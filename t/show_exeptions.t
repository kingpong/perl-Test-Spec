#!/usr/bin/env perl
#
# show_exceptions.t
#
########################################################################
#

package Testcase::Spec::ShowExceptions;
use Test::Spec;
use FindBin qw($Bin);
BEGIN { require "$Bin/test_helper.pl" };

describe "Test::Spec" => sub {
  my $tap = capture_tap("dying_spec.pl");

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
