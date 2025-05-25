package HTML::StateTable::ResultSet::Logfile;

use 5.010001;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 13 $ =~ /\d+/gmx );

use Data::Page;
use File::DataClass::Types      qw( Directory );
use HTML::StateTable::Constants qw( COL_INFO_TYPE_ATTR FALSE TRUE );
use HTML::StateTable::Types     qw( ArrayRef Bool Int LoadableClass
                                    ResultRole Str Table Undef );
use Ref::Util                   qw( is_arrayref is_coderef is_hashref );
use HTML::StateTable::ResultSet::Logfile::Column;
use Moo;
use MooX::HandlesVia;

=pod

=encoding utf-8

=head1 Name

HTML::StateTable::ResultSet::Logfile - Iterator pattern for viewing logfiles

=head1 Synopsis

   use HTML::StateTable::ResultSet::Logfile;

=head1 Description

An imitation of a L<DBIx::Class> resultset object. Unfortunately named, should
be file not logfile

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item complete

A mutable boolean which is true if the results list contains all the rows
in the logfile. It is false when the results list only contains a partial
view of the logfile

=cut

has 'complete' => is => 'rw', isa => Bool, default => TRUE;

=item count

Synonym for C<total_results>

=cut

has 'count' => is => 'lazy', isa => Int,
   default => sub { shift->total_results };

=item current_source_alias

A string which defaults to C<me>. Needed by L<HTML::StateTable>

=cut

has 'current_source_alias' => is => 'ro', isa => Str, default => 'me';

=item directory

An instance of L<File::DataClass::IO> which represents the directory that
contains the files. Required

=cut

has 'directory' => is => 'lazy', isa => Directory, required => TRUE;

=item distinct_column

The column filter option in L<HTML::StateTable> will specify which column to
return unique values for

=item has_distinct_column

Predicate

=cut

has 'distinct_column' =>
   is        => 'ro',
   isa       => ArrayRef[Str],
   predicate => 'has_distinct_column',
   writer    => '_set_distinct_column';

# The where clause in calls to search adds filters to this list
has '_filter' =>
   is          => 'ro',
   isa         => ArrayRef,
   handles_via => 'Array',
   handles     => { _add_filter => 'push', has_filter => 'count' },
   default     => sub { [] };

# This is the current index into the results list for the iterator
has '_index' =>
   is       => 'rw',
   isa      => Int,
   lazy     => TRUE,
   default  => sub { shift->index_start };

=item page

An integer that defaults to 1. The number of the page of results that is being
requested

=cut

has 'page'  =>
   is      => 'ro',
   isa     => Int,
   default => 1,
   trigger => \&reset,
   writer  => '_set_page';

=item page_size

An integer that defaults to 0. The size of the page of results that is being
requested. If non zero paging is turned on

=cut

has 'page_size' =>
   is      => 'ro',
   isa     => Int,
   default => 0,
   trigger => \&reset,
   writer  => '_set_page_size';

=item paging

A bool which tracks whether paging is turned on

=cut

has 'paging' =>
   is      => 'ro',
   isa     => Bool,
   default => FALSE,
   writer  => '_set_paging';

=item result_class

A required loadable classname. The C<build_results> method in the child class
will use this to inflate lines from the result source

=cut

has 'result_class' => is => 'ro', isa => LoadableClass, required => TRUE;

# The list of results which will be displayed in response to this request
has '_results' =>
   is          => 'lazy',
   isa         => ArrayRef[ResultRole|Undef],
   builder     => 'build_results',
   handles_via => 'Array',
   handles     => { result_count => 'count' },
   clearer     => '_clear_results';

# The column by which the results will be sorted
has '_sort_column' =>
   is        => 'ro',
   isa       => Str,
   trigger   => \&reset,
   predicate => '_has_sort_column',
   writer    => '_set_sort_column';

# The order in which the results will be sorted. Either 'asc' or 'desc'
has '_sort_order' =>
   is      => 'ro',
   isa     => Str,
   trigger => \&reset,
   default => 'asc',
   writer  => '_set_sort_order';

=item table

Parent table object reference

=cut

has 'table' => is => 'ro', isa => Table, weak_ref => TRUE;

=item total_results

The total number of objects in the resultset

=cut

has 'total_results' =>
   is      => 'lazy',
   isa     => Int,
   writer  => '_set_total_results',
   default => sub { shift->result_count };

=back

=head1 Subroutines/Methods

=over

=item build_results

Default constructor that returns an empty array reference. Expected to be
overridden in a child class by a method which returns a reference to an array
of C<result_class> objects

=cut

sub build_results {
   return [];
}

=item column_info( column_name )

Returns a hash reference containing the data type of the specified
column. Think L<DBIx::Class> resultsets

=cut

sub column_info {
   my ($self, $name) = @_;

   my $attr = COL_INFO_TYPE_ATTR;

   if (my $column = $self->table->get_column($name)) {
      for my $trait (@{$column->cell_traits}) {
         return { $attr => 'TIMESTAMP' } if $trait =~ m{ date }imx;
         return { $attr => 'INTEGER' }   if $trait =~ m{ numeric }imx;
      }
   }

   return { $attr => 'TEXT' };
}

sub _filter_results {
   my ($self, $results) = @_;

   return [ grep { $self->_filter_result($_) } @{$results} ]
}

sub _filter_result {
   my ($self, $result) = @_;

   for my $tuple (@{$self->_filter}) {
      return TRUE if _filter_match($result, @{$tuple});
   }

   return FALSE;
}

sub _filter_match {
   my ($result, $field, $op, $wanted) = @_;

   return FALSE unless $result->can($field);

   my $value = $result->$field;

   return FALSE unless defined $value;

   return TRUE if $op eq '==' && $value == $wanted;

   return TRUE if $op eq 'eq' && $value eq $wanted;

   return TRUE if $op eq 'ilike' && $value =~ m{ \Q$wanted\E }mx;

   return FALSE;
}

=item get_column( column_name )

Returns a L<HTML::StateTable::ResultSet::Logfile::Column> object for the given
column name

=cut

sub get_column {
   my ($self, $column_name) = @_;

   return HTML::StateTable::ResultSet::Logfile::Column->new(
      name => $column_name, resultset => $self
   );
}

=item index_start

The line number of the first row being displayed in the table

=cut

sub index_start {
   my $self = shift;

   return $self->page_size * ($self->page - 1);
}

sub _is_numeric {
   my ($self, $col) = @_;

   my $attr = COL_INFO_TYPE_ATTR;
   my $type = $self->column_info($col)->{$attr};

   return $type && lc $type eq 'integer' ? TRUE : FALSE;
}

=item next

This is the iterator call to return the next result object

=cut

sub next {
   my $self = shift;

   if ($self->paging) {
      return if $self->_index >= $self->index_start + $self->page_size;
   }

   return if $self->_index >= $self->total_results;

   my $offset = $self->complete ? 0 : $self->index_start;
   my $result = $self->_results->[$self->_index - $offset];

   $self->_index($self->_index + 1);

   return $result;
}

=item pager

Provides L<HTML::StateTable> with a L<Data::Page> object

=cut

sub pager {
   my $self = shift;

   return Data::Page->new(
      $self->total_results, $self->page_size, $self->page
   );
}

=item process( results )

Implements the actual filtering and ordering of the result set. Called from
the C<build_results> method

=cut

sub process {
   my ($self, $results) = @_;

   $results = $self->_filter_results($results)  if $self->has_filter;
   $results = $self->_select_distinct($results) if $self->has_distinct_column;
   $results = $self->_sort_results($results)    if $self->_has_sort_column;

   return $results;
}

=item reset

Resets the iterators state whenever one of the request parameters changes

=cut

sub reset {
   my $self = shift;

   $self->_set_paging($self->page_size ? TRUE : FALSE);
   $self->_index($self->index_start);

   return;
}

=item result_source

Required by L<HTML::StateTable>

=cut

sub result_source {
   return shift;
}

=item search( where, options )

Implements enough of L<DBIx::Class::Resultset> search to satisfy
L<HTML::StateTable>

=cut

sub search {
   my ($self, $where, $options) = @_;

   $options //= {};
   $self->_set_distinct_column($options->{columns}) if $options->{distinct};
   $self->_set_page_size($options->{rows})          if $options->{rows};
   $self->_set_page($options->{page})               if $options->{page};
   $self->_set_sort_options($options->{order_by})   if $options->{order_by};
   $self->_set_where_clause($where)                 if defined $where;

   return $self;
}

sub _select_distinct {
   my ($self, $results) = @_;

   my $col      = $self->distinct_column->[0];
   my $distinct = [];
   my %seen     = ();

   for my $result (@{$results}) {
      push @{$distinct}, $result unless $seen{$result->$col}++;
   }

   return $distinct;
}

sub _set_sort_options {
   my ($self, $options) = @_;

   my $col   = $options;
   my $order = 'asc';

   if (is_arrayref $options) {
      my $pair = $options->[0];

      ($order = (keys %{$pair})[0]) =~ s{ \A [\-] }{}mx;
      $col = ${(values %{$pair})[0]};
   }

   if ($col && $order) {
      $col = _strip_column_name($col);
      $self->_set_sort_column($col);
      $self->_set_sort_order($order);
   }

   return;
}

sub _strip_column_name {
   my $col = shift;

   $col =~ s{ \A LOWER\( (.+) \) \z }{$1}imx;
   $col =~ s{ \A \"me\" \. }{}mx;
   $col =~ s{ (?: \A \" | \" \z ) }{}gmx;

   return $col;
}

sub _set_where_clause {
   my ($self, $options) = @_;

   if (is_arrayref $options) {
      my $index = 0;

      while (defined(my $field = $options->[$index])) {
         my $operator = (keys %{$options->[$index + 1]})[0];
         my $value    = $options->[$index + 1]->{$operator};

         $field =~ s{ \A me\. }{}mx;
         $value =~ s{ (?: \A % | % \z ) }{}gmx if $operator eq 'ilike';

         $self->_add_filter([ $field, $operator, $value ]);
         $index += 2;
      }

      $self->_clear_results;
   }
   elsif (is_hashref $options) {
      if (my $field = (keys %{$options})[0]) {
         my $value = $options->{$field};

         $field =~ s{ \A me\. }{}mx;
         $self->_add_filter([ $field, 'eq', $value ]);
         $self->_clear_results;
      }
   }

   return;
}

sub _sort_results {
   my ($self, $results) = @_;

   my $col = $self->_sort_column or return $results;

   return $results if is_coderef $col || $col =~ m{ \A CODE }mx ;

   if ($self->_is_numeric($col)) {
      return [ sort { $a->$col <=> $b->$col } @{$results} ]
         if $self->_sort_order eq 'asc';

      return [ sort { $b->$col <=> $a->$col } @{$results} ];
   }

   return [ sort { $a->$col cmp $b->$col } @{$results} ]
      if $self->_sort_order eq 'asc';

   return [ sort { $b->$col cmp $a->$col } @{$results} ];
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
