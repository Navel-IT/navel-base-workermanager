# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-workermanager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::WorkerManager::Mojolicious::Application::Controller::Swagger2::Worker 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

#-> methods

sub list {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        $controller->daemon->{core}->{definitions}->all_by_property_name('name'),
        200
    );
}

sub show {
    my ($controller, $arguments, $callback) = @_;

    my $definition = $controller->daemon->{core}->{definitions}->definition_properties_by_name($arguments->{name});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{name}
        }
    ) unless defined $definition;

    $controller->$callback(
        $definition,
        200
    );
}

sub new {
    my ($controller, $arguments, $callback) = @_;

    return $controller->resource_already_exists(
        {
            callback => $callback,
            resource_name => $arguments->{definition}->{name}
        }
    ) if defined $controller->daemon->{core}->{definitions}->definition_by_name($arguments->{definition}->{name});

    my (@ok, @ko);

    local $@;

    my $definition = eval {
        $controller->daemon->{core}->{definitions}->add_definition($arguments->{definition});
    };

    unless ($@) {
        $controller->daemon->{core}->init_worker_by_name($definition->{name})->register_worker_by_name($definition->{name});

        push @ok, $definition->full_name . ': added.';
    } else {
        push @ko, $@;
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 201
    );
}

sub update {
    my ($controller, $arguments, $callback) = @_;

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($arguments->{name});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{name}
        }
    ) unless defined $definition;

    my (@ok, @ko);

    local $@;

    delete $arguments->{baseDefinition}->{name};

    my $merged_definition = {
        %{$definition->properties},
        %{$arguments->{baseDefinition}}
    };

    eval {
        $controller->daemon->{core}->delete_worker_and_definition_associated_by_name($merged_definition->{name});
    };

    unless ($@) {
        my $definition = eval {
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

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 200
    );
}

sub delete {
    my ($controller, $arguments, $callback) = @_;

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($arguments->{name});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{name}
        }
    ) unless defined $definition;

    my (@ok, @ko);

    local $@;

    eval {
        $controller->daemon->{core}->delete_worker_and_definition_associated_by_name($definition->{name});
    };

    unless ($@) {
        push @ok, $definition->full_name . ': killed, unregistered and deleted.';
    } else {
        push @ko, $@;
    }

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        @ko ? 400 : 200
    );
}

sub show_associated_queue {
    my ($controller, $arguments, $callback) = @_;

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($arguments->{name});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{name}
        }
    ) unless defined $definition;

    $controller->render_later;

    $controller->daemon->{core}->{worker_per_definition}->{$definition->{name}}->rpc(undef, 'queue')->then(
        sub {
            $controller->$callback(
                {
                    amount_of_events => shift
                },
                200
            );
        }
    )->catch(
        sub {
            $controller->$callback(
                $controller->ok_ko(
                    [],
                    [
                        $definition->full_name . ': ' . (@_ ? join ', ', @_ : 'unexpected error') . '.'
                    ]
                ),
                500
            );
        }
    );
}

sub delete_all_events_from_the_associated_queue {
    my ($controller, $arguments, $callback) = @_;

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($arguments->{name});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{name}
        }
    ) unless defined $definition;

    $controller->render_later;

    my (@ok, @ko);

    $controller->daemon->{core}->{worker_per_definition}->{$definition->{name}}->rpc(undef, 'dequeue')->then(
        sub {
            push @ok, $definition->full_name . ': queue cleared.';
        }
    )->catch(
        sub {
            push @ko, $definition->full_name . ': ' . (@_ ? join ', ', @_ : 'unexpected error') . '.';
        }
    )->finally(
        sub {
            $controller->$callback(
                $controller->ok_ko(\@ok, \@ko),
                @ko ? 500 : 200
            );
        }
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

Navel::Base::WorkerManager::Mojolicious::Application::Controller::Swagger2::Worker

=head1 COPYRIGHT

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-workermanager is licensed under the Apache License, Version 2.0

=cut
