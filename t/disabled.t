#!/usr/bin/env perl
#
# disabled.t
#
# Test cases for disabled specs (xit, xdescribe, xthey).
# Executes disabled_spec.pl and validates its TAP output.
#
########################################################################
#
use strict;
use warnings;
use FindBin qw($Bin);
BEGIN { require "$Bin/test_helper.pl" };

use Test::More;

my @results = parse_tap("disabled_spec.pl");
my %passing = map { $_->description => $_ } grep { $_->is_test } @results;

sub test_passed {
  my $desc = shift;
  my $testdesc = "- $desc";
  ok($passing{$testdesc}, $desc);
}

sub test_todo {
  my $desc = shift;
  my $testdesc = "- $desc";
  ok($passing{$testdesc} && $passing{$testdesc}->directive eq 'TODO', $desc);
}

test_todo('Test::Spec disabled spec should not execute "it" examples');
test_todo('Test::Spec disabled spec should not execute "they" examples');
test_todo('Test::Spec should not execute disabled "it" example');
test_todo('Test::Spec should not execute disabled "they" example');
test_passed('Test::Spec should execute enabled "it" example');
test_passed('Test::Spec should execute enabled "they" example');

done_testing();

