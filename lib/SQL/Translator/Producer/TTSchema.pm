package SQL::Translator::Producer::TTSchema;

# -------------------------------------------------------------------
# $Id: TTSchema.pm,v 1.3 2003/08/20 22:55:06 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Mark Addison <grommit@users.sourceforge.net>,
#                    Ken Y. Clark <kclark@cpan.org>.
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

=pod 

=head1 NAME

SQL::Translator::Producer::TTSchema - 
    Produces output using the Template Toolkit from a SQL schema

=head1 SYNOPSIS

  use SQL::Translator;
  my $translator     = SQL::Translator->new(
      from           => 'MySQL',
      filename       => 'foo_schema.sql',
      to             => 'TTSchema',
      producer_args  => {
          ttfile     => 'foo_template.tt',
      },
  );
  print $translator->translate;

=head1 DESCRIPTION

Produces schema output using a given Template Tookit template.

It needs one additional producer_arg of C<ttfile> which is the file
name of the template to use.  This template will be passed a single
argument called C<schema>, which is the
C<SQL::Translator::Producer::Schema> object, which you can then use to
walk the schema via the methods documented in that module.  

Here's a brief example of what the template could look like:

  database: [% schema.database %]
  tables:
  [% FOREACH table = schema.get_tables %]
      [% table.name %]
      ================
      [% FOREACH field = table.get_fields %]
          [% field.name %]   [% field.data_type %]([% field.size %])
      [% END -%]
  [% END %]

See F<t/data/template/basic.tt> for a more complete example.

You can also set any of the options used to initiallize the Template object by 
adding them to your producer_args. See Template Toolkit docs for details of
the options.

  $translator          = SQL::Translator->new(
      to               => 'TT',
      producer_args    => {
          ttfile       => 'foo_template.tt',
          INCLUDE_PATH => '/foo/templates/tt',
          INTERPOLATE  => 1,
      },
  );

You can use this producer to create any type of text output you like,
even using it to create your own versions of what the other producers
make.  For example, you could create a template that translates the
schema into MySQL's syntax, your own HTML documentation, your own
Class::DBI classes (or some other code) -- the opportunities are
limitless!

=cut

# -------------------------------------------------------------------

use strict;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

use Template;
use Data::Dumper;
use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(produce);

use SQL::Translator::Utils 'debug';

sub produce {
    my $translator = shift;
    local $DEBUG   = $translator->debug;
    my $scma       = $translator->schema;
    my $args       = $translator->producer_args;
    my $file       = delete $args->{'ttfile'} or die "No template file!";
   
    debug "Processing template $file\n";
    my $out;
    my $tt       = Template->new(
        DEBUG    => $DEBUG,
        ABSOLUTE => 1, # Set so we can use from the command line sensibly
        RELATIVE => 1, # Maybe the cmd line code should set it! Security!
        %$args,        # Allow any TT opts to be passed in the producer_args
    ) || die "Failed to initialize Template object: ".Template->error;

    $tt->process( $file, { schema => $scma }, \$out ) 
        or die "Error processing template '$file': ".$tt->error;

    return $out;
};

1;

# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Mark Addison E<lt>grommit@users.sourceforge.netE<gt>.

=head1 TODO

B<More template vars?> e.g. [% tables %] as a shortcut for
[% schema.get_tables %].

=head1 SEE ALSO

SQL::Translator.

=cut
