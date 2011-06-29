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

  it "should explain why a dying test failed" => sub {
    like($tap, qr/^#   Failed test 'Test::Spec should trap die message' by dying:\s*$/m);
  };
  it "should echo the exception message" => sub {
    like($tap, qr/^#     this should be displayed\s*$/m);
  };
  it "should report the context at which the error occurred" => sub {
    like($tap, qr/^#     at .+? line \d+\.\s*$/m);
  };
  it "should continue running tests after an exception is encountered" => sub {
    like($tap, qr/^ok \d+ - Test::Spec should continue testing/m);
  };
};

runtests unless caller;
