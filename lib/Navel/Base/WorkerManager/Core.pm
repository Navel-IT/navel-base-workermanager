# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-workermanager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::WorkerManager::Core 0.1;

use Navel::Base;

use parent 'Navel::Base::Daemon::Core';

use AnyEvent::Fork;

use Navel::Utils 'croak';

#-> methods

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    $self->{worker_per_definition} = {};

    $self->{ae_fork} = AnyEvent::Fork->new;

    $self;
}

sub init_workers {
    my $self = shift;

    $self->init_worker_by_name($_->{name}) for @{$self->{definitions}->{definitions}};

    $self;
}

sub register_workers {
    my $self = shift;

    $self->register_worker_by_name($_->{name}) for @{$self->{definitions}->{definitions}};

    $self;
}

sub delete_worker_and_definition_associated_by_name {
    my ($self, $job_type) = splice @_, 0, 2;

    croak('job_type must be defined') unless defined $job_type;

    my $definition = $self->{definitions}->definition_by_name(shift);

    die "unknown worker\n" unless defined $definition;

    $self->unregister_job_by_type_and_name($job_type, $definition->{name})->{definitions}->delete_definition(
        definition_name => $definition->{name}
    );

    delete $self->{worker_per_definition}->{$definition->{name}};

    $self;
}

sub delete_workers {
    my $self = shift;

    $self->delete_worker_and_definition_associated_by_name($_->{name}) for my @names = @{$self->{definitions}->{definitions}};

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

Navel::Base::WorkerManager::Core

=head1 COPYRIGHT

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-workermanager is licensed under the Apache License, Version 2.0

=cut
