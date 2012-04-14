#!/usr/bin/env perl
#
# runtests_subset.t
#
########################################################################
#

package Testcase::Spec::RuntestsSubset;
use Test::Spec;
use FindBin qw($Bin);
BEGIN { require "$Bin/test_helper.pl" };

describe "Test::Spec" => sub {

  describe "when no specific tests are requested" => sub {
    my $tap;
    before all => sub {
      $tap = capture_tap("subset_spec.pl");
    };
    it "should run all the tests" => sub {
      like $tap, qr/^ok \d+ - Test One.*ok \d+ - Test Two/ms;
    };
  };

  describe "when specific tests are requested explicitly" => sub {
    my $tap;
    before all => sub {
      # case insensitivity is baked in
      $tap = capture_tap("subset_spec.pl", "oNe");
    };
    it "should run the requested tests" => sub {
      like $tap, qr/^ok \d+ - Test One/;
    };
    it "should run ONLY the requested tests" => sub {
      unlike $tap, qr/^ok \d+ - Test Two/;
    };
  };

  describe "when specific tests are requested via SPEC environment var" => sub {
    my $tap;
    before all => sub {
      # case insensitivity is baked in
      local $ENV{SPEC} = "oNe";
      $tap = capture_tap("subset_spec.pl");
    };
    it "should run the requested tests" => sub {
      like $tap, qr/^ok \d+ - Test One/;
    };
    it "should run ONLY the requested tests" => sub {
      unlike $tap, qr/^ok \d+ - Test Two/;
    };
  };

};

runtests unless caller;
