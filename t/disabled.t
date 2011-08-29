#!/usr/bin/env perl
#
# disabled.t
#
# Disabled specs.
#
########################################################################
#

package Testcase::Spec::Disabled;
use Test::Spec;

describe 'Test::Spec' => sub {
    xdescribe 'disabled spec' => sub {
        it 'should not execute any examples' => sub {
            fail;
        };
    };

    xit 'should not execute disabled example' => sub {
        fail;
    };

    it 'should execute enabled example' => sub {
        pass;
    };
};

runtests unless caller;
