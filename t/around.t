#!/usr/bin/env perl
#
# around.pl
#
# Test cases for arounded specs (around).
#
########################################################################
#

use Test::Spec;
use FindBin qw($Bin);
BEGIN { require "$Bin/test_helper.pl" };

our $local_var = 5;

describe "around method" => sub {
  around {
    local $local_var = 4;
    yield;
  };
  it "should have localized var" => sub { is $local_var, 4 };

  describe "inner" => sub {
    around( sub {
      local $local_var = 15;
      yield;
    });

    it "should have localized var" => sub { is $local_var, 15 };
    it "should pass an example instance" => sub { isa_ok shift, "Test::Spec::Example" };
  };

  describe "another inner" => sub {
    around {
      local $local_var = 7;
      yield;
    };

    it "should have localized var" => sub { is $local_var, 7 };
    it "should pass an example instance" => sub { isa_ok shift, "Test::Spec::Example" };
  };
};

describe "yield method" => sub {
  it "should be died without any around" => sub {
    eval { yield };
    like $@, qr/yield/;
  };
};

runtests(@ARGV) unless caller;
