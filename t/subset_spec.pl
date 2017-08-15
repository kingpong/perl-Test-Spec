#!/usr/bin/env perl
#
# subset_spec.pl
#
# Helper for testing arguments to runtests(@patterns).
#
########################################################################
#

use Test::Spec;
use FindBin qw($Bin);
BEGIN { require "$Bin/test_helper.pl" };

describe "Test" => sub {
  it "One" => sub { pass };
  it "Two" => sub { pass };
  it "Three" => sub { pass };
};

runtests(@ARGV) unless caller;
