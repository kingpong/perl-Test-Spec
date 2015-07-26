#!/usr/bin/env perl
#
# ordering.pl
#
# Verify that describe blocks are executed in order of definition.
#
########################################################################
#

use Test::Spec;
use FindBin qw($Bin);
BEGIN { require "$Bin/test_helper.pl" };

my $num_contexts = 10;

my $next_expected = 1;
for my $num (1..$num_contexts) {
  describe "Context $num" => sub {
    it "should run in position $num" => sub {
      is $next_expected++, $num;
    };
  }
};

runtests(@ARGV) unless caller;
