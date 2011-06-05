#!/usr/bin/env perl

package Testcase::Spec::ImportWarnings;
use Test::Spec;
use FindBin qw($Bin);
BEGIN { require "$Bin/test_helper.pl" };

describe "Test::Spec" => sub {
  describe "test file that contains code that triggers Perl warnings" => sub {
    my $tap = capture_tap("perl_warning_spec.pl");

    it "shows reason for the warning" => sub {
      like($tap,
          qr/Odd number of elements/);
    }
  }
};

runtests unless caller;
