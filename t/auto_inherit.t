#!/usr/bin/env perl
#
# auto_inherit.t
#
########################################################################
#

package Testcase::Spec::AutoInherit;
use Test::Spec;

describe "Test::Spec" => sub {
  it "should insert itself into the inheritance chain of any package that imports it" => sub {
    ok( Testcase::Spec::AutoInherit->isa('Test::Spec') );
  };
};

runtests unless caller;
