#!/usr/bin/env perl
#
# strict_violating_spec.pl
#
# Expected to fail to compile because Test::Spec imports strict into test file.
#
########################################################################

use Test::Spec;

$undefined_variable_violates_strict_mode_and_test_should_not_compile;

runtests unless caller;
