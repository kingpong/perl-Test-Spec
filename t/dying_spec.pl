#!/usr/bin/env perl
#
# dying_test.pl
#
# Expected to fail. It should output TAP in such a way that prove(1)
# will display the exception message.
#
########################################################################
#
# override Test::Harness's insistence on using "perl -w"
BEGIN { $^W = 0 }
BEGIN { open(STDERR, ">&STDOUT") }  # 2>&1

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
