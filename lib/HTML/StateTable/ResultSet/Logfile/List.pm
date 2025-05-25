package HTML::StateTable::ResultSet::Logfile::List;

use HTML::StateTable::Constants qw( FALSE TRUE );
use HTML::StateTable::Types     qw( Bool );
use Moo;

extends 'HTML::StateTable::ResultSet::Logfile';

=pod

=encoding utf-8

=head1 Name

HTML::StateTable::ResultSet::Logfile::List - Builds directory list results

=head1 Synopsis

   use HTML::StateTable::ResultSet::Logfile::List;

=head1 Description

Creates result objects for each matching file entry in the base directory

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item allow_directories

=cut

has 'allow_directories' => is => 'ro', isa => Bool, default => FALSE;

=item recurse

=cut

has 'recurse' => is => 'ro', isa => Bool, default => TRUE;

=item show_dot_files

=cut

has 'show_dot_files' => is => 'ro', isa => Bool, default => FALSE;

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item build_results

=cut

sub build_results {
   my $self    = shift;
   my $results = [];

   $self->directory->visit(sub {
      my $path = shift;

      return if !$self->show_dot_files && $path->basename =~ m{ \A \. }mx;
      return if $path->is_dir && !$self->allow_directories;

      push @{$results}, $self->result_class->new(
         directory => $self->directory,
         path      => $path,
         table     => $self->table,
      );
   }, { recurse => $self->recurse });

   return $self->process([sort { $a->path cmp $b->path } @{$results}]);
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
