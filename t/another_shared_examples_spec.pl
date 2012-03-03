#!/usr/bin/env perl
#
# another_shared_examples_spec.pl
#
# Test cases for Test::Spec shared example definition and inclusion.
# 
# This spec requires a shared example group that is expected to already
# have been defined in shared_examples_spec.pl.
#
########################################################################
#
package Testcase::Spec::AnotherSharedExamplesSpec;
use Test::Spec;
use FindBin qw($Bin);
BEGIN { require "$Bin/test_helper.pl" };

spec_helper 'shared_examples_spec.pl';

describe "A context in a second spec importing an example group defined in another package" => sub {
  it_should_behave_like "example group";
#   it "can take at least one example";
#   it "can take more than one example";
#   describe "with an inner block" =>
#     it "nests properly";
#   it "can be reopened";
};

runtests unless caller;
