package HTML::StateTable::ResultSet::Logfile::Cache;

use HTML::StateTable::Constants qw( EXCEPTION_CLASS FALSE TRUE );
use HTML::StateTable::Types     qw( HashRef Object );
use IPC::Run                    qw( run );
use JSON::MaybeXS               qw( decode_json encode_json );
use Type::Utils                 qw( class_type );
use Unexpected::Functions       qw( throw );
use Moo;

my $CACHE_LAG_SECS = 300;
my $MAX_CACHE_SIZE = 5_000_000;
my $READ_BUFF_SIZE = 5_000_000;

=pod

=encoding utf-8

=head1 Name

HTML::StateTable::ResultSet::Logfile::Cache - Cache for viewing logfiles

=head1 Synopsis

   use HTML::StateTable::ResultSet::Logfile::Cache;

=head1 Description

A read through cache for viewing logfiles

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item config

=cut

has 'config' => is => 'ro', isa => HashRef, default => sub { {} };

=item redis

=cut

has 'redis' => is => 'ro', isa => Object, required => TRUE;

=item resultset

=cut

has 'resultset' =>
   is       => 'ro',
   isa      => class_type('HTML::StateTable::ResultSet::Logfile'),
   required => TRUE;

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item count

=cut

sub count {
   my $self = shift;
   my $rs   = $self->resultset;
   my $key  = $rs->path->as_string;

   return scalar @{$self->_filtered_line_numbers($key)} if $rs->has_filter;
   return $rs->result_count if $self->_is_complete;
   return scalar @{$self->_read_cache($key, \&_build_index)};
}

=item read

=cut

sub read {
   my $self = shift;
   my $rs   = $self->resultset;
   my $key  = $rs->path->as_string;

   return $self->_read_column_values($key) if $rs->has_column_filter;
   return $self->_read_all_lines($key)     if $self->_is_complete;
   return $self->_read_some_lines($key)    if $rs->has_filter;
   return $self->_read_partial($key);
}

sub _build_index {
   my $self     = shift;
   my $path     = $self->resultset->path->assert_open('r');
   my $buffer;
   my $iterator = $self->_build_iterator($path, \$buffer);
   my $index    = [];
   my $line     = 0;
   my $count    = 0;

   $index->[$line++] = $count;

   while (my $bytes_read = $iterator->()) {
      if ($line > 1) {
         $line--;
         $count--;
      }

      for my $len (map { length } split m{ \n }mx, $buffer) {
         $count += $len + 1;
         $index->[$line++] = $count;
      }
   }

   return $index;
}

sub _build_iterator {
   my ($self, $path, $buffer_ref) = @_;

   return sub {
      my $bytes_read = $path->sysread(${$buffer_ref}, $READ_BUFF_SIZE);

      throw ${!} unless defined $bytes_read;
      return unless $bytes_read;
      return $bytes_read;
   };
}

sub _end_offset {
   my ($self, $index) = @_;

   my $rs  = $self->resultset;
   my $end = $index->[ $rs->index_start + $rs->page_size ];

   return $end if $rs->paging && $end;

   # If we are not paging force read partial to read the whole file
   return $rs->path->stat->{size};
}

sub _filtered_line_numbers {
   my ($self, $key) = @_;

   my $rs    = $self->resultset;
   my $col   = $rs->_filter->[0]->[1];
   my $value = $rs->_filter->[0]->[2];

   return $self->_read_cache("${key}!column-${col}!value-${value}", sub {
      my @cmd    = ('grep', '-n', $value, $rs->path->as_string);
      my @filter = ('cut', '-d', ':', '-f', 1);
      my $stdin  = undef;
      my $stdout;
      my $stderr;

      run \@cmd, \$stdin, '|', \@filter, \$stdout, \$stderr;

      throw $stderr if $stderr;

      return [ split m{ \n }mx, $stdout ];
   });
}

sub _is_complete {
   my $self = shift;
   my $rs   = $self->resultset;

   return $rs->complete(TRUE) if $rs->path->stat->{size} < $MAX_CACHE_SIZE;

   return $rs->complete(FALSE);
}

sub _partition_command {
   my ($self, $cmd) = @_;

   my $aref    = [];
   my @command = ();

   for my $item (grep { defined && length } @{$cmd}) {
      if ($item !~ m{ [\<\>\|\&] }mx) { push @{$aref}, $item }
      else { push @command, $aref, $item; $aref = [] }
   }

   if ($aref->[0]) {
      if ($command[0]) { push @command, $aref }
      else { @command = @{$aref} }
   }

   return @command;
}

sub _read_all_lines {
   my ($self, $key) = @_;

   my $rs    = $self->resultset;
   my $path  = $rs->path;
   my $lines = $self->_read_cache($key, sub { [$path->chomp->slurp]});
   my $class = $rs->result_class;

   return [ map { $class->new(line => $_, resultset => $rs) } @{$lines} ];
}

sub _read_by_line_numbers {
   my ($self, $key, $line_numbers) = @_;

   my $index = $self->_read_cache($key, \&_build_index);
   my $rs    = $self->resultset;
   my $start = $rs->index_start;
   my $end   = $start + $rs->page_size - 1;
   my $lines = [];
   my $buffer;

   $rs->path->assert_open('r');

   for my $line_number (map { $line_numbers->[$_] } $start .. $end) {
      next unless defined $line_number && length $line_number;

      my $offset = $index->[$line_number - 1];
      my $length = $index->[$line_number] - $offset - 1;

      $rs->path->seek($offset, 0);
      $rs->path->sysread($buffer, $length);

      my $line = $buffer;

      push @{$lines}, $line;
   }

   return $lines;
}

sub _read_cache {
   my ($self, $key, $source) = @_;

   my $redis = $self->redis;
   my $mtime = $self->resultset->path->stat->{mtime};
   my $cache = decode_json($redis->get($key)) if $redis->exists($key);

   if (defined $cache && $mtime > $cache->{mtime} + $CACHE_LAG_SECS) {
      $redis->del($key);
      $cache = undef;
   }

   unless (defined $cache) {
      $cache = { mtime => $mtime, results => $source->($self) };
      $redis->set($key, encode_json($cache));
   }

   return $cache->{results};
}

sub _read_column_values {
   my ($self, $key) = @_;

   my $rs     = $self->resultset;
   my $class  = $rs->result_class;
   my $col    = $rs->distinct_column->[0];
   my $values = $self->_read_cache("${key}!column-${col}", sub {
      my $method = "${col}_filter";
      my $values = "${method}_values";
      my $result = $class->new(line => q(), resultset => $rs);

      return $result->$values if $result->can($values);

      my @cmd    = ('cat', $rs->path->as_string);
      my @filter = $self->_partition_command($result->$method);
      my $stdin  = undef;
      my $stdout;
      my $stderr;

      run \@cmd, \$stdin, '|', @filter, \$stdout, \$stderr;

      throw $stderr if $stderr;

      return [ split m{ \n }mx, $stdout ];
   });

   return [ map { $class->new(line => q(), $col => $_, resultset => $rs) }
            @{$values} ];
}

sub _read_partial {
   my ($self, $key) = @_;

   my $index  = $self->_read_cache($key, \&_build_index);
   my $rs     = $self->resultset;
   my $offset = $index->[ $rs->index_start ];
   my $length = $self->_end_offset($index) - $offset - 1;

   $rs->path->seek($offset, 0);

   my $buffer;
   my $bytes_read = $rs->path->sysread($buffer, $length);

   $buffer = q() unless defined $bytes_read;

   return [] unless defined $buffer && length $buffer;

   my $class = $rs->result_class;

   return [ map { $class->new(line => $_, resultset => $rs) }
            split m{ \n }mx, $buffer ];
}

sub _read_some_lines {
   my ($self, $key) = @_;

   my $rs    = $self->resultset;
   my $class = $rs->result_class;
   my $lnums = $self->_filtered_line_numbers($key);
   my $lines = $self->_read_by_line_numbers($key, $lnums);

   return [ map { $class->new(line => $_, resultset => $rs) } @{$lines} ];
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<HTML::StateTable>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=HTML::StateTable::ResultSet.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <lazarus@roxsoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2023 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
