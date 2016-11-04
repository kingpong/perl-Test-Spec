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

  describe "when no specific examples are requested" => sub {
    my $tap;
    before all => sub {
      $tap = capture_tap("subset_spec.pl");
    };
    it "should run all the examples" => sub {
      like $tap, qr/^ok \d+ - Test One.*ok \d+ - Test Two/ms;
    };
  };

  describe "when specific examples are requested explicitly" => sub {
    my $tap;
    before all => sub {
      # case insensitivity is baked in
      $tap = capture_tap("subset_spec.pl", "oNe");
    };
    it "should run the requested examples" => sub {
      like $tap, qr/^ok \d+ - Test One/m;
    };
    it "should run ONLY the requested examples" => sub {
      unlike $tap, qr/^ok \d+ - Test Two/;
    };
  };

  describe "when more than one specific example is requested explicitly" => sub {
    my $tap;
    before all => sub {
      # case insensitivity is baked in
      $tap = capture_tap("subset_spec.pl", "oNe", "Two");
    };
    it "should run the requested examples" => sub {
      like $tap, qr/^ok \d+ - Test One.*ok \d+ - Test Two/ms;
    };
    it "should run ONLY the requested examples" => sub {
      unlike $tap, qr/^ok \d+ - Test Three/;
    };
  };

  describe "when specific examples are requested via SPEC environment var" => sub {
    my $tap;
    before all => sub {
      # case insensitivity is baked in
      local $ENV{SPEC} = "oNe";
      $tap = capture_tap("subset_spec.pl");
    };
    it "should run the requested examples" => sub {
      like $tap, qr/^ok \d+ - Test One/m;
    };
    it "should run ONLY the requested examples" => sub {
      unlike $tap, qr/^ok \d+ - Test Two/;
    };
  };

  describe "when examples are requested via both SPEC and explicit parameter" => sub {
    my $tap;
    before all => sub {
      # case insensitivity is baked in
      local $ENV{SPEC} = "oNe";
      $tap = capture_tap("subset_spec.pl","tWo");
    };
    it "should run the explicit example" => sub {
      like $tap, qr/^ok \d+ - Test Two/m;
    };
    it "should *not* run the SPEC example" => sub {
      unlike $tap, qr/^ok \d+ - Test One/;
    };
  };

};

runtests unless caller;
