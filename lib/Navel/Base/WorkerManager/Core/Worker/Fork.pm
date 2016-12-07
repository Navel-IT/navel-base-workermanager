# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-workermanager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::WorkerManager::Core::Worker::Fork 0.1;

use Navel::Base;

use AnyEvent::Fork;
use AnyEvent::Fork::RPC;

use Promises 'deferred';

use Navel::Logger::Message;
use Navel::AnyEvent::Fork::RPC::Serializer::Sereal;

use Navel::Utils qw/
    blessed
    croak
    weaken
/;

#-> methods

sub new {
    my ($class, %options) = @_;

    my $self;

    if (ref $class) {
        $self = $class;
    } else {
        croak('core class is invalid') unless blessed($options{core}) && $options{core}->isa('Navel::Base::WorkerManager::Core');

        croak('definition is invalid') unless blessed($options{definition}) && $options{definition}->isa('Navel::Base::Definition');

        $self = bless {
            core => $options{core},
            definition => $options{definition},
            worker_package => 'W',
            worker_rpc_method => '_worker'
        }, $class;
    }

    $self->{initialized} = 0;

    my $weak_self = $self;

    weaken($weak_self);

    my $wrapped_code = $self->wrapped_code;

    $self->{core}->{logger}->debug(
        Navel::Logger::Message->stepped_message($self->{definition}->full_name . ': dump of the source.',
            [
                split /\n/, $wrapped_code
            ]
        )
    );

    $self->{rpc} = $self->{core}->{ae_fork}->fork->eval($wrapped_code)->AnyEvent::Fork::RPC::run(
        $self->{worker_package} . '::' . $self->{worker_rpc_method},
        on_event => $options{on_event},
        on_error => sub {
            undef $weak_self->{rpc};

            $options{on_error}->(@_);
        },
        on_destroy => $options{on_destroy},
        async => 1,
        serialiser => Navel::AnyEvent::Fork::RPC::Serializer::Sereal::SERIALIZER
    );

    $self->{core}->{logger}->info($self->{definition}->full_name . ': spawned a new worker.');

    $self;
}

sub is_healthy {
    my $self = shift;

    blessed($self->{rpc}) && $self->{rpc}->isa('AnyEvent::Fork::RPC') || 0;
}

sub rpc {
    my $self = shift;

    my $deferred = deferred;

    if ($self->is_healthy) {
        my @definitions;

        unless ($self->{initialized}) {
            $self->{initialized} = 1;

            push @definitions, $self->{core}->{meta}->{definition}, $self->{definition}->properties;
        }

        $self->{rpc}->(
            @_,
            @definitions,
            sub {
                shift() ? $deferred->resolve(@_) : $deferred->reject(@_);
            }
        );
    } else {
        $deferred->reject('the worker is broken');
    }

    $deferred->promise;
}

# sub AUTOLOAD {}

sub DESTROY {
    my $self = shift;

    local $@;

    eval {
        $self->rpc;

        undef $self->{rpc};
    };

    $self;
}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Base::WorkerManager::Core::Worker::Fork

=head1 COPYRIGHT

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-workermanager is licensed under the Apache License, Version 2.0

=cut
