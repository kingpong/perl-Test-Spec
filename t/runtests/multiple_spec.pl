#!/usr/bin/env perl
#
# done_testing_spec.pl
#
# Helper for testing runtests(@patterns) with done_testing()
#
########################################################################
#

use Test::Spec;

describe "Test One" => sub {
  it "passes" => sub { pass };
};

describe "Test Two" => sub {
  it "passes" => sub { pass };
};

runtests("One");
runtests("Two");
