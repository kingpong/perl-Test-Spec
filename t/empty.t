#!/usr/bin/env perl
#
# empty.t
#
# Test behavior of empty specs
#
########################################################################
#

package Testcase::Spec::Define;
use strict;
use warnings;
use FindBin qw($Bin);
use Test::More;
use Test::Trap;

BEGIN { require "$Bin/test_helper.pl" };

{
  package A;
  use base qw(Test::Spec);
}

trap {
  stub_builder_in_packages("A", sub {
    A->runtests;
  });
};

warn $trap->die if $trap->die;
is( $trap->leaveby, 'return', 'expected empty test to return, not die' );
like( $trap->stderr, qr/no examples defined/, 'expected warning for empty test' );
like( $trap->stderr, qr/at .*empty\.t line \d+/, 'expected warning from context of caller (issue #5)');

done_testing();
