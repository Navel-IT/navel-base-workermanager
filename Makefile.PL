# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-workermanager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

use strict;
use warnings;

use ExtUtils::MakeMaker;

#-> main

my $min_perl_version = '5.18.0';

WriteMakefile(
    NAME => 'Navel::Base::WorkerManager',
    VERSION_FROM => 'lib/Navel/Base/WorkerManager.pm',
    ABSTRACT => 'navel-base-workermanager',
    AUTHOR => 'Yoann Le Garff, Nicolas Boquet and Yann Le Bras',
    LICENSE => 'apache_2_0',
    META_MERGE => {
        requires => {
            perl => $min_perl_version
        },
        resources => {
            license => 'http://www.apache.org/licenses/LICENSE-2.0.html',
            repository => 'http://github.com/Navel-IT/navel-base-workermanager'
        }
    },
    MIN_PERL_VERSION => $min_perl_version,
    PREREQ_PM => {
        'Navel::Base' => 0,
        'Navel::Base::Daemon' => 0,
        'Navel::AnyEvent::Fork::RPC::Serializer::Sereal' => 0,
        'Navel::Logger' => 0,
        'AnyEvent' => 0,
        'AnyEvent::Fork' => 0,
        'AnyEvent::Fork::RPC' => 0,
        'Promises' => 0,
        'Mojolicious' => 0
    },
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 6.64
    },
    TEST_REQUIRES => {
        'Test::More' => 0
    },
    test => {
        TESTS => 't/*.t'
    }
);

#-> END

__END__
