#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

use Data::Dumper;
use FindBin qw/$Bin/;

# Testing 1,2,3,4...
#=============================================================================

BEGIN {
    maybe_plan(17,
        'SQL::Translator::Producer::PostgreSQL',
        'Test::Differences',
    )
}
use Test::Differences;
use SQL::Translator;

my $PRODUCER = \&SQL::Translator::Producer::PostgreSQL::create_field;

my $table = SQL::Translator::Schema::Table->new( name => 'mytable');

my $field1 = SQL::Translator::Schema::Field->new( name => 'myfield',
                                                  table => $table,
                                                  data_type => 'VARCHAR',
                                                  size => 10,
                                                  default_value => undef,
                                                  is_auto_increment => 0,
                                                  is_nullable => 1,
                                                  is_foreign_key => 0,
                                                  is_unique => 0 );

my $field1_sql = SQL::Translator::Producer::PostgreSQL::create_field($field1);

is($field1_sql, 'myfield character varying(10)', 'Create field works');

my $field2 = SQL::Translator::Schema::Field->new( name      => 'myfield',
                                                  table => $table,
                                                  data_type => 'VARCHAR',
                                                  size      => 25,
                                                  default_value => undef,
                                                  is_auto_increment => 0,
                                                  is_nullable => 0,
                                                  is_foreign_key => 0,
                                                  is_unique => 0 );

my $alter_field = SQL::Translator::Producer::PostgreSQL::alter_field($field1,
                                                                $field2);
is($alter_field, qq[ALTER TABLE mytable ALTER COLUMN myfield SET NOT NULL
ALTER TABLE mytable ALTER COLUMN myfield TYPE character varying(25)],
 'Alter field works');

$field1->name('field3');
my $add_field = SQL::Translator::Producer::PostgreSQL::add_field($field1);

is($add_field, 'ALTER TABLE mytable ADD COLUMN field3 character varying(10)', 'Add field works');

my $drop_field = SQL::Translator::Producer::PostgreSQL::drop_field($field2);
is($drop_field, 'ALTER TABLE mytable DROP COLUMN myfield', 'Drop field works');

my $field3 = SQL::Translator::Schema::Field->new( name      => 'time_field',
                                                  table => $table,
                                                  data_type => 'TIME',
                                                  default_value => undef,
                                                  is_auto_increment => 0,
                                                  is_nullable => 0,
                                                  is_foreign_key => 0,
                                                  is_unique => 0 );

my $field3_sql = SQL::Translator::Producer::PostgreSQL::create_field($field3);

is($field3_sql, 'time_field time NOT NULL', 'Create time field works');

my $field4 = SQL::Translator::Schema::Field->new( name      => 'bytea_field',
                                                  table => $table,
                                                  data_type => 'bytea',
                                                  size => '16777215',
                                                  default_value => undef,
                                                  is_auto_increment => 0,
                                                  is_nullable => 0,
                                                  is_foreign_key => 0,
                                                  is_unique => 0 );

my $field4_sql = SQL::Translator::Producer::PostgreSQL::create_field($field4);

is($field4_sql, 'bytea_field bytea NOT NULL', 'Create bytea field works');

my $field5 = SQL::Translator::Schema::Field->new( name => 'enum_field',
                                                   table => $table,
                                                   data_type => 'enum',
                                                   extra => { list => [ 'Foo', 'Bar' ] },
                                                   is_auto_increment => 0,
                                                   is_nullable => 0,
                                                   is_foreign_key => 0,
                                                   is_unique => 0 );

my $field5_sql = SQL::Translator::Producer::PostgreSQL::create_field($field5,{ postgres_version => 8.3 });

is($field5_sql, 'enum_field mytable_enum_field_type NOT NULL', 'Create real enum field works');




my $field6 = SQL::Translator::Schema::Field->new(
                                                  name      => 'character',
                                                  table => $table,
                                                  data_type => 'character',
                                                  size => '123',
                                                  default_value => 'foobar',
                                                    is_auto_increment => 0,
                                                    is_nullable => 0,
                                                    is_foreign_key => 0,
                                                    is_unique => 0);

my $field7 = SQL::Translator::Schema::Field->new(
                                name      => 'character',
                                table => $table,
                                data_type => 'character',
                                size => '123',
                                default_value => undef,
                                  is_auto_increment => 0,
                                  is_nullable => 0,
                                  is_foreign_key => 0,
                                  is_unique => 0);

$alter_field = SQL::Translator::Producer::PostgreSQL::alter_field($field6,
                                                                $field7);

is($alter_field, q(ALTER TABLE mytable ALTER COLUMN character DROP DEFAULT), 'DROP DEFAULT');

$field7->default_value(q(foo'bar'));

$alter_field = SQL::Translator::Producer::PostgreSQL::alter_field($field6,
                                                                $field7);

is($alter_field, q(ALTER TABLE mytable ALTER COLUMN character SET DEFAULT 'foo''bar'''), 'DEFAULT with escaping');

$field7->default_value(\q(foobar));

$alter_field = SQL::Translator::Producer::PostgreSQL::alter_field($field6,
                                                                $field7);

is($alter_field, q(ALTER TABLE mytable ALTER COLUMN character SET DEFAULT foobar), 'DEFAULT unescaped if scalarref');

$field7->is_nullable(1);
$field7->default_value(q(foobar));

$alter_field = SQL::Translator::Producer::PostgreSQL::alter_field($field6,
                                                                $field7);

is($alter_field, q(ALTER TABLE mytable ALTER COLUMN character DROP NOT NULL), 'DROP NOT NULL');


{
    # let's test default values! -- rjbs, 2008-09-30
    my %field = (
        table => $table,
        data_type => 'VARCHAR',
        size => 10,
        is_auto_increment => 0,
        is_nullable => 1,
        is_foreign_key => 0,
        is_unique => 0,
    );

    {
        my $simple_default = SQL::Translator::Schema::Field->new(
            %field,
            name => 'str_default',
            default_value => 'foo',
        );

        is(
            $PRODUCER->($simple_default),
            q{str_default character varying(10) DEFAULT 'foo'},
            'default str',
        );
    }

    {
        my $null_default = SQL::Translator::Schema::Field->new(
            %field,
            name => 'null_default',
            default_value => \'NULL',
        );

        is(
            $PRODUCER->($null_default),
            q{null_default character varying(10) DEFAULT NULL},
            'default null',
        );
    }

    {
        my $null_default = SQL::Translator::Schema::Field->new(
            %field,
            name => 'null_default_2',
            default_value => 'NULL', # XXX: this should go away
        );

        is(
            $PRODUCER->($null_default),
            q{null_default_2 character varying(10) DEFAULT NULL},
            'default null from special cased string',
        );
    }

    {
        my $func_default = SQL::Translator::Schema::Field->new(
            %field,
            name => 'func_default',
            default_value => \'func(funky)',
        );

        is(
            $PRODUCER->($func_default),
            q{func_default character varying(10) DEFAULT func(funky)},
            'unquoted default from scalar ref',
        );
    }
}


my $view1 = SQL::Translator::Schema::View->new(
    name   => 'view_foo',
    fields => [qw/id name/],
    sql    => 'SELECT id, name FROM thing',
);
my $create_opts = { add_replace_view => 1, no_comments => 1 };
my $view1_sql1 = SQL::Translator::Producer::PostgreSQL::create_view($view1, $create_opts);

my $view_sql_replace = "CREATE VIEW view_foo ( id, name ) AS
    SELECT id, name FROM thing
";
is($view1_sql1, $view_sql_replace, 'correct "CREATE OR REPLACE VIEW" SQL');

my $view2 = SQL::Translator::Schema::View->new(
    name   => 'view_foo2',
    sql    => 'SELECT id, name FROM thing',
    extra  => {
      'temporary'    => '1',
      'check_option' => 'cascaded',
    },
);
my $create2_opts = { add_replace_view => 1, no_comments => 1 };
my $view2_sql1 = SQL::Translator::Producer::PostgreSQL::create_view($view2, $create2_opts);

my $view2_sql_replace = "CREATE TEMPORARY VIEW view_foo2 AS
    SELECT id, name FROM thing
 WITH CASCADED CHECK OPTION";
is($view2_sql1, $view2_sql_replace, 'correct "CREATE OR REPLACE VIEW" SQL 2');
