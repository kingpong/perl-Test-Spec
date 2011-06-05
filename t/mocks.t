#!/usr/bin/env perl
#
# mocks.t
#
# Object mocking and stubs.
#
########################################################################
#

package Testcase::Spec::Mocks;
use Test::Spec;
use base qw(Test::Spec);

use List::Util ();

# Just a dummy class hierarchy for our testing
{
  package TestOO;
  sub new {
    bless {}, shift;
  }
  sub desc {
    my $self = shift;
    "bottom";
  }
}
{
  package TestORM;
  our @ISA = qw(TestOO);
  sub create { 'ORIGINAL' }
  sub retrieve { 'ORIGINAL' }
  sub desc {
    shift->SUPER::desc . " middle";
  }
}
{
  package TestProduct;
  our @ISA = qw(TestORM);
  sub prices { 'ORIGINAL' }
  sub desc {
    # normally "bottom middle top"
    shift->SUPER::desc . " top";
  }
}

sub contains_ok {
  my ($array,$matcher) = @_;
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  my $ok;
  if (ref $matcher eq 'Regexp') {
    ok( $ok = List::Util::first { $_ =~ $matcher } @$array );
  }
  else {
    ok( $ok = List::Util::first { $_ eq $matcher } );
  }
  if (not $ok) {
    # ganked from Test::Builder::_regex_ok
    my $candidates = join("\n" . (" " x 18), map { "'$_'" } @$array);
    my $match = "don't match";
    Test::More->builder->diag(sprintf <<'DIAGNOSTIC', $candidates, "don't match", $matcher);
                  %s
    %13s '%s'
DIAGNOSTIC
  }
}

describe 'Test::Mocks' => sub {
  # <enter context "The mocking system">

  describe "->stubs()" => sub {

    # replace TestProduct->create for this scope (which is actually TestORM->create)
    my $class;
    my $test_product = TestProduct->new;
    TestProduct->stubs('create' => sub {
      $class = shift;
      return $test_product;
    });

#    after each => sub {
#      # <enter context anonymous>
#      # TODO: WHAT SHOULD HAPPEN HERE?
#      # <leave context>
#    };
#
#    after all => sub {
#      # <enter context anonymous>
#      # TODO: WHAT SHOULD HAPPEN HERE?
#      # <leave context>
#    };

    it 'stubs a class method' => sub {
      my $product = TestProduct->create(price => 1000);
      is($product, $test_product);
    };

    it 'calls the stubbed method with the correct class invocant' => sub {
      TestProduct->create(price => 1000);
      # stub should have set $class
      is($class, 'TestProduct');
    };

    describe "with a before:all block" => sub {
      my $i = 0;
      before all => sub {
        $i++;
        TestProduct->stubs('retrieve' => sub { $i });
      };
      it 'stubs methods in before:all blocks' => sub {
        is(TestProduct->retrieve, 1);
      };
      it 'stubs only once' => sub {
        is(TestProduct->retrieve, 1);
      };
    };
    
    describe "outside and after the before:all block" => sub {
      it "restored the original method" => sub {
        is(TestProduct->retrieve, 'ORIGINAL');
      };
    };

    describe "with a before:each block" => sub {
      my $i = 0;
      my $tests_run;  # in case only specific tests are run
      before each => sub {
        $i++;
        TestProduct->stubs('retrieve' => sub { $i });
      };

      it "stubs once per test" => sub {
        is(TestProduct->retrieve, ++$tests_run);
      };

      it "continues to stub once per test" => sub {
        is(TestProduct->retrieve, ++$tests_run);
      };

    };
    
    describe "outside and after the before:each block" => sub {
      it "restored the original method" => sub {
        is(TestProduct->retrieve, 'ORIGINAL');
      };
    };

    it 'stubs an instance method on all instances of a class' => sub {
      TestProduct->stubs('name')->returns('stubbed_name');
      my $product = TestProduct->new;
      is($product->name, 'stubbed_name');
      # TestProduct->name is un-stubbed automatically
    };

    it 'calls stubbed instance methods with the correct instance invocant' => sub {
      my $invocant;
      TestProduct->stubs(name => sub { $invocant = shift });
      my $product = TestProduct->new;
      $product->name;
      is($invocant, $product);
    };

    it 'stubs instance methods' => sub {
      my @prices = (1000, 2000);
      my $product = TestProduct->new;
      $product->stubs('prices')->returns(\@prices);
      is_deeply( $product->prices, \@prices );
    };

    my $shared_product;
    it 'stubs only the instances requested' => sub {
      my $before_unstubbed = TestProduct->new;

      my @prices = (1000, 2000);
      $shared_product = TestProduct->new;
      $shared_product->stubs('prices')->returns(\@prices);

      my $after_unstubbed = TestProduct->new;
      is_deeply( [$before_unstubbed->prices, $after_unstubbed->prices],
                ['ORIGINAL','ORIGINAL'] );
    };

    it 'restores stubbed instance methods' => sub {
      is_deeply($shared_product->prices, 'ORIGINAL');
    };

    # "necessarily," because you have to specify the package in your code
    it 'does not necessarily break SUPER::' => sub {
      TestORM->stubs('desc' => sub {
        package TestORM;
        shift->SUPER::desc . " STUBBED";
      });
      is(TestProduct->new->desc, 'bottom STUBBED top');
    };

    it 'does not break inheritance chains after restoring a method' => sub {
      # usefulness depends on previous test having been run first
      is(TestProduct->new->desc, 'bottom middle top');
    };
  };

  describe "::stub()" => sub {

    it 'creates anonymous stubs' => sub {
      my $stub = stub(stubbed_method => 'result');
      is( $stub->stubbed_method, 'result' );
    };

  };

  describe "->expects()" => sub {
    it 'mocks a class method' => sub {
      TestProduct->expects('retrieve')->returns(42);
      is(TestProduct->retrieve(1), 42);
    };

    it 'mocks an instance method' => sub {
      my $product = TestProduct->new;
      $product->expects('save')->returns(42);
      is($product->save, 42);
    };

    it 'expects exactly one call by default' => sub {
      # looking for something like "expected retrieve to be called
      # exactly once, but it was called 0 times"
      my $expectation = TestProduct->expects('retrieve')->returns(42);
      $expectation->cancel;
      contains_ok([$expectation->problems],
                  qr/expected.*exactly once.*0 times/);
    };

    it 'dies if there are any problems' => sub {
      my $expectation = TestProduct->expects('retrieve')->returns(42);
      $expectation->cancel;
      eval { $expectation->verify };
      like($@, qr/expected.*exactly once.*0 times/);
    };

    it 'runs verify after a test block' => sub {
      my $verified = 0;
      my $block_ended = 0;
      Test::Spec::Mocks::Expectation->stubs(verify => sub {
        # ensure it actually happens 
        die "verify called before block ended" unless $block_ended;
        $verified++;
      });
      # yuck, private method. maybe change later.
      Test::Spec->current_context->_in_anonymous_context(sub {
        TestProduct->expects('retrieve')->returns(42);
        $block_ended++;
      });
      ok($verified);
    };


    describe "call count expectation" => sub {

      my $stub = stub();
      my $expectation;
      before each => sub {
        $expectation = $stub->expects('run')->returns(42);
        $expectation->cancel; # don't verify
      };

      describe "'exactly'" => sub {
        before sub { $expectation->exactly(42) };
        it "passes when called exactly N times" => sub {
          for (1..42) { $stub->run }
          is(scalar($expectation->problems), 0);
        };
        it "fails when called less than N times" => sub {
          $stub->run;
          contains_ok([$expectation->problems], qr/expected.*42.*1 time/);
        };
        it "fails when called more than N times" => sub {
          for (1..43) { $stub->run }
          contains_ok([$expectation->problems], qr/expected.*42.*43 times/);
        };
      };

      describe "'never'" => sub {
        before sub { $expectation->never };
        it "passes when called never" => sub {
          is(scalar($expectation->problems), 0);
        };
        it "fails when called" => sub {
          $stub->run;
          ok(scalar($expectation->problems) > 0);
        };
      };

      describe "'once'" => sub {
        before sub { $expectation->once };
        it "passes when called once" => sub {
          $stub->run;
          is(scalar($expectation->problems), 0);
        };
        it "fails when not called" => sub {
          contains_ok([$expectation->problems],
                      qr/expected.*exactly once.*0 times/);
        };
        it "fails when called more than once" => sub {
          $stub->run;
          $stub->run;
          contains_ok([$expectation->problems],
                      qr/expected.*exactly once.*2 times/);
        };
      };

      describe "'at_least'" => sub {
        before sub { $expectation->at_least(3) };
        it "fails when called fewer than N times" => sub {
          $stub->run;
          contains_ok([$expectation->problems], qr/expected.*\bat least 3\b.*\b1 time/);
        };
        it "passes when called N times" => sub {
          for (1..3) { $stub->run }
          is(scalar($expectation->problems), 0);
        };
        it "passes when called more than N times" => sub {
          for (1..4) { $stub->run }
          is(scalar($expectation->problems), 0);
        };
      };

      describe "'at_least_once'" => sub {
        before sub { $expectation->at_least_once };
        it "fails when not called at least once" => sub {
          contains_ok([$expectation->problems],
                      qr/expected.*\bat least 1\b.*\b0 times/);
        };
        it "passes when called once" => sub {
          $stub->run;
          is(scalar($expectation->problems), 0);
        };
        it "passes when called more than once" => sub {
          for (1..3) { $stub->run }
          is(scalar($expectation->problems), 0);
        };
      };

      describe "'at_most'" => sub {
        before sub { $expectation->at_most(2) };
        it "passes when never called" => sub {
          # test specifically for zero, since it's an edge case
          is(scalar($expectation->problems), 0);
        };
        it "passes when called fewer than N times" => sub {
          $stub->run;
          is(scalar($expectation->problems), 0);
        };
        it "passes when called at most N times" => sub {
          for (1..2) { $stub->run }
          is(scalar($expectation->problems), 0);
        };
        it "fails when not called at most N times" => sub {
          for (1..3) { $stub->run }
          contains_ok([$expectation->problems], qr/expected.*\bat most 2\b.*\b3 times/);
        };
      };

      describe "'at_most_once'" => sub {
        before sub { $expectation->at_most_once };
        it "passes when never called" => sub {
          # test specifically for zero, since it's an edge case
          is(scalar($expectation->problems), 0);
        };
        it "passes when called exactly once" => sub {
          $stub->run;
          is(scalar($expectation->problems), 0);
        };
        it "fails when called more than once" => sub {
          for (1..2) { $stub->run }
          contains_ok([$expectation->problems], qr/expected.*\bat most 1\b.*\b2 times/);
        };
      };

      describe "'maybe'" => sub {
        # TODO: add ability to share tests between contexts. these are the
        # same tests for at_most_once, since 'maybe' is an alias for that
        before sub { $expectation->maybe };
        it "passes when never called" => sub {
          # test specifically for zero, since it's an edge case
          is(scalar($expectation->problems), 0);
        };
        it "passes when called exactly once" => sub {
          $stub->run;
          is(scalar($expectation->problems), 0);
        };
        it "fails when called more than once" => sub {
          for (1..2) { $stub->run }
          contains_ok([$expectation->problems], qr/expected.*\bat most 1\b.*\b2 times/);
        };
      };

      describe "'any_number'" => sub {
        before sub { $expectation->any_number };
        it "passes when not called" => sub {
          is(scalar($expectation->problems), 0);
        };
        it "passes when called once" => sub {
          $stub->run;
          is(scalar($expectation->problems), 0);
        };
        it "passes when called more than once" => sub {
          for (1..2) { $stub->run }
          is(scalar($expectation->problems), 0);
        };
      };

    };

  };

  describe "::mock()" => sub {
    it 'allows anonymous mocking' => sub {
      my $mock = mock();
      $mock->expects('expected_method')->returns("result");
      #->with("p1","p2")->returns("result");
      is($mock->expected_method, "result");
    };
  };

  # <leave context "The mocking system">
};

runtests unless caller;
