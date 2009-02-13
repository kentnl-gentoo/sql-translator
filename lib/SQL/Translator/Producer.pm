package SQL::Translator::Producer;

# -------------------------------------------------------------------
# Copyright (C) 2002-4 SQLFairy Authors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
# -------------------------------------------------------------------

use strict;
use vars qw($VERSION);
$VERSION = '1.59';

sub produce { "" }

# Do not rely on this if you are not bundled with SQL::Translator.
# -- rjbs, 2008-09-30
## $exceptions contains an arrayref of paired values
## Each pair contains a pattern match or string, and a value to be used as
## the default if matched.
## They are special per Producer, and provide support for the old 'now()'
## default value exceptions
sub _apply_default_value {
  my (undef, $field_ref, $default, $exceptions) = @_;

  if ($exceptions and ! ref $default) {
    for (my $i = 0; $i < @$exceptions; $i += 2) {
      my ($pat, $val) = @$exceptions[ $i, $i + 1 ];
      if (ref $pat and $default =~ $pat) {
          $default = $val;
          last;
      } elsif (lc $default eq lc $pat) {
          $default = $val;
          last
      }
    }
  }

  if (ref $default) {
      $$field_ref .= " DEFAULT $$default";
  } else {
      $$field_ref .= " DEFAULT '$default'";
  }

}

1;

# -------------------------------------------------------------------
# A burnt child loves the fire.
# Oscar Wilde
# -------------------------------------------------------------------

=pod

=head1 NAME

SQL::Translator::Producer - describes how to write a producer

=head1 DESCRIPTION

Producer modules designed to be used with SQL::Translator need to
implement a single function, called B<produce>.  B<produce> will be
called with the SQL::Translator object from which it is expected to 
retrieve the SQL::Translator::Schema object which has been populated 
by the parser.  It is expected to return a string.

=head1 METHODS

=over 4

=item produce

=item create_table($table)

=item create_field($field)

=item create_view($view)

=item create_index($index)

=item create_constraint($constraint)

=item create_trigger($trigger)

=item alter_field($from_field, $to_field)

=item add_field($table, $new_field)

=item drop_field($table, $old_field)

=head1 AUTHORS

Darren Chamberlain E<lt>darren@cpan.orgE<gt>,
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

perl(1), SQL::Translator, SQL::Translator::Schema.

=cut
