#!/usr/bin/env perl
#
# perl_warning_spec.pl
#
# Expected to show "Odd number of elements" warning because Test::Spec
# imports warnings into test file.
#
########################################################################

use Test::Spec;

describe "Test::Spec" => sub {
  it "turns on perl warnings in test file" => sub {
    my %hash = ( "with" => "odd", "number" => "of", "elements" );
    pass;
  };
};

runtests unless caller;
