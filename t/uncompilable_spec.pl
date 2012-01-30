#!/usr/bin/env perl
#
# uncompilable_spec.pl
#
# Expected to fail and report Test::Spec usage error from the correct stack
# frame (i.e. "at uncompilable_spec.pl line 13").
#
########################################################################
#

use Test::Spec;

describe "Test::Spec";

runtests unless caller;
