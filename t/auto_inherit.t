#!/usr/bin/env perl
#
# auto_inherit.t
#
########################################################################
#
# override Test::Harness's insistence on using "perl -w"
BEGIN { $^W = 0 }

package Testcase::Spec::AutoInherit;
use Test::Spec;
use strict;
use warnings;

describe "Test::Spec" => sub {
  it "should insert itself into the inheritance chain of any package that imports it" => sub {
    ok( Testcase::Spec::AutoInherit->isa('Test::Spec') );
  };
};

runtests unless caller;
