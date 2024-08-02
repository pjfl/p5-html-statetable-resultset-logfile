package HTML::StateTable::ResultSet::File::View;

use File::DataClass::Types      qw( File );
use HTML::StateTable::Constants qw( DOT FALSE TRUE );
use HTML::StateTable::Types     qw( HashRef Object Str );
use Type::Utils                 qw( class_type );
use HTML::StateTable::ResultSet::Logfile::Cache;
use Moo;

extends 'HTML::StateTable::ResultSet::Logfile';

=pod

=encoding utf-8

=head1 Name

HTML::StateTable::ResultSet::File::View - Create result objects

=head1 Synopsis

   use HTML::StateTable::ResultSet::File::View;

=head1 Description

Creates result objects for each line in the selected file

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item cache

=cut

has 'cache' =>
   is      => 'lazy',
   isa     => class_type('HTML::StateTable::ResultSet::Logfile::Cache'),
   default => sub {
      my $self = shift;

      return HTML::StateTable::ResultSet::Logfile::Cache->new(
         redis => $self->redis, resultset => $self
      );
   };

has 'file' => is => 'ro', isa => Str, required => TRUE;

=item path

=cut

has 'path' =>
   is       => 'lazy',
   isa      => File,
   init_arg => undef,
   default  => sub {
      my $self      = shift;
      my $file      = $self->file;
      my $extension = $self->extension;

      $file .= DOT . $extension
         if $self->extension && $file !~ m{ \. $extension \z }mx;

      return $self->directory->catfile($file);
   };

=item redis

=cut

has 'redis' => is => 'ro', isa => Object, required => TRUE;

=item total_results

=cut

has '+total_results' => default => sub { shift->cache->count };

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item build_results

=cut

sub build_results {
   my $self = shift;

   return $self->process($self->cache->read);
}

=item has_column_filter

=cut

sub has_column_filter {
   my $self = shift;

   return FALSE unless $self->has_distinct_column;

   my $method = $self->distinct_column->[0] . '_filter';

   return $self->result_class->can($method) ? TRUE : FALSE;
}

around '_sort_results' => sub {
   my ($orig, $self, $results) = @_;

   if ($self->_sort_column eq 'timestamp') {
      return $self->_sort_order eq 'asc' ? $results : [ reverse @{$results} ];
   }

   return $orig->($self, $results);
};

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
