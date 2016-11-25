# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-workermanager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::WorkerManager::Mojolicious::Application::Controller::OpenAPI::Worker 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

#-> methods

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

    return $controller->resource_not_found($name) unless defined $definition;

    $controller->render(
        openapi => $definition,
        status => 200
    );
}

sub create {
    my $controller = shift->openapi->valid_input || return;

    my $definition = $controller->validation->param('definition');

    return $controller->resource_already_exists($definition->{name}) if defined $controller->daemon->{core}->{definitions}->definition_by_name($definition->{name});

    my (@ok, @ko);

    local $@;

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
        openapi => $controller->ok_ko(\@ok, \@ko),
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

    return $controller->resource_not_found($name) unless defined $definition;

    my (@ok, @ko);

    local $@;

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
        openapi => $controller->ok_ko(\@ok, \@ko),
        status => @ko ? 400 : 200
    );
}

sub delete {
    my $controller = shift->openapi->valid_input || return;

    my $name = $controller->validation->param('name');

    my $definition = $controller->daemon->{core}->{definitions}->definition_by_name($name);

    return $controller->resource_not_found($name) unless defined $definition;

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

    $controller->render(
        openapi => $controller->ok_ko(\@ok, \@ko),
        status => @ko ? 400 : 200
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

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-workermanager is licensed under the Apache License, Version 2.0

=cut
