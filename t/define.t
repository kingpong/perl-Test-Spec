#!/usr/bin/env perl
#
# define.t
#
# Test cases for Test::Spec definitions
#
########################################################################
#

package Testcase::Spec::Define;
use strict;
use warnings;
use Test::Deep;
use Test::More tests => 18;

# builds a hash of "parent name" => { "child name" => ... }
sub build_context_tree {
  my $node = shift;
  my $tree = shift || {};
  for my $ctx ($node->contexts) {
    build_context_tree($ctx, $tree->{$ctx->name} = {});
  }
  return $tree;
}

{
  package Stub;
  sub new { bless do { \my $stub }, shift() }
  sub AUTOLOAD { shift }
}

my ($outer,$inner) = (0,0);
my ($before_all,$before_each) = (0,0);
my ($after_all,$after_each) = (0,0);
my ($ctx_in_desc, $ctx_in_before, $ctx_in_after);

my $enter_leave_state = undef;
my ($on_enter,$on_leave) = (0,0);

{
  package A;
  use Test::Spec;  # imports
  use base qw(Test::Spec);

  describe "Outer 1" => sub {
    $outer++;

    $ctx_in_desc = A->current_context;

    before all => sub {
      $before_all++;
      $ctx_in_before = A->current_context;
    };
    before each => sub {
      $before_each++;
    };

    it "runs outer test 1" => sub { ok(1, "ran outer test 1") };

    describe "Inner 1" => sub {
      $inner++;
      A->current_context->on_enter(sub {
        $enter_leave_state = 'ENTER';
        $on_enter++;
      });
      A->current_context->on_leave(sub {
        $enter_leave_state = 'LEAVE' if $enter_leave_state eq 'ENTER';
        $on_leave++;
      });

      it "runs inner test 1" => sub { ok(1) };
    };

    after each => sub {
      $after_each++;
      $ctx_in_after = A->current_context;
    };

    after all => sub {
      $after_all++;
    };
  };

  describe "Outer 1" => sub {
    $outer++;
    describe "Inner 1" => sub {
      $inner++;
    };
    describe "Inner 2" => sub {
    };
  };

  # tests
  describe "Outer 2" => sub {
  };
}

is( $outer, 2, "both outer blocks ran");
is( $inner, 2, "both inner blocks ran");

my $tree = build_context_tree('A');
is_deeply( $tree, {
  "Outer 1" => { "Inner 1" => {}, "Inner 2" => {} },
  "Outer 2" => {},
}, "contexts shallow-merged");

is( $before_all,  0, "before-all not run during definition" );
is( $before_each, 0, "before-all not run during definition" );
is( $after_each,  0, "after-each not run during definition" );
is( $after_all,   0, "after-all not run during definition" );
ok( $on_enter > 0, "enter block called");
is( $on_enter, $on_leave, "entered and left symmetrically" );

is( A->phase, Test::Spec::DEFINITION_PHASE, "definition phase" );

{
  no warnings 'once';
  my $stub = Stub->new;
  local *A::builder          = sub { $stub };
  local *Test::More::builder = sub { $stub };
  A->runtests;
}

is( A->phase, Test::Spec::EXECUTION_PHASE, "execution phase" );

is( $ctx_in_desc, $ctx_in_before,
  "describe() and before() contexts are the same (for hooks, esp. mocks)");
is( $ctx_in_desc, $ctx_in_after,
  "describe() and after() contexts are the same (for hooks, esp. mocks)");

is( $outer,       2, "describe blocks did not re-run");
is( $before_all,  1, "before-all ran once before all tests" );
is( $before_each, 2, "before-each ran before each test");
is( $after_each,  2, "after-each ran after each test");

TODO: {
  local $TODO = "after-all untestable without changes to Spec.pm";
  is($after_all,  1, "after-all ran once after all tests" );
}
