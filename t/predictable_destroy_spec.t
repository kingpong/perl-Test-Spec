#!/usr/bin/env perl
#
# predictable_destroy_spec.t
#
# Ensure we don't keep references around to objects so they
# are destroyed in a predictable order
#
########################################################################
#

package Testcase::Spec::PredictableDestroy;
use Test::Spec;

use FindBin qw($Bin);
BEGIN { require "$Bin/test_helper.pl" };

describe "Test::Spec" => sub {
  my $tap = capture_tap("predictable_destroy.pl");

  it "destroys objects in the run phase" => sub {
      unlike $tap => qr/DESTROYED IN DESTRUCT/;
  };

  it "avoids global destruction" => sub {
      unlike $tap => qr/during global destruction/;
  };
};

runtests unless caller;
