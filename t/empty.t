#!/usr/bin/env perl
#
# empty.t
#
# Test behavior of empty specs
#
########################################################################
#
# override Test::Harness's insistence on using "perl -w"
BEGIN { $^W = 0 }

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

done_testing();
