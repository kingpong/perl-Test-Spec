#!/usr/bin/env perl
#
# shared_examples.t
#
# Test cases for Test::Spec shared example definition and inclusion.
# Executes shared_examples_spec.pl and validates its TAP output.
#
########################################################################
#
use strict;
use warnings;
use FindBin qw($Bin);
BEGIN { require "$Bin/test_helper.pl" };

use Test::More;
use TAP::Parser;

my @results = parse_tap("shared_examples_spec.pl");
my %passing = map { $_->description => 1 } grep { $_->is_test } @results;

sub test_passed {
  my $desc = shift;
  my $testdesc = "- $desc";
  ok(exists $passing{$testdesc}, $desc);
}

test_passed("A context importing an example group can take at least one example");
test_passed("A context importing an example group can take more than one example");
test_passed("A context importing an example group with an inner block nests properly");
test_passed("A context importing an example group can have custom behavior");
test_passed("A context importing an example group can be reopened");
test_passed("A context importing an example group executes");
test_passed("Another context importing an example group can take at least one example");
test_passed("Another context importing an example group can take more than one example");
test_passed("Another context importing an example group with an inner block nests properly");
test_passed("Another context importing an example group can have custom behavior, too");
test_passed("Another context importing an example group can be reopened");
test_passed("Another context can have behavior that doesn't interfere with example groups in sub-contexts");
test_passed("Another context importing an example group accumulates examples in the same way that describe() does");

@results = parse_tap("another_shared_examples_spec.pl");
%passing = map { $_->description => 1 } grep { $_->is_test } @results;

test_passed("A context in a second spec importing an example group defined in another package can take at least one example");
test_passed("A context in a second spec importing an example group defined in another package can take more than one example");
test_passed("A context in a second spec importing an example group defined in another package with an inner block nests properly");
test_passed("A context in a second spec importing an example group defined in another package can be reopened");

done_testing();
