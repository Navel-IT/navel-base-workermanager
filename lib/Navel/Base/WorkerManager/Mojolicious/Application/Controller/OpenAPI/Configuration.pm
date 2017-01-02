# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-workermanager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::WorkerManager::Mojolicious::Application::Controller::OpenAPI::Configuration 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

use parent 'Navel::Base::Daemon::Mojolicious::Application::Controller::OpenAPI::Configuration';

#-> methods

sub save {
    my $controller = shift;

    $controller->SUPER::save(
        $controller->daemon->{core}->{definitions}->async_write,
        $controller->daemon->{core}->{meta}->async_write,
        @_
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

Navel::Base::WorkerManager::Mojolicious::Application::Controller::OpenAPI::Configuration

=head1 COPYRIGHT

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-workermanager is licensed under the Apache License, Version 2.0

=cut
