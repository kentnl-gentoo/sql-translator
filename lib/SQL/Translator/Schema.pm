package SQL::Translator::Schema;

# ----------------------------------------------------------------------
# $Id: Schema.pm,v 1.7 2003/06/09 04:40:08 kycl4rk Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>
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

SQL::Translator::Schema - SQL::Translator schema object

=head1 SYNOPSIS

  use SQL::Translator::Schema;
  my $schema = SQL::Translator::Schema->new;
  my $table  = $schema->add_table( name => 'foo' );
  my $view   = $schema->add_view( name => 'bar', sql => '...' );

=head1 DESCSIPTION

C<SQL::Translator::Schema> is the object that accepts, validates, and
returns the database structure.

=head1 METHODS

=cut

use strict;
use Class::Base;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Schema::Table;
use SQL::Translator::Utils 'parse_list_arg';
use SQL::Translator::Schema::View;

use base 'Class::Base';
use vars qw[ $VERSION $TABLE_ORDER $VIEW_ORDER ];

$VERSION = 1.00;

# ----------------------------------------------------------------------
sub init {

=pod

=head2 new

Object constructor.

  my $schema   =  SQL::Translator->new(
      name     => 'Foo',
      database => 'MySQL',
  );

=cut

    my ( $self, $config ) = @_;
    $self->params( $config, qw[ name database ] ) || return undef;
    return $self;
}

# ----------------------------------------------------------------------
sub add_table {

=pod

=head2 add_table

Add a table object.  Returns the new SQL::Translator::Schema::Table object.
The "name" parameter is required.  If you try to create a table with the
same name as an existing table, you will get an error and the table will 
not be created.

  my $t1 = $schema->add_table( name => 'foo' ) or die $schema->error;
  my $t2 = SQL::Translator::Schema::Table->new( name => 'bar' );
  $t2    = $schema->add_table( $table_bar ) or die $schema->error;

=cut

    my $self        = shift;
    my $table_class = 'SQL::Translator::Schema::Table';
    my $table;

    if ( UNIVERSAL::isa( $_[0], $table_class ) ) {
        $table = shift;
        $table->schema( $self );
    }
    else {
        my %args = @_;
        $args{'schema'} = $self;
        $table = $table_class->new( \%args ) or return 
            $self->error( $table_class->error );
    }

    $table->order( ++$TABLE_ORDER );
    my $table_name = $table->name or return $self->error('No table name');

    if ( defined $self->{'tables'}{ $table_name } ) {
        return $self->error(qq[Can't create table: "$table_name" exists]);
    }
    else {
        $self->{'tables'}{ $table_name } = $table;
    }

    return $table;
}

# ----------------------------------------------------------------------
sub add_view {

=pod

=head2 add_view

Add a view object.  Returns the new SQL::Translator::Schema::View object.
The "name" parameter is required.  If you try to create a view with the
same name as an existing view, you will get an error and the view will 
not be created.

  my $v1 = $schema->add_view( name => 'foo' );
  my $v2 = SQL::Translator::Schema::View->new( name => 'bar' );
  $v2    = $schema->add_view( $view_bar ) or die $schema->error;

=cut

    my $self        = shift;
    my $view_class = 'SQL::Translator::Schema::View';
    my $view;

    if ( UNIVERSAL::isa( $_[0], $view_class ) ) {
        $view = shift;
    }
    else {
        my %args = @_;
        return $self->error('No view name') unless $args{'name'};
        $view = $view_class->new( \%args ) or return $view_class->error;
    }

    $view->order( ++$VIEW_ORDER );
    my $view_name = $view->name or return $self->error('No view name');

    if ( defined $self->{'views'}{ $view_name } ) { 
        return $self->error(qq[Can't create view: "$view_name" exists]);
    }
    else {
        $self->{'views'}{ $view_name } = $view;
    }

    return $view;
}

# ----------------------------------------------------------------------
sub database {

=pod

=head2 database

Get or set the schema's database.  (optional)

  my $database = $schema->database('PostgreSQL');

=cut

    my $self = shift;
    $self->{'database'} = shift if @_;
    return $self->{'database'} || '';
}

# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Returns true if all the tables and views are valid.

  my $ok = $schema->is_valid or die $schema->error;

=cut

    my $self = shift;

    return $self->error('No tables') unless $self->get_tables;

    for my $object ( $self->get_tables, $self->get_views ) {
        return $object->error unless $object->is_valid;
    }

    return 1;
}

# ----------------------------------------------------------------------
sub get_table {

=pod

=head2 get_table

Returns a table by the name provided.

  my $table = $schema->get_table('foo');

=cut

    my $self       = shift;
    my $table_name = shift or return $self->error('No table name');
    return $self->error( qq[Table "$table_name" does not exist] ) unless
        exists $self->{'tables'}{ $table_name };
    return $self->{'tables'}{ $table_name };
}

# ----------------------------------------------------------------------
sub get_tables {

=pod

=head2 get_tables

Returns all the tables as an array or array reference.

  my @tables = $schema->get_tables;

=cut

    my $self   = shift;
    my @tables = 
        map  { $_->[1] } 
        sort { $a->[0] <=> $b->[0] } 
        map  { [ $_->order, $_ ] }
        values %{ $self->{'tables'} };

    if ( @tables ) {
        return wantarray ? @tables : \@tables;
    }
    else {
        $self->error('No tables');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub get_view {

=pod

=head2 get_view

Returns a view by the name provided.

  my $view = $schema->get_view('foo');

=cut

    my $self      = shift;
    my $view_name = shift or return $self->error('No view name');
    return $self->error('View "$view_name" does not exist') unless
        exists $self->{'views'}{ $view_name };
    return $self->{'views'}{ $view_name };
}

# ----------------------------------------------------------------------
sub get_views {

=pod

=head2 get_views

Returns all the views as an array or array reference.

  my @views = $schema->get_views;

=cut

    my $self  = shift;
    my @views = 
        map  { $_->[1] } 
        sort { $a->[0] <=> $b->[0] } 
        map  { [ $_->order, $_ ] }
        values %{ $self->{'views'} };

    if ( @views ) {
        return wantarray ? @views : \@views;
    }
    else {
        $self->error('No views');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub make_natural_joins {

=pod

=head2 make_natural_joins

Creates foriegn key relationships among like-named fields in different
tables.  Accepts the following arguments:

=over 4

=item * join_pk_only 

A True or False argument which determins whether or not to perform 
the joins from primary keys to fields of the same name in other tables

=item * skip_fields

A list of fields to skip in the joins

=back 4

  $schema->make_natural_joins(
      join_pk_only => 1,
      skip_fields  => 'name,department_id',
  );

=cut

    my $self         = shift;
    my %args         = @_;
    my $join_pk_only = $args{'join_pk_only'} || 0;
    my %skip_fields  = map { s/^\s+|\s+$//g; $_, 1 } @{ 
        parse_list_arg( $args{'skip_fields'} ) 
    };

    my ( %common_keys, %pk );
    for my $table ( $self->get_tables ) {
        for my $field ( $table->get_fields ) {
            my $field_name = $field->name or next;
            next if $skip_fields{ $field_name };
            $pk{ $field_name } = 1 if $field->is_primary_key;
            push @{ $common_keys{ $field_name } }, $table->name;
        }
    } 
   
    for my $field ( keys %common_keys ) {
        next if $join_pk_only and !defined $pk{ $field };

        my @table_names = @{ $common_keys{ $field } };
        next unless scalar @table_names > 1;

        for my $i ( 0 .. $#table_names ) {
            my $table1 = $self->get_table( $table_names[ $i ] ) or next;

            for my $j ( 1 .. $#table_names ) {
                my $table2 = $self->get_table( $table_names[ $j ] ) or next;
                next if $table1->name eq $table2->name;

                $table1->add_constraint(
                    type             => FOREIGN_KEY,
                    fields           => $field,
                    reference_table  => $table2->name,
                    reference_fields => $field,
                );
            }               
        }
    } 

    return 1;
}

# ----------------------------------------------------------------------
sub name {

=pod

=head2 name

Get or set the schema's name.  (optional)

  my $schema_name = $schema->name('Foo Database');

=cut

    my $self = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub DESTROY {
    my $self = shift;
    undef $_ for values %{ $self->{'tables'} };
    undef $_ for values %{ $self->{'views'}  };
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
