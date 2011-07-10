#!/usr/bin/env perl
#
# stash.t
#
# Test cases for context stash.
#
########################################################################
#
package Testcase::Spec::Stash;
use strict;
use warnings;
use Test::Spec;

describe "An example group" => sub {

  share my %stash;

  $stash{outside} = "outside";
  $stash{inside}  = "outside";  # expected to be overridden

  before all => sub {
    $stash{inside} .= 'inside';  # overrides earlier
  };
  before each => sub {
    $stash{each1} = 'each1';
  };
  before each => sub {
    $stash{each2} = 'each2';
  };

  my %expected = (
    outside => 'outside',
    inside => 'outsideinside',
    each1 => 'each1',
    each2 => 'each2',
  );

  it "should set up the stash properly" => sub {
    is_deeply({ %stash }, \%expected);
  };

  describe "within an example group" => sub {
    it "should get the same stash as its parents" => sub {
      is_deeply({ %stash }, { %expected, each3 => 'each3' });
    };
    before each => sub {
      $stash{each3} = 'each3';
    };

    share my %second;
    it "should have the same data in every shared hash" => sub {
      $second{key} = 'value';
      is_deeply({ %second }, { %stash });
    };
  };

};

runtests unless caller;

