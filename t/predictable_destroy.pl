#!/usr/bin/env perl
#
# predictable_destroy.pl
#
# Objects should be destroyed in a predictable order during the RUN phase
# Expected to print out "DESTROYED IN RUN PHASE"
#
########################################################################
#

package Testcase::Spec::PredictableDestroy;
use Test::Spec;
use Devel::GlobalPhase qw( global_phase );
{
    package Foo;
    sub new { bless {}, $_[0] }
    sub DESTROY { warn("$_[0] DESTROYED IN ". global_phase) }
};

describe "Test::Spec::Mocks" => sub {
  my $x = Foo->new;
  it "destroys objects in the run phase" => sub {
      ok $x;
  };
};

runtests() unless caller;
