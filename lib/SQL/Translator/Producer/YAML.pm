package SQL::Translator::Producer::YAML;

# -------------------------------------------------------------------
# $Id: YAML.pm,v 1.6 2003/10/17 19:48:38 dlc Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 darren chamberlain <darren@cpan.org>,
#   Ken Y. Clark <kclark@cpan.org>.
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

=head1 NAME

SQL::Translator::Producer::YAML - A YAML producer for SQL::Translator

=head1 SYNOPSIS

  use SQL::Translator;

  my $translator = SQL::Translator->new(producer => 'YAML');

=head1 DESCRIPTION

This module uses YAML to serialize a schema to a string so that it
can be saved to disk.  Serializing a schema and then calling producers
on the stored can realize significant performance gains when parsing
takes a long time.

=cut

use strict;
use vars qw($VERSION);
$VERSION = sprintf "%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/;

use YAML qw(Dump);

# -------------------------------------------------------------------
sub produce {
    my $translator  = shift;
    my $schema      = $translator->schema;

    return Dump({
        schema => {
            tables => { 
                map { ($_->name => view_table($_)) }
                    $schema->get_tables,
            },
            views => { 
                map { ($_->name => view_view($_)) }
                    $schema->get_views,
            },
            triggers => { 
                map { ($_->name => view_trigger($_)) }
                    $schema->get_triggers,
            },
            procedures => { 
                map { ($_->name => view_procedure($_)) } 
                    $schema->get_procedures,
            },
        }
    });
}

# -------------------------------------------------------------------
sub view_table {
    my $table = shift;

    return {
        'name'     => $table->name,
        'order'    => $table->order,
        'options'  => $table->options  || [],
        'comments' => $table->comments || '',
        'indices'  => {
            map { ($_->name => view_index($_)) }
                $table->get_indices
        },
        'fields'   => { 
            map { ($_->name => view_field($_)) }
                $table->get_fields 
        },
    };
}

# -------------------------------------------------------------------
sub view_field {
    my $field = shift;

    return {
        'order'          => scalar $field->order,
        'name'           => scalar $field->name,
        'data_type'      => scalar $field->data_type,
        'size'           => [ $field->size ],
        'default_value'  => scalar $field->default_value,
        'is_nullable'    => scalar $field->is_nullable,
        'is_primary_key' => scalar $field->is_primary_key,
        'is_unique'      => scalar $field->is_unique,
        'extra'          => { $field->extra },
    };
}

# -------------------------------------------------------------------
sub view_procedure {
    my $procedure = shift;

    return {
        'order'      => scalar $procedure->order,
        'name'       => scalar $procedure->name,
        'sql'        => scalar $procedure->sql,
        'parameters' => scalar $procedure->parameters,
        'owner'      => scalar $procedure->owner,
        'comments'   => scalar $procedure->comments,
    };
}

# -------------------------------------------------------------------
sub view_trigger {
    my $trigger = shift;

    return {
        'order'               => scalar $trigger->order,
        'name'                => scalar $trigger->name,
        'perform_action_when' => scalar $trigger->perform_action_when,
        'database_event'      => scalar $trigger->database_event,
        'fields'              => scalar $trigger->fields,
        'on_table'            => scalar $trigger->on_table,
        'action'              => scalar $trigger->action,
    };
}

# -------------------------------------------------------------------
sub view_view {
    my $view = shift;

    return {
        'order'  => scalar $view->order,
        'name'   => scalar $view->name,
        'sql'    => scalar $view->sql,
        'fields' => scalar $view->fields,
    };
}

# -------------------------------------------------------------------
sub view_index {
    my $index = shift;

    return {
        'name'      => scalar $index->name,
        'type'      => scalar $index->type,
        'fields'    => scalar $index->fields,
        'options'   => scalar $index->options,
    };
}

1;

# -------------------------------------------------------------------

=head1 SEE ALSO

SQL::Translator, YAML, http://www.yaml.org/.

=head1 AUTHORS

darren chamberlain E<lt>darren@cpan.orgE<gt>,
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=cut
