#!/usr/bin/env perl
#
# disabled.t
#
# Disabled specs.
#
########################################################################
#

package Testcase::Spec::Disabled;
use Test::Spec;
use FindBin qw($Bin);
BEGIN { require "$Bin/test_helper.pl" };

describe 'Test::Spec' => sub {
  xdescribe 'disabled spec' => sub {
    it 'should not execute "it" examples' => sub {
      fail;
    };
    they 'should not execute "they" examples' => sub {
      fail;
    };
  };

  xit 'should not execute disabled "it" example' => sub {
    fail;
  };

  xthey 'should not execute disabled "they" example' => sub {
    fail;
  };

  it 'should execute enabled "it" example' => sub {
    pass;
  };
  they 'should execute enabled "they" example' => sub {
    pass;
  };
};

runtests unless caller;
