#!/usr/bin/env perl
#
# shared_examples_spec.pl
#
# Test cases for Test::Spec shared example definition and inclusion.
# Generates TAP to be checked by shared_examples.t
#
########################################################################
#
package Testcase::Spec::SharedExamplesSpec;
use Test::Spec;
use FindBin qw($Bin);
BEGIN { require "$Bin/test_helper.pl" };

shared_examples_for "example group" => sub {
  it "can take at least one example";
  it "can take more than one example";
  describe "with an inner block" => sub {
    it "nests properly";
  };
};

describe "A context importing an example group" => sub {
  it_should_behave_like "example group";
  it "can have custom behavior";
};

describe "Another context" => sub {
  describe "importing an example group" => sub {
    it_should_behave_like "example group";
    it "can have custom behavior, too";
  };
  it "can have behavior that doesn't interfere with example groups in sub-contexts";
};

describe "Another context" => sub {
  describe "importing an example group" => sub {
    it "accumulates examples in the same way that describe() does";
  };
};

shared_examples_for "example group" => sub {
  it "can be reopened";
};


# A context importing an example group can take at least one example
# A context importing an example group can take more than one example
# A context importing an example group can be reopened
# A context importing an example group with an inner block nests properly

runtests unless caller;
