# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-workermanager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::WorkerManager::Mojolicious::Application::Controller::Swagger2::Backup 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

use parent 'Navel::Base::Daemon::Mojolicious::Application::Controller::Swagger2::Backup';

#-> methods

sub save_all_configuration {
    my $controller = shift;

    $controller->SUPER::save_all_configuration(
        @_,
        $controller->daemon->{core}->{definitions}->async_write,
        $controller->daemon->{core}->{meta}->async_write
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

Navel::Base::WorkerManager::Mojolicious::Application::Controller::Swagger2::Backup

=head1 COPYRIGHT

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-workermanager is licensed under the Apache License, Version 2.0

=cut
