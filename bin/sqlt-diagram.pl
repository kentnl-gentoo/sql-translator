#!/usr/bin/perl

# $Id: sqlt-diagram.pl,v 1.2 2003/06/16 18:25:36 kycl4rk Exp $

=head1 NAME 

sqlt-diagram.pl - Automatically create a diagram from a database schema

=head1 SYNOPSIS

  ./sqlt-diagram.pl -d|--db=db_parser [options] schema.sql

  Options:

    -o|--output        Output file name (default STDOUT)
    -i|--image         Output image type ("png" or "jpeg," default "png")
    -t|--title         Title to give schema
    -c|--cols          Number of columns
    -n|--no-lines      Don't draw lines
    -f|--font-size     Font size ("small," "medium," "large," or "huge,"
                       default "medium")
    --color            Add colors
    --show-fk-only     Only show fields that act as primary 
                       or foreign keys

    --natural-join     Perform natural joins
    --natural-join-pk  Perform natural joins from primary keys only
    -s|--skip          Fields to skip in natural joins
    --debug            Print debugging information

=head1 DESCRIPTION

This script will create a picture of your schema.  Only the database
driver argument (for SQL::Translator) is required.  If no output file
name is given, then image will be printed to STDOUT, so you should
redirect the output into a file.

The default action is to assume the presence of foreign key
relationships defined via "REFERNCES" or "FOREIGN KEY" constraints on
the tables.  If you are parsing the schema of a file that does not
have these, you will find the natural join options helpful.  With
natural joins, like-named fields will be considered foreign keys.
This can prove too permissive, however, as you probably don't want a
field called "name" to be considered a foreign key, so you could
include it in the "skip" option, and all fields called "name" will be
excluded from natural joins.  A more efficient method, however, might
be to simply deduce the foriegn keys from primary keys to other fields
named the same in other tables.  Use the "natural-join-pk" option
to acheive this.

=cut

use strict;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
use SQL::Translator;

my $VERSION = (qw$Revision: 1.2 $)[-1];

#
# Get arguments.
#
my ( 
    $out_file, $image_type, $db_driver, $title, $no_columns, 
    $no_lines, $font_size, $add_color, $debug, $show_fk_only,
    $natural_join, $join_pk_only, $skip_fields, $help
);

GetOptions(
    'd|db=s'          => \$db_driver,
    'o|output:s'      => \$out_file,
    'i|image:s'       => \$image_type,
    't|title:s'       => \$title,
    'c|columns:i'     => \$no_columns,
    'n|no-lines'      => \$no_lines,
    'f|font-size:s'   => \$font_size,
    'color'           => \$add_color,
    'show-fk-only'    => \$show_fk_only,
    'natural-join'    => \$natural_join,
    'natural-join-pk' => \$join_pk_only,
    's|skip:s'        => \$skip_fields,
    'debug'           => \$debug,
    'h|help'          => \$help,
) or die pod2usage;
my @files = @ARGV; # the create script(s) for the original db

pod2usage(1) if $help;
pod2usage( -message => "No db driver specified" ) unless $db_driver;
pod2usage( -message => 'No input file'          ) unless @files;

my $translator       =  SQL::Translator->new( 
    from             => $db_driver,
    to               => 'Diagram',
    debug            => $debug || 0,
    producer_args    => {
        out_file     => $out_file,
        image_type   => $image_type,
        title        => $title,
        no_columns   => $no_columns,
        no_lines     => $no_lines,
        font_size    => $font_size,
        add_color    => $add_color,
        show_fk_only => $show_fk_only,
        natural_join => $natural_join,
        join_pk_only => $join_pk_only,
        skip_fields  => $skip_fields,
    },
) or die SQL::Translator->error;

for my $file (@files) {
    my $output = $translator->translate( $file ) or die
                 "Error: " . $translator->error;
    if ( $out_file ) {
        print "Image written to '$out_file'.  Done.\n";
    }
    else {
        print $output;
    }
}

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
