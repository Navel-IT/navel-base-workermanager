# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-workermanager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::WorkerManager::Mojolicious::Application::Controller::OpenAPI::Worker 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

use Navel::Utils 'croak';

use Promises 'collect';

#-> methods

sub _show_associated_queue {
    my ($controller, $action) = (shift->openapi->valid_input || return, shift);

    croak('action must be defined') unless defined $action;

    my $name = $controller->validation->param('name');

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($name);

    return $controller->navel->api->responses->resource_not_found($name) unless defined $definition;

    $controller->render_later;

    $controller->daemon->{core}->{worker_per_definition}->{$definition->{name}}->rpc(undef, $action)->then(
        sub {
            $controller->render(
                openapi => {
                    amount_of_events => shift
                },
                status => 200
            );
        }
    )->catch(
        sub {
            $controller->render(
                openapi => $controller->navel->logger->ok_ko(
                    [],
                    [
                        $definition->full_name . ': ' . (@_ ? join ', ', @_ : 'unexpected error') . '.'
                    ]
                ),
                status => 500
            );
        }
    );
}

sub _delete_all_events_from_associated_queue {
    my ($controller, $action) = (shift->openapi->valid_input || return, shift);

    croak('action must be defined') unless defined $action;

    my $name = $controller->validation->param('name');

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($name);

    return $controller->navel->api->responses->resource_not_found($name) unless defined $definition;

    $controller->render_later;

    my (@ok, @ko);

    $controller->daemon->{core}->{worker_per_definition}->{$definition->{name}}->rpc(undef, $action)->then(
        sub {
            push @ok, $definition->full_name . ': queue cleared (' . $action . ').';
        }
    )->catch(
        sub {
            push @ko, $definition->full_name . ': ' . (@_ ? join ', ', @_ : 'unexpected error') . '.';
        }
    )->finally(
        sub {
            $controller->render(
                openapi => $controller->navel->logger->ok_ko(\@ok, \@ko),
                status => @ko ? 500 : 200
            );
        }
    );
}

sub _show_associated_pubsub_connection_status {
    my ($controller, $backend) = (shift->openapi->valid_input || return, shift);

    croak('backend must be defined') unless defined $backend;

    my $name = $controller->validation->param('name');

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($name);

    return $controller->navel->api->responses->resource_not_found($name) unless defined $definition;

    my $worker_worker = $controller->daemon->{core}->{worker_per_definition}->{$definition->{name}};

    $controller->render_later;

    my $connectable;

    $worker_worker->rpc($definition->{$backend}, 'is_connectable')->then(
        sub {
            collect(
                $worker_worker->rpc($definition->{$backend}, 'is_connecting'),
                $worker_worker->rpc($definition->{$backend}, 'is_connected'),
                $worker_worker->rpc($definition->{$backend}, 'is_disconnecting'),
                $worker_worker->rpc($definition->{$backend}, 'is_disconnected')
            ) if $connectable = shift;
        }
    )->then(
        sub {
            my %status;

            ($status{connecting}, $status{connected}, $status{disconnecting}, $status{disconnected}) = @_;

            $status{$_} = $status{$_}->[0] ? 1 : 0 for keys %status;

            $status{connectable} = $connectable ? 1 : 0;

            $controller->render(
                openapi => \%status,
                status => 200
            );
        }
    )->catch(
        sub {
            $controller->render(
                openapi => $controller->navel->logger->ok_ko(
                    [],
                    [
                        $definition->full_name . ': ' . (@_ ? join ', ', @_ : 'unexpected error') . '.'
                    ]
                ),
                status => 500
            );
        }
    );
}

sub list {
    my $controller = shift->openapi->valid_input || return;

    $controller->render(
        openapi => $controller->daemon->{core}->{definitions}->all_by_property_name('name'),
        status => 200
    );
}

sub show {
    my $controller = shift->openapi->valid_input || return;

    my $name = $controller->validation->param('name');

    my $definition = $controller->daemon->{core}->{definitions}->definition_properties_by_name($name);

    return $controller->navel->api->responses->resource_not_found($name) unless defined $definition;

    $controller->render(
        openapi => $definition,
        status => 200
    );
}

sub create {
    my $controller = shift->openapi->valid_input || return;

    my $definition = $controller->validation->param('definition');

    return $controller->navel->api->responses->resource_already_exists($definition->{name}) if defined $controller->daemon->{core}->{definitions}->definition_by_name($definition->{name});

    my (@ok, @ko);

    $definition = eval {
        $controller->daemon->{core}->{definitions}->add_definition($definition);
    };

    unless ($@) {
        $controller->daemon->{core}->init_worker_by_name($definition->{name})->register_worker_by_name($definition->{name});

        push @ok, $definition->full_name . ': added.';
    } else {
        push @ko, $@;
    }

    $controller->render(
        openapi => $controller->navel->logger->ok_ko(\@ok, \@ko),
        status => @ko ? 400 : 201
    );
}

sub update {
    my $controller = shift->openapi->valid_input || return;

    my ($name, $base_definition) = (
        $controller->validation->param('name'),
        $controller->validation->param('baseDefinition')
    );

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($name);

    return $controller->navel->api->responses->resource_not_found($name) unless defined $definition;

    my (@ok, @ko);

    delete $base_definition->{name};

    my $merged_definition = {
        %{$definition->properties},
        %{$base_definition}
    };

    eval {
        $controller->daemon->{core}->delete_worker_and_definition_associated_by_name($merged_definition->{name});
    };

    unless ($@) {
        $definition = eval {
            $controller->daemon->{core}->{definitions}->add_definition($merged_definition);
        };

        unless ($@) {
            $controller->daemon->{core}->init_worker_by_name($definition->{name})->register_worker_by_name($definition->{name});

            push @ok, $definition->full_name . ': updated.';
        } else {
            push @ko, $@;
        }
    } else {
        push @ko, $@;
    }

    $controller->render(
        openapi => $controller->navel->logger->ok_ko(\@ok, \@ko),
        status => @ko ? 400 : 200
    );
}

sub delete {
    my $controller = shift->openapi->valid_input || return;

    my $name = $controller->validation->param('name');

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($name);

    return $controller->navel->api->responses->resource_not_found($name) unless defined $definition;

    my (@ok, @ko);

    eval {
        $controller->daemon->{core}->delete_worker_and_definition_associated_by_name($definition->{name});
    };

    unless ($@) {
        push @ok, $definition->full_name . ': killed, unregistered and deleted.';
    } else {
        push @ko, $@;
    }

    $controller->render(
        openapi => $controller->navel->logger->ok_ko(\@ok, \@ko),
        status => @ko ? 400 : 200
    );
}

sub show_worker_status {
    my $controller = shift->openapi->valid_input || return;

    my $name = $controller->validation->param('name');

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($name);

    return $controller->navel->api->responses->resource_not_found($name) unless defined $definition;

    $controller->render(
        openapi => {
            initialized => $controller->daemon->{core}->{worker_per_definition}->{$definition->{name}}->{initialized},
            healthy => $controller->daemon->{core}->{worker_per_definition}->{$definition->{name}}->is_healthy
        },
        status => 200
    );
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Base::WorkerManager::Mojolicious::Application::Controller::OpenAPI::Worker

=head1 COPYRIGHT

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-workermanager is licensed under the Apache License, Version 2.0

=cut
