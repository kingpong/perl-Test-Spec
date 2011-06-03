#!/usr/bin/env perl
#
# show_exceptions.t
#
########################################################################
#
# override Test::Harness's insistence on using "perl -w"
#BEGIN { $^W = 0 }

package Testcase::Spec::ShowExceptions;
use Test::Spec;
use FindBin qw($Bin);
use strict;
use warnings;

describe "Test::Spec" => sub {
  my $tap;
  before all => sub {
    my @incflags = map { "-I$_" } @INC;
    open(my $SPEC, '-|') || exec($^X, @incflags, "$Bin/dying_spec.pl");
    $tap = do { local $/; <$SPEC> };
    close($SPEC);
  };
  it "should display the error message for uncaught exceptions" => sub {
    my @patterns = (
      qr/^#   Failed test 'Test::Spec should trap die message' by dying:\n/m,
      qr/^#     this should be displayed\n/m,
      qr/^#     at .+? line \d+\.\n/m,
    );
    local $" = "";
    like($tap, qr/@patterns/);
  };
  it "should continue running tests after an exception is encountered" => sub {
    like($tap, qr/^ok \d+ - Test::Spec should continue testing/m);
  };
};

runtests unless caller;
