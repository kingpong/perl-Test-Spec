package Test::Spec::Mocks;
use strict;
use warnings;
use Carp ();
use Scalar::Util ();
use Test::Deep::NoTest ();

require Test::Spec;

our @EXPORT_OK = qw(stubs stub expects mock);
our @EXPORT = @EXPORT_OK;

our $Debug = $ENV{TEST_SPEC_MOCKS_DEBUG};

our %To_Universal = map { $_ => 1 } qw(stubs expects);

#
# use Test::Spec::Mocks ();               # nothing (import never called)
# use Test::Spec::Mocks;                  # stubs,expects=>UNIVERSAL, stub,mock=>caller
# use Test::Spec::Mocks qw(stubs stub);   # stubs=>UNIVERSAL, stub=>caller
#
sub import {
  my $srcpkg = shift;
  my $callpkg = caller(0);
  my @syms = @_ ? @_ : @EXPORT;
  SYMBOL: for my $orig_sym (@syms) {
    no strict 'refs';
    # accept but ignore leading '&', we only export subs
    (my $sym = $orig_sym) =~ s{\A\&}{};
    if (not grep { $_ eq $sym } @EXPORT_OK) {
      Carp::croak("\"$orig_sym\" is not exported by the $srcpkg module");
    }
    my $destpkg = $To_Universal{$sym} ? 'UNIVERSAL' : $callpkg;
    my $src  = join("::", $srcpkg, $sym);
    my $dest = join("::", $destpkg, $sym);
    if (defined &$dest) {
      if (*{$dest}{CODE} == *{$src}{CODE}) {
        # already exported, ignore request
        next SYMBOL;
      }
      else {
        Carp::carp("Clobbering existing \"$orig_sym\" in package $destpkg");
      }
    }
    *$dest = \&$src;
  }
}

# Foo->stubs("name")                    # empty return value
# Foo->stubs("name" => "value")         # static return value
# Foo->stubs("name" => sub { "value" }) # dynamic return value

sub stubs {
  _install('Test::Spec::Mocks::Stub', @_);
}

# Foo->expects("name")                  # empty return value
sub expects {
  if (@_ != 2 || ref($_[1])) {
    Carp::croak "usage: ->expects('foo')";
  }
  _install('Test::Spec::Mocks::Expectation', @_);
}

sub _install {
  my $stub_class = shift;
  my ($caller) = ((caller(1))[3] =~ /.*::(.*)/);

  my $target = shift;
  my @methods;

  # normalize name/value pairs to name/subroutine pairs
  if (@_ > 0 && @_ % 2 == 0) {
    # list of name/value pairs
    while (my ($name,$value) = splice(@_,0,2)) {
      push @methods, { name => $name, value => $value };
    }
  }
  elsif (@_ == 1 && ref($_[0]) eq 'HASH') {
    # hash ref of name/value pairs
    my $args = shift;
    while (my ($name,$value) = each %$args) {
      push @methods, { name => $name, value => $value };
    }
  }
  elsif (@_ == 1 && !ref($_[0])) {
    # name only
    push @methods, { name => shift };
  }
  else {
    Carp::croak "usage: $caller('foo'), $caller(foo=>'bar') or $caller({foo=>'bar'})";
  }

  my $context = Test::Spec->current_context
    || Carp::croak "Test::Spec::Mocks only works in conjunction with Test::Spec";
  my $retval; # for chaining. last wins.

  for my $method (@methods) {
    my $stub = $stub_class->new({ target => $target, method => $method->{name} });
    $stub->returns($method->{value}) if exists $method->{value};
    $context->on_enter(sub { $stub->setup });
    $context->on_leave(sub { $stub->teardown });
    $retval = $stub;
  }

  return $retval;
}

# $stub_object = stub();
# $stub_object = stub(method => 'result');
# $stub_object = stub(method => sub { 'result' });
sub stub {
  my $args;
  if (@_ % 2 == 0) {
    $args = { @_ };
  }
  elsif (@_ == 1 && ref($_[0]) eq 'HASH') {
    $args = shift;
  }
  else {
    Carp::croak "usage: stub(%HASH) or stub(\\%HASH)";
  }
  my $blank = _make_mock();
  $blank->stubs($args) if @_;
  return $blank;
}

# $mock_object = mock(); $mock_object->expects(...)
sub mock {
  Carp::croak "usage: mock()" if @_;
  return _make_mock();
}

{
  package Test::Spec::Mocks::MockObject;
  # this page intentionally left blank
}

# keep this out of the MockObject class, so it has a blank slate
sub _make_mock {
  return bless({}, 'Test::Spec::Mocks::MockObject');
}

{
  package Test::Spec::Mocks::Expectation;

  sub new {
    my $class = shift;
    my $self = bless {}, $class;

    # expect to be called exactly one time in the default case
    $self->once;

    if (@_) {
      my $args = shift;
      if (@_ || ref($args) ne 'HASH') {
        Carp::croak "usage: $class->new(\\%args)";
      }
      while (my ($name,$val) = each (%$args)) {
        if ($name eq 'target') {
          $name = '_target';
        }
        elsif ($name eq 'method') {
          $name = '_method';
        }
        $self->$name($val);
      }
    }

    return $self;
  }

  sub _target {
    my $self = shift;
    $self->{__target} = shift if @_;
    return $self->{__target};
  }

  sub _target_class {
    my $self = shift;
    $self->{__target_class} = shift if @_;
    return $self->{__target_class};
  }

  sub _original_code {
    my $self = shift;
    $self->{__original_code} = shift if @_;
    return $self->{__original_code};
  }

  sub _method {
    my $self = shift;
    $self->{__method} = shift if @_;
    return $self->{__method};
  }

  sub _retval {
    my $self = shift;
    $self->{__retval} = shift if @_;
    return $self->{__retval} ||= sub {};
  }

  sub _canceled {
    my $self = shift;
    $self->{__canceled} = shift if @_;
    if (not exists $self->{__canceled}) {
      $self->{__canceled} = 0;
    }
    return $self->{__canceled};
  }

  sub cancel {
    my $self = shift;
    $self->_canceled(1);
    return;
  }

  sub _call_count {
    my $self = shift;
    if (not defined $self->{__call_count}) {
      $self->{__call_count} = 0;
    }
    return $self->{__call_count};
  }

  sub _called {
    my $self = shift;
    my @args = @_;
    $self->_given_args(\@args);
    $self->{__call_count} = $self->_call_count + 1;
  }

  sub _check_call_count {
    my $self = shift;
    $self->{__check_call_count} = shift if @_;
    return $self->{__check_call_count};
  }

  # sets _retval to a subroutine that returns the desired value, which
  # lets us allow users to pass their own subroutines as well as
  # immediate values.
  sub returns {
    my $self = shift;
    if (@_ == 1 && ref($_[0]) eq 'CODE') {
      # no boxing necessary
      $self->_retval(shift);
    }
    elsif (@_ == 1) {
      my $val = shift;
      $self->_retval(sub {
        return $val;
      });
    }
    else {
      my @list = @_;
      $self->_retval(sub {
        return @list;
      });
    }
    return $self;
  }

  #
  # ARGUMENT MATCHING
  #

  sub with {
    my $self = shift;
    return $self->with_eq(@_);
  }

  sub with_eq {
    my $self = shift;
    $self->_eq_args(\@_);
    return $self;
  }

  sub with_deep {
    my $self = shift;
    $self->_deep_args(\@_);
    return $self;
  }

  sub _eq_args {
    my $self = shift;
    $self->{__eq_args} = shift if @_;
    return $self->{__eq_args} ||= undef;
  }

  sub _deep_args {
    my $self = shift;
    $self->{__deep_args} = shift if @_;
    return $self->{__deep_args} ||= undef;
  }

  sub _given_args {
    my $self = shift;
    $self->{__given_args} = shift if @_;
    return $self->{__given_args} ||= undef;
  }

 sub _check_eq_args {
    my $self = shift;
    return unless defined $self->_eq_args;
    return unless $self->_call_count;

    if (!defined $self->_given_args || scalar(@{$self->_eq_args}) != scalar(@{$self->_given_args})) {
        return "Number of arguments don't match expectation";
    }
    my @problems = ();
    for my $i (0..$#{$self->_eq_args}) {
      my $a = $self->_eq_args->[$i];
      my $b = $self->_given_args->[$i];
      unless ($self->_match_arguments($a, $b)) {
        $a = 'undef' unless defined $a;
        $b = 'undef' unless defined $b;
        push @problems, sprintf("Expected argument in position %d to be '%s', but it was '%s'", $i, $a, $b);
      }
    }
    return @problems;
  }

  sub _match_arguments {
    my $self = shift;
    my ($a, $b) = @_;
    return 1 if !defined $a && !defined $b;
    return unless defined $a && defined $b;
    return $a eq $b;
  }

  sub _check_deep_args {
    my $self = shift;
    return unless defined $self->_deep_args;
    return unless $self->_call_count;

    my @got = $self->_given_args;
    my @expected = $self->_deep_args;
    my ($same, $stack) = Test::Deep::cmp_details(\@got, \@expected);
    if ( !$same ) {
      return Test::Deep::deep_diag($stack);
    }
    return; # args are the same
  }

  #
  # EXCEPTIONS
  #

  sub raises {
    my $self = shift;
    my ($message) = @_;
    $self->_exception($message);
    return $self;
  }

  sub _exception {
    my $self = shift;
    $self->{__exception} = shift if @_;
    return $self->{__exception} ||= undef;
  }



  #
  # CALL COUNT CHECKS
  #

  sub _times {
    my ($self,$n,$msg,@params) = @_;
    my $times = $n == 1 ? "time" : "times";
    $msg =~ s{%times}{$times}g;
    return @params ? sprintf($msg,@params) : $msg;
  }

  # ensures that the expected method is called exactly N times
  sub exactly {
    my $self = shift;
    my $n_times = shift;
    if (!defined($n_times) || $n_times !~ /^\A\d+\z/) {
      Carp::croak "Usage: ->exactly(INTEGER)";
    }
    $self->_check_call_count(sub {
      if ($self->_call_count != $n_times) {
        return $self->_times($n_times, "exactly $n_times %times");
      }
    });
    $self;
  }

  # ensures that the expected method is never called
  sub never {
    my $self = shift;
    return $self->exactly(0);
  }

  # ensures that the expected method is called exactly one time
  sub once {
    my $self = shift;
    $self->_check_call_count(sub {
      if ($self->_call_count != 1) {
        return "exactly once";
      }
    });
    $self;
  }

  # ensures that the expected method is called at least N times
  sub at_least {
    my $self = shift;
    my $n_times = shift;
    if (!defined($n_times) || $n_times !~ /^\A\d+\z/) {
      Carp::croak "Usage: ->at_least(INTEGER)";
    }
    $self->_check_call_count(sub {
      if ($self->_call_count < $n_times) {
        return $self->_times($n_times, "at least $n_times %times");
      }
    });
    $self;
  }

  sub at_least_once {
    my $self = shift;
    return $self->at_least(1);
  }

  # ensures that the expected method is called at most N times
  sub at_most {
    my $self = shift;
    my $n_times = shift;
    if (!defined($n_times) || $n_times !~ /^\A\d+\z/) {
      Carp::croak "Usage: ->at_most(INTEGER)";
    }
    $self->_check_call_count(sub {
      if ($self->_call_count > $n_times) {
        return $self->_times($n_times, "at most $n_times %times");
      }
    });
    $self;
  }

  sub at_most_once {
    my $self = shift;
    return $self->at_most(1);
  }

  sub maybe {
    my $self = shift;
    return $self->at_most_once;
  }

  sub any_number {
    my $self = shift;
    $self->_check_call_count(sub {});
    $self;
  }

  # dummy method for syntactic sugar
  sub times {
    my $self = shift;
    $self;
  }

  sub verify {
    my $self = shift;
    my @msgs = $self->problems;
    die join("\n", @msgs) if @msgs;
    return 1;
  }

  sub problems {
    my $self = shift;
    my @prob;
    if (my $message = $self->_check_call_count->()) {
      push @prob, $self->_times(
        $self->_call_count,
        "expected %s to be called %s, but it was called %d %times\n",
        $self->_method, $message, $self->_call_count,
      );
    }
    for my $message ($self->_check_eq_args) {
      push @prob, $message;
    }
    for my $message ($self->_check_deep_args) {
      push @prob, $message;
    }
    return @prob;
  }

  sub setup {
    my $self = shift;
    if ($Debug) {
      print STDERR "Setting up stub for @{[ $self->_target ]}->@{[ $self->_method ]}\n";
    }

    # both these methods set _replaced_qualified_name and
    # _original_code, which we'll use in teardown()
    if (ref $self->_target) {
      $self->_replace_instance_method;
    }
    else {
      $self->_replace_class_method;
    }
  }

  sub teardown {
    my $self = shift;

    if ($Debug) {
      print STDERR "Tearing down stub for @{[ $self->_target ]}->@{[ $self->_method ]}\n";
    }

    no strict 'refs';
    no warnings 'redefine';

    if ($self->_original_code) {
      *{ $self->_replaced_qualified_name } = $self->_original_code;
    }
    else {
      # avoid nuking aliases (including our _retval) by assigning a blank sub first.
      # this technique stolen from ModPerl::Util::unload_package_pp
      *{ $self->_replaced_qualified_name } = sub {};

      # Simply undefining &foo breaks in some cases by leaving some Perl
      # droppings that cause subsequent calls to this function to die with
      # "Not a CODE reference". It sounds harmless until Perl tries to
      # call this method in an inheritance chain. Using Package::Stash solves
      # that problem.  It actually clones the original glob, leaving out the
      # part being deleted.
      require Package::Stash;
      my $stash = Package::Stash->new($self->_target_class);
      $stash->remove_symbol('&' . $self->_method);
    }

    $self->verify unless $self->_canceled;
  }

  sub _replaced_qualified_name {
    my $self = shift;
    return join("::", $self->_target_class, $self->_method);
  }

  sub _replace_instance_method {
    no strict 'refs';
    no warnings qw(uninitialized);

    my $self = shift;
    my $target = $self->_target;
    my $class = ref($target);
    my $dest = join("::", $class, $self->_method);
    my $original_method = $class->can($self->_method);

    # save to be restored later
    $self->_target_class($class);
    $self->_original_code($original_method);

    $self->_install($dest => sub {
      # Use refaddr() to prevent an overridden equality operator from
      # making two objects appear equal when they are only equivalent.
      if (Scalar::Util::refaddr($_[0]) == Scalar::Util::refaddr($target)) {
        # do extreme late binding here, so calls to returns() after the
        # mock has already been installed will take effect.
        my @args = @_;
        shift @args;
        $self->_called(@args);
        die $self->_exception if $self->_exception;
        return $self->_retval->(@_);
      }
      elsif (!$original_method) {
        # method didn't exist before, mimic Perl's behavior
        Carp::croak sprintf("Can't locate object method \"%s\" " .
                            "via package \"%s\"", $self->_method, $class);
      }
      else {
        # run the original as if we were never here.
        # to that end, use goto to prevent the extra stack frame
        goto $original_method;
      }
    });
  }

  sub _replace_class_method {
    no strict 'refs';

    my $self = shift;
    my $dest = join("::", $self->_target, $self->_method);

    $self->_target_class($self->_target);
    $self->_original_code(defined(&$dest) ? \&$dest : undef);

    $self->_install($dest => sub {
      # do extreme late binding here, so calls to returns() after the
      # mock has already been installed will take effect.
      my @args = @_;
      shift @args;
      $self->_called(@args);
      die $self->_exception if $self->_exception;
      $self->_retval->(@_);
    });
  }

  sub _install {
    my ($self,$dest,$code) = @_;
    if ($self->_original_code) {
      # avoid "Prototype mismatch"
      # this code borrowed/enhanced from Moose::Exporter
      if (defined(my $proto = prototype $self->_original_code)) {
        # XXX - Perl's prototype sucks. Use & to make set_prototype
        # ignore the fact that we're passing "private variables"
        &Scalar::Util::set_prototype($code, $proto);
      }
    }
    no strict 'refs';
    no warnings 'redefine';
    *$dest = $code;
  }

}

{
  package Test::Spec::Mocks::Stub;
  use base qw(Test::Spec::Mocks::Expectation);

  # A stub is a special case of expectation that doesn't actually
  # expect anything.

  sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->at_least(0);
    return $self;
  }

}

1;

=head1 NAME

Test::Spec::Mocks - Object Simulation Plugin for Test::Spec

=head1 SYNOPSIS

  use Test::Spec;
  use base qw(Test::Spec);

  use My::RSS::Tool;    # this is what we're testing
  use LWP::UserAgent;

  describe "RSS tool" => sub {
    it "should fetch and parse an RSS feed" => sub {
      my $xml = load_rss_fixture();
      LWP::Simple->expects('get')->returns($xml);

      # calls LWP::Simple::get, but returns our $xml instead
      my @stories = My::RSS::Tool->run;

      is_deeply(\@stories, load_stories_fixture());
    };
  };

=head1 DESCRIPTION

Test::Spec::Mocks is a plugin for Test::Spec that provides mocking and
stubbing of objects, individual methods and plain subroutines on both
object instances and classes. This module is inspired by and heavily
borrows from Mocha, a library for the Ruby programming language. Mocha
itself is inspired by JMock.

Mock objects provide a way to simulate the behavior of real objects, while
providing consistent, repeatable results. This is very useful when you need
to test a function whose results are dependent upon an external factor that
is normally uncontrollable (like the time of day). Mocks also allow you to
test your code in isolation, a tenet of unit testing.

There are many other reasons why mock objects might come in handy. See the
L<Mock objects|http://en.wikipedia.org/wiki/Mock_object> article at Wikipedia
for lots more examples and more in-depth coverage of the philosophy behind
object mocking.

=head2 Ecosystem

Test::Spec::Mocks is currently only usable from within tests built with
the Test::Spec BDD framework. 

=head2 Terminology

Familiarize yourself with these terms:

=over 4

=item * Stub object

A stub object is an object created specifically to return canned responses for
a specific set of methods. These are created with the L<stub|/stub()> function.

=item * Mock object

Mock objects are similar to stub objects, but are programmed with both
prepared responses and expectations for how they will be called. If the
expectations are not met, they raise an exception to indicate that the test
failed. Mock objects are created with the L<mock|/mock()> function.

=item * Stubbed method

Stubbed methods temporarily replace existing methods on a class or object
instance. This is useful when you only want to override a subset of an object
or class's behavior. For example, you might want to override the C<do> method
of a DBI handle so it doesn't make changes to your database, but still need
the handle to respond as usual to the C<quote> method.  You'll stub
methods using the L<stubs|/"$thing-E<gt>stubs($method_name)"> method.

=item * Mocked method

If you've been reading up to this point, this will be no surprise.  Mocked
methods are just like stubbed methods, but they come with expectations that
will raise an exception if not met. For example, you can mock a C<save> method
on an object to ensure it is called by the code you are testing, while
preventing the data from actually being committed to disk in your test. Use
the L<expects|/"$thing-E<gt>expects($method)"> method to create mock methods.

=item * "stub", "mock"

Depending on context, these can refer to stubbed objects and methods, or
mocked objects and methods, respectively.

=back

=head2 Using stub objects (anonymous stubs)

Sometimes the code you're testing requires that you pass it an object that
conforms to a specific interface. For example, you are testing a console
prompting library, but you don't want to require a real person to stand by,
waiting to type answers into the console. The library requires an object
that returns a string when the C<read_line> method is called.

You could create a class specifically for returning test console input. But
why do that? You can create a stub object in one line:

  describe "An Asker" => sub {
    my $asker = Asker->new;

    it "returns true when a yes_or_no question is answered 'yes'" => sub {
      my $console_stub = stub(read_line => "yes");
      # $console_stub->read_line returns "yes"
      ok( $asker->yes_or_no($console_stub, "Am I awesome?") );
    };

    it "returns false when a yes_or_no question is answered 'no'" => sub {
      my $console_stub = stub(read_line => "no");
      ok( ! $asker->yes_or_no($console_stub, "Am I second best?") );
    };
  };

Stubs can also take subroutine references.  This is useful when the behavior
you need to mimic is a little more complex.

  it "keeps asking until it gets an answer" => sub {
    my @answers = (undef, "yes");
    my $console_stub = stub(read_line => sub { shift @answers });
    # when console_stub is called the first time, it returns undef
    # the second time returns "yes"
    ok( $asker->yes_or_no($console_stub, "Do I smell nice?") );
  };

=head2 Using mock objects

If you want to take your tests one step further, you can use mock objects
instead of stub objects. Mocks ensure the methods you expect to be called
actually are called. If they aren't, the mock will raise an exception which
causes your test to fail.

In this example, we are testing that C<read_line> is called once and only
once (the default for mocks).

  it "returns true when a yes_or_no question is answered 'yes'" => sub {
    my $console_mock = mock();
    $console_mock->expects('read_line')
                 ->returns("yes");
    # $console_mock->read_line returns "yes"
    ok( $asker->yes_or_no($console_mock, "Am I awesome?") );
  };

If Asker's C<yes_or_no> method doesn't call C<read_line> on our mock exactly
one time, the test would fail with a message like:

  expected read_line to be called exactly 1 time, but it was called 0 times

You can specify how many times your mock should be called with "exactly":

  it "keeps asking until it gets an answer" => sub {
    my @answers = (undef, "yes");
    my $console_mock = mock();
    $console_mock->expects('read_line')
                 ->returns(sub { shift @answers })
                 ->exactly(2);
    # when console_mock is called the first time, it returns undef
    # the second time returns "yes"
    ok( $asker->yes_or_no($console_mock, "Do I smell nice?") );
  };

If you want something more flexible than "exactly", you can choose from
"at_least", "at_most", "any_number" and others. See L</EXPECTATION ADJUSTMENT METHODS>.


=head2 Stubbing methods

Sometimes you want to override just a small subset of an object's behavior.

  describe "The old audit system" => sub {
    my $dbh;
    before sub { $dbh = SomeExternalClass->get_dbh };

    it "executes the expected sql" => sub {
      my $sql;
      $dbh->stubs(do => sub { $sql = shift; return 1 });

      # $dbh->do("foo") now sets $sql to "foo"
      # $dbh->quote still does what it normally would

      audit_event($dbh, "server crash, oh noes!!");

      like( $sql, qr/insert into audit_event.*'server crash, oh noes!!!'/ );
    };
  };

You can also stub class methods:

  # 1977-05-26T14:11:55
  my $event_datetime = DateTime->new(from_epoch => 0xdeafcab);

  it "should tag each audit event with the current time" => sub {
    DateTime->stubs('now' => sub { $event_datetime });
    is( audit_timestamp(), '19770526.141155' );
  };

=head2 Mocking methods

Mocked methods are to stubbed methods as mock objects are to stub objects.

  it "executes the expected sql" => sub {
    $dbh->expects('do')->returns(sub { $sql = shift; return 1 });

    # $dbh->do("foo") now sets $sql to "foo"
    # $dbh->quote still does what it normally would

    audit_event($dbh, "server crash, oh noes!!");
    like( $sql, qr/insert into audit_event.*'server crash, oh noes!!!'/ );

    # if audit_event doesn't call $dbh->do exactly once, KABOOM!
  };

=head1 CONSTRUCTORS

=over 4

=item stub()

=item stub($method_name => $result, ...)

=item stub($method_name => sub { $result }, ...)

=item stub({ $method_name => $result, ... })

Returns a new anonymous stub object. Takes a list of
C<$method_name>/C<$result> pairs or a reference to a hash containing the same.
Each C<$method_name> listed is stubbed to return the associated value
(C<$result>); or if the value is a subroutine reference, it is stubbed
in-place (the subroutine becomes the method).

Examples:

  # A blank object with no methods.
  # Gives a true response to ref() and blessed().
  my $blank = stub();

  # Static responses to width() and height():
  my $rect = stub(width => 5, height => 5);

  # Dynamic response to area():
  my $radius = 1.0;
  my $circle_stub = stub(area => sub { PI * $radius * $radius });

You can also stub more methods, just like with any other object:

  my $rect = stub(width => 5, height => 5);
  $rect->stubs(area => sub { my $self = shift; $self->width * $self->height });


=item $thing->stubs($method_name)

=item $thing->stubs($method_name => $result)

=item $thing->stubs($method_name => sub { $result })

=item $thing->stubs({ $method_name => $result })

Stubs one or more methods on an existing class or instance, C<$thing>.

If passed only one (non-hash) argument, it is interpreted as a method name.
The return value of the stubbed method will be C<undef>.

Otherwise, the arguments are a list of C<$method_name> and C<$result>
pairs, either as a flat list or as a hash reference. Each method is
installed onto C<$thing>, and returns the specified result. If the result is a
subroutine reference, it will be called for every invocation of the method.


=item mock()

Returns a new blank, anonymous mock object, suitable for mocking methods with
L<expects()|/"$thing-E<gt>expects($method)">.

  my $rect = mock();
  $rect->expects('area')->returns(100);


=item $thing->expects($method)

Installs a mock method named C<$method> onto the class or object C<$thing> and
returns an Test::Spec::Mocks::Expectation object, which you can use to set the
return value with C<returns()> and other expectations. By default, the method
is expected to be called L<at_least_once>.

If the expectation is not met before the enclosing example completes, the
mocked method will raise an exception that looks something like:

  expected foo to be called exactly 1 time, but it was called 0 times

=back

=head1 EXPECTATION ADJUSTMENT METHODS

These are methods of the Test::Spec::Mocks::Expectation class, which you'll
receive by calling C<expects()> on a class or object instance.

=over 4

=item returns( $result )

=item returns( @result )

=item returns( \&callback )

Configures the mocked method to return the specified result when called. If
passed a subroutine reference, the subroutine will be executed when the method
is called, and the result is the return value.

  $rect->expects('height')->returns(5);
  # $rect->height ==> 5

  @points = ( [0,0], [1,0], [1,1], [1,0] );
  $rect->expects('points')->returns(@points);
  # (@p = $rect->points) ==> ( [0,0], [1,0], [1,1], [1,0] )
  # ($p = $rect->points) ==> 4

  @points = ( [0,0], [1,0], [1,1], [1,0] );
  $rect->expects('next_point')->returns(sub { shift @points });
  # $rect->next_point ==> [0,0]
  # $rect->next_point ==> [1,0]
  # ...

=item exactly($N)

Configures the mocked method so that it must be called exactly $N times. 

=item never

Configures the mocked method so that it must never be called.

=item once

Configures the mocked method so that it must be called exactly one time.

=item at_least($N)

Configures the mocked method so that it must be called at least $N times.

=item at_least_once

Configures the mocked method so that it must be called at least 1 time.
This is just syntactic sugar for C<at_least(1)>.

=item at_most($N)

Configures the mocked method so that it must be called no more than $N times.

=item at_most_once

Configures the mocked method so that it must be called either zero or 1
times.

=item maybe

An alias for L</at_most_once>.

=item any_number

Configures the mocked method so that it can be called zero or more times.

=item times

A syntactic sugar no-op:

  $io->expects('print')->exactly(3)->times;

I<This method is alpha and will probably change in a future release.>

=item with(@arguments) / with_eq(@arguments)

Configures the mocked method so that it must be called with arguments as
specified. The arguments will be compared using the "eq" operator, so it works
for most scalar values with no problem. If you want to check objects here,
they must be the exact same instance or you must overload the "eq" operator to
provide the behavior you desire.

=item with_deep(@arguments)

Similar to C<with_eq> except the arguments are compared using L<Test::Deep>: scalars are
compared by value, arrays and hashes must have the same elements and references
must be blessed into the same class.

    $cache->expects('set')
          ->with_deep($customer_id, { name => $customer_name });

Use L<Test::Deep>'s comparison functions for more flexibility:

    use Test::Deep::NoTest ();
    $s3->expects('put')
       ->with_deep('test-bucket', 'my-doc', Test::Deep::ignore());

=item raises($exception)

Configures the mocked method so that it raises C<$exception> when called.

=back

=head1 OTHER EXPECTATION METHODS

=over 4

=item verify

Allows you to verify manually that the expectation was met. If the expectation
has not been met, the method dies with an error message containing specifics
of the failure.  Returns true otherwise.

=item problems

If the expectation has not been met, returns a list of problem description
strings. Otherwise, returns an empty list.

=back

=head1 KNOWN ISSUES

=over 4

=item Memory leaks

Because of the way the mock objects (C<stubs>, C<stub>, C<expects>, and C<mock>)
are integrated into the Test::Spec runtime they will leak memory. It is
not recommended to use the Test::Spec mocks in any long-running program.

Patches welcome.

=back

=head1 SEE ALSO

There are other less sugary mocking systems for Perl, including
L<Test::MockObject> and L<Test::MockObject::Extends>.

This module is a plugin for L<Test::Spec>.  It is inspired by
L<Mocha|http://mocha.rubyforge.org/>.

The Wikipedia article L<Mock object|http://en.wikipedia.org/wiki/Mock_object>
is very informative.

=head1 AUTHOR

Philip Garrett, <philip.garrett@icainformatics.com>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2011 by Informatics Corporation of America.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
