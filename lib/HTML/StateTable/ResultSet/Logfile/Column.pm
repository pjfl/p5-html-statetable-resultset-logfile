package HTML::StateTable::ResultSet::Logfile::Column;

use HTML::StateTable::Constants qw( FALSE TRUE );
use HTML::StateTable::Types     qw( ResultSet Str );
use Moo;

=pod

=encoding utf-8

=head1 Name

HTML::StateTable::ResultSet::Logfile::Column - Column object

=head1 Synopsis

   use HTML::StateTable::ResultSet::Logfile::Column;

=head1 Description

Column object

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item name

=cut

has 'name' => is => 'ro', isa => Str, required => TRUE;

=item resultset

=cut

has 'resultset' => is => 'ro', isa => ResultSet, required => TRUE;

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item all

=cut

sub all {
   my $self   = shift;
   my $name   = $self->name;
   my @values = ();

   while (my $result = $self->resultset->next) {
      push @values, $result->$name;
   }

   $self->resultset->reset;
   return @values;
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
