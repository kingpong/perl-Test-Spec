#!/usr/bin/env perl
#
# mocks_imports.t
#
# Test the way Test::Spec::Mocks exports symbols.
#
########################################################################
#

package Testcase::Spec::Mocks::Imports;
use Test::Spec;
use base qw(Test::Spec);
use Package::Stash;

no strict 'refs';

describe "Test::Spec::Mocks" => sub {

  # start each test with a clean slate
  before each => sub {
    for my $pkg (qw(UNIVERSAL A)) {
      my $stash = Package::Stash->new($pkg);
      for my $sym (qw(&stubs &stub &expects &mock)) {
        $stash->remove_symbol($sym);
      }
    }
  };

  it "should not export symbols unless asked" => sub {
    {
      package A;
      require Test::Spec::Mocks;
    }
    ok(!defined(&UNIVERSAL::stubs) && !defined(&A::stubs));
  };

  it "should export &stubs into UNIVERSAL" => sub {
    {
      package A;
      eval "use Test::Spec::Mocks";
      die $@ if $@;
    }
    is( \&{"UNIVERSAL::stubs"}, \&{"Test::Spec::Mocks::stubs"} );
  };

  it "should export &stubs into UNIVERSAL even when listed in the import list" => sub {
    {
      package A;
      eval "use Test::Spec::Mocks qw(stubs)";
      die $@ if $@;
    }
    ok( \&{"UNIVERSAL::stubs"} == \&{"Test::Spec::Mocks::stubs"} && !defined(&{"A::stubs"}) );
  };

  it "should export &stub into the current pacakge" => sub {
    {
      package A;
      eval "use Test::Spec::Mocks";
      die $@ if $@;
    }
    is( \&{"A::stub"}, \&{"Test::Spec::Mocks::stub"} );
  };

  it "should export &stub into the current package even when &stubs is in the import list"  => sub {
    {
      package A;
      eval "use Test::Spec::Mocks qw(stub stubs)";
      die $@ if $@;
    }
    ok( \&{"UNIVERSAL::stubs"} == \&{"Test::Spec::Mocks::stubs"}
        && !defined(&{"A::stubs"})
        && !defined(&{"UNIVERSAL::stub"})
        && \&{"A::stub"} == \&{"Test::Spec::Mocks::stub"}
    );
  };

};

runtests unless caller;
