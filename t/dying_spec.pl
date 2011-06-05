#!/usr/bin/env perl
#
# dying_test.pl
#
# Expected to fail. It should output TAP in such a way that prove(1)
# will display the exception message.
#
########################################################################
#

use Test::Spec;

describe "Test::Spec" => sub {
  it "should trap die message" => sub {
    die "this should be displayed";
  };
  it "should continue testing" => sub {
    ok(1);
  };
};

runtests unless caller;
