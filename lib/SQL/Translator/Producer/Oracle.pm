package SQL::Translator::Producer::Oracle;

# -------------------------------------------------------------------
# $Id: Oracle.pm,v 1.13 2003/06/11 04:00:43 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>,
#                    darren chamberlain <darren@cpan.org>,
#                    Chris Mungall <cjm@fruitfly.org>
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
use vars qw[ $VERSION $DEBUG $WARN ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);

my %translate  = (
    #
    # MySQL types
    #
    bigint     => 'number',
    double     => 'number',
    decimal    => 'number',
    float      => 'number',
    int        => 'number',
    mediumint  => 'number',
    smallint   => 'number',
    tinyint    => 'number',
    char       => 'char',
    varchar    => 'varchar2',
    tinyblob   => 'CLOB',
    blob       => 'CLOB',
    mediumblob => 'CLOB',
    longblob   => 'CLOB',
    longtext   => 'long',
    mediumtext => 'long',
    text       => 'long',
    tinytext   => 'long',
    enum       => 'varchar2',
    set        => 'varchar2',
    date       => 'date',
    datetime   => 'date',
    time       => 'date',
    timestamp  => 'date',
    year       => 'date',

    #
    # PostgreSQL types
    #
    numeric             => 'number',
    'double precision'  => 'number',
    serial              => 'number',
    bigserial           => 'number',
    money               => 'number',
    character           => 'char',
    'character varying' => 'varchar2',
    bytea               => 'BLOB',
    interval            => 'number',
    boolean             => 'number',
    point               => 'number',
    line                => 'number',
    lseg                => 'number',
    box                 => 'number',
    path                => 'number',
    polygon             => 'number',
    circle              => 'number',
    cidr                => 'number',
    inet                => 'varchar2',
    macaddr             => 'varchar2',
    bit                 => 'number',
    'bit varying'       => 'number',
);

#
# Oracle reserved words from:
# http://technet.oracle.com/docs/products/oracle8i/doc_library/\
# 817_doc/server.817/a85397/ap_keywd.htm
#
my %ora_reserved = map { $_, 1 } qw(
    ACCESS ADD ALL ALTER AND ANY AS ASC AUDIT 
    BETWEEN BY
    CHAR CHECK CLUSTER COLUMN COMMENT COMPRESS CONNECT CREATE CURRENT
    DATE DECIMAL DEFAULT DELETE DESC DISTINCT DROP
    ELSE EXCLUSIVE EXISTS 
    FILE FLOAT FOR FROM
    GRANT GROUP 
    HAVING
    IDENTIFIED IMMEDIATE IN INCREMENT INDEX INITIAL INSERT
    INTEGER INTERSECT INTO IS
    LEVEL LIKE LOCK LONG 
    MAXEXTENTS MINUS MLSLABEL MODE MODIFY 
    NOAUDIT NOCOMPRESS NOT NOWAIT NULL NUMBER 
    OF OFFLINE ON ONLINE OPTION OR ORDER
    PCTFREE PRIOR PRIVILEGES PUBLIC
    RAW RENAME RESOURCE REVOKE ROW ROWID ROWNUM ROWS
    SELECT SESSION SET SHARE SIZE SMALLINT START 
    SUCCESSFUL SYNONYM SYSDATE 
    TABLE THEN TO TRIGGER 
    UID UNION UNIQUE UPDATE USER
    VALIDATE VALUES VARCHAR VARCHAR2 VIEW
    WHENEVER WHERE WITH
);

my $max_id_length    = 30;
my %used_identifiers = ();
my %global_names;
my %unreserve;
my %truncated;

# -------------------------------------------------------------------
sub produce {
    my $translator     = shift;
    $DEBUG             = $translator->debug;
    $WARN              = $translator->show_warnings;
    my $no_comments    = $translator->no_comments;
    my $add_drop_table = $translator->add_drop_table;
    my $schema         = $translator->schema;
    my $output;

    $output .= header_comment unless ($no_comments);

    if ( $translator->parser_type =~ /mysql/i ) {
        $output .= 
        "-- We assume that default NLS_DATE_FORMAT has been changed\n".
        "-- but we set it here anyway to be self-consistent.\n".
        "ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';\n\n";
    }

    #
    # Print create for each table
    #
    for my $table ( $schema->get_tables ) { 
        my $table_name    = $table->name or next;
        $table_name       = mk_name( $table_name, '', undef, 1 );
        my $table_name_ur = unreserve($table_name) or next;

        my ( @comments, @field_defs, @trigger_defs, @constraint_defs );

        push @comments, "--\n-- Table: $table_name_ur\n--" unless $no_comments;

        my %field_name_scope;
        for my $field ( $table->get_fields ) {
            #
            # Field name
            #
            my $field_name    = mk_name(
                $field->name, '', \%field_name_scope, 1 
            );
            my $field_name_ur = unreserve( $field_name, $table_name );
            my $field_def     = $field_name_ur;

            #
            # Datatype
            #
            my $check;
            my $data_type = lc $field->data_type;
            my @size      = $field->size;
            my %extra     = $field->extra;
            my $list      = $extra{'list'} || [];
            my $commalist = join ",", @$list;

            if ( $data_type eq 'enum' ) {
                $check = "CHECK ($field_name IN ($commalist))";
                $data_type = 'varchar2';
            }
            elsif ( $data_type eq 'set' ) {
                # XXX add a CHECK constraint maybe 
                # (trickier and slower, than enum :)
                $data_type = 'varchar2';
            }
            else {
                $data_type  = defined $translate{ $data_type } ?
                              $translate{ $data_type } :
                              die "Unknown datatype: $data_type\n";
            }

            $field_def .= " $data_type";
            if ( defined $size[0] && $size[0] > 0 ) {
                $field_def .= '(' . join( ', ', @size ) . ')';
            }
        
            #
            # Default value
            #
            my $default = $field->default_value;
            if ( defined $default ) {
                $field_def .= sprintf(
                    ' DEFAULT %s',
                    $default =~ m/null/i ? 'NULL' : "'$default'"
                );
            }

            #
            # Not null constraint
            #
            unless ( $field->is_nullable ) {
                my $constraint_name = mk_name($field_name_ur, 'nn');
                $field_def .= ' CONSTRAINT ' . $constraint_name . ' NOT NULL';
            }

            $field_def .= " $check" if $check;

            #
            # Auto_increment
            #
            if ( $field->is_auto_increment ) {
                my $base_name    = $table_name . "_". $field_name;
                my $seq_name     = mk_name( $base_name, 'sq' );
                my $trigger_name = mk_name( $base_name, 'ai' );

                push @trigger_defs, 
                    "CREATE SEQUENCE $seq_name;\n" .
                    "CREATE OR REPLACE TRIGGER $trigger_name\n" .
                    "BEFORE INSERT ON $table_name\n" .
                    "FOR EACH ROW WHEN (\n" .
                        " new.$field_name_ur IS NULL".
                        " OR new.$field_name_ur = 0\n".
                    ")\n".
                    "BEGIN\n" .
                        " SELECT $seq_name.nextval\n" .
                        " INTO :new." . $field->name."\n" .
                        " FROM dual;\n" .
                    "END;\n/";
                ;
            }

            if ( lc $field->data_type eq 'timestamp' ) {
                my $base_name = $table_name . "_". $field_name_ur;
                my $trig_name = mk_name( $base_name, 'ts' );
                push @trigger_defs, 
                    "CREATE OR REPLACE TRIGGER $trig_name\n".
                    "BEFORE INSERT OR UPDATE ON $table_name_ur\n".
                    "FOR EACH ROW WHEN (new.$field_name_ur} IS NULL)\n".
                    "BEGIN \n".
                    " SELECT sysdate INTO :new.$field_name_ur} FROM dual;\n".
                    "END;\n/";
            }

            push @field_defs, $field_def;
        }

        #
        # Table constraints
        #
        my $constraint_name_default;
        for my $c ( $table->get_constraints ) {
            my $name    = $c->name || '';
            my @fields  = map { unreserve( $_, $table_name ) } $c->fields;
            my @rfields = map { unreserve( $_, $table_name ) } 
                $c->reference_fields;
            next unless @fields;

            if ( $c->type eq PRIMARY_KEY ) {
                $name ||= mk_name( $table_name, 'pk' );
                push @constraint_defs, "CONSTRAINT $name PRIMARY KEY ".
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $c->type eq UNIQUE ) {
                $name ||= mk_name( $table_name, ++$constraint_name_default );
                push @constraint_defs, "CONSTRAINT $name UNIQUE " .
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $c->type eq FOREIGN_KEY ) {
                $name ||= mk_name( $table_name, ++$constraint_name_default );
                my $def = "CONSTRAINT $name FOREIGN KEY REFERENCES ".
                    $c->reference_table;

                if ( @rfields ) {
                    $def .= ' (' . join( ', ', @rfields ) . ')';
                }

                if ( $c->match_type ) {
                    $def .= ' MATCH ' . 
                        ( $c->match_type =~ /full/i ) ? 'FULL' : 'PARTIAL';
                }

                if ( $c->on_delete ) {
                    $def .= ' ON DELETE '.join( ' ', $c->on_delete );
                }

                if ( $c->on_update ) {
                    $def .= ' ON UPDATE '.join( ' ', $c->on_update );
                }

                push @constraint_defs, $def;
            }
        }

        #
        # Index Declarations
        #
        my @index_defs = ();
        my $idx_name_default;
        for my $index ( $table->get_indices ) {
            my $index_name = $index->name || '';
            my $index_type = $index->type || NORMAL;
            my @fields     = map { unreserve( $_, $table_name ) }
                             $index->fields;
            next unless @fields;

            if ( $index_type eq PRIMARY_KEY ) {
                $index_name = mk_name( $table_name, 'pk' );
                push @field_defs, 'CONSTRAINT '.$index_name.' PRIMARY KEY '.
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $index_type eq UNIQUE ) {
                $index_name = mk_name( 
                    $table_name, $index_name || ++$idx_name_default
                );
                push @field_defs, 'CONSTRAINT ' . $index_name . ' UNIQUE ' .
                    '(' . join( ', ', @fields ) . ')';
            }

            elsif ( $index_type eq NORMAL ) {
                $index_name = mk_name( 
                    $table_name, $index_name || ++$idx_name_default
                );
                push @index_defs, 
                    "CREATE INDEX $index_name on $table_name_ur (".
                        join( ', ', @fields ).  
                    ");"; 
            }
            else {
                warn "Unknown index type ($index_type) on table $table_name.\n"
                    if $WARN;
            }
        }

        my $create_statement;
        $create_statement  = "DROP TABLE $table_name_ur;\n" if $add_drop_table;
        $create_statement .= 
            join( ",\n", map { "-- $_" } $table->comments ) .
            "CREATE TABLE $table_name_ur (\n" .
            join( ",\n", map { "  $_" } @field_defs, @constraint_defs ) .
            "\n);"
        ;

        $output .= join( "\n\n", 
            @comments,
            $create_statement, 
            @trigger_defs, 
            @index_defs, 
            '' 
        );
    }

    if ( $WARN ) {
        if ( %truncated ) {
            warn "Truncated " . keys( %truncated ) . " names:\n";
            warn "\t" . join( "\n\t", sort keys %truncated ) . "\n";
        }

        if ( %unreserve ) {
            warn "Encounted " . keys( %unreserve ) .
                " unsafe names in schema (reserved or invalid):\n";
            warn "\t" . join( "\n\t", sort keys %unreserve ) . "\n";
        }
    }

    return $output;
}

# -------------------------------------------------------------------
sub mk_name {
    my $basename      = shift || ''; 
    my $type          = shift || ''; 
    my $scope         = shift || ''; 
    my $critical      = shift || '';
    my $basename_orig = $basename;
    my $max_name      = $type 
                        ? $max_id_length - (length($type) + 1) 
                        : $max_id_length;
    $basename         = substr( $basename, 0, $max_name ) 
                        if length( $basename ) > $max_name;
    my $name          = $type ? "${type}_$basename" : $basename;

    if ( $basename ne $basename_orig and $critical ) {
        my $show_type = $type ? "+'$type'" : "";
        warn "Truncating '$basename_orig'$show_type to $max_id_length ",
            "character limit to make '$name'\n" if $WARN;
        $truncated{ $basename_orig } = $name;
    }

    $scope ||= \%global_names;
    if ( my $prev = $scope->{ $name } ) {
        my $name_orig = $name;
        $name        .= sprintf( "%02d", ++$prev );
        substr($name, $max_id_length - 3) = "00" 
            if length( $name ) > $max_id_length;

        warn "The name '$name_orig' has been changed to ",
             "'$name' to make it unique.\n" if $WARN;

        $scope->{ $name_orig }++;
    }

    $scope->{ $name }++;
    return $name;
}

# -------------------------------------------------------------------
sub unreserve {
    my $name            = shift || '';
    my $schema_obj_name = shift || '';

    my ( $suffix ) = ( $name =~ s/(\W.*)$// ) ? $1 : '';

    # also trap fields that don't begin with a letter
    return $name if !$ora_reserved{ uc $name } && $name =~ /^[a-z]/i; 

    if ( $schema_obj_name ) {
        ++$unreserve{"$schema_obj_name.$name"};
    }
    else {
        ++$unreserve{"$name (table name)"};
    }

    my $unreserve = sprintf '%s_', $name;
    return $unreserve.$suffix;
}

1;

# -------------------------------------------------------------------
# All bad art is the result of good intentions.
# Oscar Wilde
# -------------------------------------------------------------------

=head1 NAME

SQL::Translator::Producer::Oracle - Oracle SQL producer

=head1 SYNOPSIS

  use SQL::Translator::Parser::MySQL;
  use SQL::Translator::Producer::Oracle;

  my $original_create = ""; # get this from somewhere...
  my $translator = SQL::Translator->new;

  $translator->parser("SQL::Translator::Parser::MySQL");
  $translator->producer("SQL::Translator::Producer::Oracle");

  my $new_create = $translator->translate($original_create);

=head1 DESCRIPTION

SQL::Translator::Producer::Oracle takes a parsed data structure,
created by a SQL::Translator::Parser subclass, and turns it into a
create string suitable for use with an Oracle database.

=head1 CREDITS

A hearty "thank-you" to Tim Bunce for much of the logic stolen from 
his "mysql2ora" script.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=head1 SEE ALSO

perl(1).

=cut
