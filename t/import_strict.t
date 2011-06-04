#!/usr/bin/env perl
#
# import_strict.t
#
########################################################################

package Testcase::Spec::ImportStrict;
use Test::Spec;
use FindBin qw($Bin);
use warnings;

describe "Test::Spec" => sub {
  describe "test file that violates strict" => sub {
    my $tap = `$Bin/strict_violating_spec.pl 2>&1`;

    it "does not compile" => sub {
      like($tap, qr/aborted due to compilation errors/);
    };

    it "shows reason for failure" => sub {
      like($tap,
          qr/undefined_variable_violates_strict_mode_and_test_should_not_compile/);
    }
  }
};

runtests unless caller;
