# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-workermanager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::WorkerManager 0.1;

use Navel::Base;

use parent 'Navel::Base::Daemon';

use AnyEvent;

#-> class variables

my @signal_watchers;

#-> methods

sub run {
    shift->SUPER::run(
        before_starting => sub {
            my $self = shift;

            push @signal_watchers, AnyEvent->signal(
                signal => $_,
                cb => sub {
                    $self->stop(
                        sub {
                            exit;
                        }
                    );
                }
            ) for qw/
                INT
                QUIT
                TERM
            /;
        },
        @_
    );
}

sub start {
    my $self = shift;

    $self->SUPER::start(@_)->{core}->init_workers->register_workers;

    $self;
}

sub stop {
    my ($self, $callback) = @_;

    state $stopping;

    unless ($stopping) {
        $stopping = 1;

        $self->{core}->{logger}->notice('stopping.');

        $self->webserver(0) if $self->webserver;

        $self->{core}->delete_workers;

        my $wait; $wait = AnyEvent->timer(
            after => 5,
            cb => sub {
                undef $wait;

                $self->{core}->send;

                $callback->($self) if ref $callback eq 'CODE';

                $stopping = 0;
            }
        );
    }

    $self;
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Base::WorkerManager

=head1 COPYRIGHT

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-workermanager is licensed under the Apache License, Version 2.0

=cut
