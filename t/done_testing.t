#!/usr/bin/env perl

#
# done_testing.t
#
########################################################################
#

package Testcase::Spec::DoneTesting;
use Test::Spec;
use FindBin qw($Bin);
BEGIN { require "$Bin/test_helper.pl" };

describe "Test::Spec" => sub {

  describe "when runtests() is called multiple times" => sub {
    my $tap;
    before all => sub {
      $tap = capture_tap("runtests/multiple_spec.pl");
    };
    it "should call done_testing()" => sub {
      like $tap, qr/^ok \d+ - Test One.*ok \d+ - Test Two/ms;
    };
  };

  describe "when the spec dies outside of a test" => sub {
    my $tap;
    before all => sub {
      $tap = capture_tap("runtests/die_outside_spec.pl");
    };
    it "should not call done_testing()" => sub {
      like $tap, qr/^# Tests were run but no plan was declared/ms;
    };
  };
};

runtests unless caller;
