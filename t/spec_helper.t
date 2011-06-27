#!/usr/bin/env perl
#
# spec_helper.t
#
# Tests the spec_helper function, which loads helper files relative to
# the current file.
#
########################################################################
#

package Testcase::Spec::SpecHelper;
use Test::Spec;
use base qw(Test::Spec);

our $foo;

describe "spec_helper" => sub {
  before each => sub { $foo = 0 };
  it "should load a Perl file into the calling package" => sub {
    spec_helper "helper_test.pl";
    is($foo, 1);
  };
  it "should load the file even if it has already been loaded" => sub {
    spec_helper "helper_test.pl";
    is($foo, 1);
  };
  it "should treat paths as relative to the spec, not the currently running executable" => sub {
    spec_helper "../t/helper_test.pl";
    is($foo, 1);
  };
  it "should treat absolute paths as absolute" => sub {
    # checks the error message
    eval { spec_helper "/foo/bar/does/not/exist" };
    like($@, qr{'/foo/bar/does/not/exist'});
  };
  it "should raise an error containing the filename if the load fails" => sub {
    eval { spec_helper "doesnotexist.pl" };
    like($@, qr{'doesnotexist.pl'});
  };
};

runtests unless caller;
