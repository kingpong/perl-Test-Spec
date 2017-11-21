package Test::Spec;
use strict;
use warnings;
use Test::Trap ();        # load as early as possible to override CORE::exit

our $VERSION = '0.54';

use parent 'Exporter';

use Carp ();
use Exporter ();
use File::Spec ();
use Tie::IxHash ();

use constant { DEFINITION_PHASE => 0, EXECUTION_PHASE => 1 };

our $TODO;
our $Debug = $ENV{TEST_SPEC_DEBUG} || 0;

our @EXPORT      = qw(runtests
                      describe xdescribe context xcontext it xit they xthey
                      before after around yield spec_helper
                      *TODO share shared_examples_for it_should_behave_like );
our @EXPORT_OK   = ( @EXPORT, qw(DEFINITION_PHASE EXECUTION_PHASE $Debug) );
our %EXPORT_TAGS = ( all => \@EXPORT_OK,
                     constants => [qw(DEFINITION_PHASE EXECUTION_PHASE)] );
our @CARP_NOT    = ();

our $_Current_Context;
our %_Package_Contexts;
our %_Package_Phase;
our %_Package_Tests;
our %_Shared_Example_Groups;
our $Yield = sub {
  local @CARP_NOT = qw( Test::Spec );
  Carp::croak "yield can be called only by around CODE";
};

# Avoid polluting the Spec namespace by loading these other modules into
# what's essentially a mixin class.  When you write "use Test::Spec",
# you'll get everything from Spec plus everything in ExportProxy. If you
# specify a list, the pool is limited to the stuff in @EXPORT_OK above.
{
  package Test::Spec::ExportProxy;
  use base qw(Exporter);
  BEGIN {
    eval "use Test::Deep 0.103 ()"; # check version and load export list
    Test::Deep->import(grep { $_ ne 'isa' } @Test::Deep::EXPORT);
  }
  use Test::More;
  use Test::Trap;
  use Test::Spec::Mocks;
  our @EXPORT_OK = (
    @Test::More::EXPORT,
    (grep { $_ ne 'isa' } @Test::Deep::EXPORT),
    qw(trap $trap),       # Test::Trap doesn't use Exporter
    @Test::Spec::Mocks::EXPORT,
  );
  our @EXPORT = @EXPORT_OK;
  our %EXPORT_TAGS = (all => \@EXPORT_OK);
}

sub import {
  my $class = shift;
  my $callpkg = caller;

  strict->import;
  warnings->import;

  # specific imports requested
  if (@_) {
    $class->export_to_level(1, $callpkg, @_);
    return;
  }

  eval qq{
    package $callpkg;
    use parent 'Test::Spec';
    # allow Test::Spec usage errors to be reported via Carp
    our \@CARP_NOT = qw($callpkg);
  };
  die $@ if $@;
  Test::Spec::ExportProxy->export_to_level(1, $callpkg);
  $class->export_to_level(1, $callpkg);
}

# PACKAGE->phase
# PACKAGE->phase(NEWPHASE)
sub phase {
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  if (@_) {
    $_Package_Phase{$class} = shift;
  }
  if (exists $_Package_Phase{$class}) {
    return $_Package_Phase{$class};
  }
  else {
    return $_Package_Phase{$class} = DEFINITION_PHASE;
  }
}

# PACKAGE->add_test(SUBNAME)
sub add_test {
  my ($class,$test) = @_;
  my $list = $_Package_Tests{$class} ||= [];
  push @$list, $test;
  return;
}

# @subnames = PACKAGE->tests
sub tests {
  my ($class) = @_;
  my $list = $_Package_Tests{$class} ||= [];
  return @$list;
}

# runtests
# PACKAGE->runtests # @ARGV or $ENV{SPEC}
# PACKAGE->runtests(PATTERNS)
sub runtests {
  my $class = $_[0];
  if (not defined $class) {
    $class = caller;
  }
  elsif (not eval { $class->isa(__PACKAGE__) }) {
    $class = caller;
  }
  else {
    shift;  # valid class, remove from arg stack.
  }
  $class->_materialize_tests;
  $class->phase(EXECUTION_PHASE);

  my @which = @_         ? @_           :
              $ENV{SPEC} ? ($ENV{SPEC}) : ();

  my @tests = $class->_pick_tests(@which);
  return $class->_execute_tests( @tests );
}

sub builder {
  # this is a singleton.
  Test::Builder->new;
}

sub _pick_tests {
  my ($class,@matchers) = @_;
  my @tests = $class->tests;

  my $pattern = join("|", @matchers);
  @tests = grep { $_->name =~ /$pattern/i } @tests;

  return @tests;
}

sub _execute_tests {
  my ($class,@tests) = @_;
  for my $test (@tests) {
    $test->run();
  }

  # Ensure we don't keep any references to user variables so they go out
  # of scope in a predictable fashion.
  %_Package_Tests = %_Package_Contexts = ();

  # XXX: this doesn't play nicely with Test::NoWarnings and friends
  $class->builder->done_testing;
}

# it DESC => CODE
# it CODE
# it DESC
sub it(@) {
  my $package = caller;
  my $code;
  if (@_ && ref($_[-1]) eq 'CODE') {
    $code = pop;
  }
  my $name = shift;
  if (not ($code || $name)) {
    Carp::croak "it() requires at least one of (description,code)";
  }
  $name ||= "behaves as expected (whatever that means)";
  push @{ _autovivify_context($package)->tests }, {
    name => $name,
    code => $code,
    todo => $TODO,
  };
  return;
}

# alias "they" to "it", for describing behavior of multiple items
sub they(@);
BEGIN { *they = \&it }

# describe DESC => CODE
# describe CODE
sub describe(@) {
  my $package = caller;
  my $code = pop;
  if (ref($code) ne 'CODE') {
    Carp::croak "expected subroutine reference as last argument";
  }
  my $name = shift || $package;

  my $container;
  if ($_Current_Context) {
    $container = $_Current_Context->context_lookup;
  }
  else {
    $container = $_Package_Contexts{$package} ||= Test::Spec::_ixhash();
  }

  __PACKAGE__->_accumulate_examples({
    container => $container,
    name => $name,
    class => $package,
    code => $code,
    label => $name,
  });
}

# around CODE
sub around(&) {
  my $package = caller;
  my $code = pop;
  if (ref($code) ne 'CODE') {
    Carp::croak "expected subroutine reference as last argument";
  }
  my $context = _autovivify_context($package);
  push @{ $context->around_blocks }, { code => $code };
}

# yield
sub yield() {
  $Yield->();
}

# make context() an alias for describe()
sub context(@);
BEGIN { *context = \&describe }

# used to easily disable suites/specs during development
sub xit(@) {
  local $TODO = '(disabled)';
  it(@_);
}

sub xthey(@) {
  local $TODO = '(disabled)';
  they(@_);
}

sub xdescribe(@) {
  local $TODO = '(disabled)';
  describe(@_);
}

# make xcontext() an alias for xdescribe()
sub xcontext(@);
BEGIN { *xcontext = \&xdescribe }

# shared_examples_for DESC => CODE
sub shared_examples_for($&) {
  my $package = caller;
  my ($name,$code) = @_;
  if (not defined($name)) {
    Carp::croak "expected example group name as first argument";
  }
  if (ref($code) ne 'CODE') {
    Carp::croak "expected subroutine reference as last argument";
  }

  __PACKAGE__->_accumulate_examples({
    container => \%_Shared_Example_Groups,
    name => $name,
    class => undef,   # shared examples are global
    code => $code,
    label => '',
  });
}

# used by both describe() and shared_examples_for() to build example
# groups in context
sub _accumulate_examples {
  my ($klass,$args) = @_;
  my $container = $args->{container};
  my $name = $args->{name};
  my $class = $args->{class};
  my $code = $args->{code};
  my $label = $args->{label};

  my $context;
  # Don't clobber contexts of the same name, aggregate them.
  if ($container->{$name}) {
    $context = $container->{$name};
  }
  else {
    $container->{$name} = $context = Test::Spec::Context->new;
    $context->name( $label );
    # A context gets either a parent or a class. This is because the
    # class should be inherited from the parent to support classless
    # shared example groups.
    if ($_Current_Context) {
      $context->parent( $_Current_Context );
    }
    else {
      $context->class( $class );
    }
  }

  # evaluate the context function, which will set up lexical variables and
  # define tests and other contexts
  $context->contextualize($code);
}

# it_should_behave_like DESC
sub it_should_behave_like($) {
  my ($name) = @_;
  if (not defined($name)) {
    Carp::croak "expected example_group_name as first argument";
  }
  if (!$_Current_Context) {
    Carp::croak "it_should_behave_like can only be used inside a describe or shared_examples_for context";
  }
  my $context = $_Shared_Example_Groups{$name} ||
    Carp::croak "unrecognized example group \"$name\"";

  # make a copy so we can assign the correct class name (via parent),
  # which is needed for flattening the context into actual test
  # functions later.
  my $shim = $context->clone;
  $shim->parent($_Current_Context);

  # add our shared_examples_for context as if it had been written inline
  # as a describe() block
  $_Current_Context->context_lookup->{"__shared_examples__:$name"} = $shim;
}

# before CODE
# before all => CODE
# before each => CODE
sub before (@) {
  my $package = caller;
  my $code = pop;
  if (ref($code) ne 'CODE') {
    Carp::croak "expected subroutine reference as last argument";
  }
  my $type = shift || 'each';
  if ($type ne 'each' && $type ne 'all') {
    Carp::croak "before type should be one of 'each' or 'all'";
  }
  my $context = _autovivify_context($package);
  push @{ $context->before_blocks }, { type => $type, code => $code };
}

# after CODE
# after all => CODE
# after each => CODE
sub after (@) {
  my $package = caller;
  my $code = pop;
  if (ref($code) ne 'CODE') {
    Carp::croak "expected subroutine reference as last argument";
  }
  my $type = shift || 'each';
  if ($type ne 'each' and $type ne 'all') {
    Carp::croak "after type should be one of 'each' or 'all'";
  }
  my $context = _autovivify_context($package);
  push @{ $context->after_blocks }, { type => $type, code => $code };
}

# spec_helper FILESPEC
sub spec_helper ($) {
  my $filespec = shift;
  my ($callpkg,$callfile) = caller;
  my $load_path;
  if (File::Spec->file_name_is_absolute($filespec)) {
    $load_path = $filespec;
  }
  else {
    my ($callvol,$calldir,undef)  = File::Spec->splitpath($callfile);
    my (undef,$filedir,$filename) = File::Spec->splitpath($filespec);
    my $newdir = File::Spec->catdir($calldir,$filedir);
    $load_path = File::Spec->catpath($callvol,$newdir,$filename);
  }
  my $sub = eval "package $callpkg;\n" . q[sub {
    my ($file,$origpath) = @_;
    open(my $IN, "<", $file)
      || die "could not open spec_helper '$origpath': $!";
    defined(my $content = do { local $/; <$IN> })
      || die "could not read spec_helper '$origpath': $!";
    eval("# line 1 \"$origpath\"\n" . $content);
    die "$@\n" if $@;
  }];
  $sub->($load_path,$filespec);
}

sub share(\%) {
  my $hashref = shift;
  tie %$hashref, 'Test::Spec::SharedHash';
}

sub _materialize_tests {
  my $class = shift;
  my $contexts = $_Package_Contexts{$class};
  if (not $contexts && %$contexts) {
    Carp::carp "no examples defined in spec package $class";
    return;
  }
  for my $context (values %$contexts) {
    $context->_materialize_tests();
  }
}

sub in_context {
  my ($class,$context) = @_;
  if (!$_Current_Context) {
    return '';
  }
  elsif ($context == $_Current_Context) {
    return 1;
  }
  elsif ($context->ancestor_of($_Current_Context)) {
    return 1;
  }
  else {
    return '';
  }
}

# NOT a method, just a subroutine that takes a package name.
sub _autovivify_context {
  my ($package) = @_;
  if ($_Current_Context) {
    return $_Current_Context;
  }
  else {
    my $name = '';  # unnamed context
    return $_Package_Contexts{$package}{$name} ||=
      Test::Spec::Context->new({ name => $name, class => $package, parent => undef });
  }
}

# Public interface.
sub current_context {
  $_Current_Context
}

sub contexts {
  my ($class) = @_;
  my @ctx = values %{ $_Package_Contexts{$class} || {} };
  return wantarray ? @ctx : \@ctx;
}

sub _ixhash {
  tie my %h, 'Tie::IxHash';
  \%h;
}

# load context implementation
require Test::Spec::Context;
require Test::Spec::SharedHash;

1;

=head1 NAME

Test::Spec - Write tests in a declarative specification style

=head1 SYNOPSIS

  use Test::Spec; # automatically turns on strict and warnings

  describe "A date" => sub {

    my $date;

    describe "in a leap year" => sub {

      before each => sub {
        $date = DateTime->new(year => 2000, month => 2, day => 28);
      };

      it "should know that it is in a leap year" => sub {
        ok($date->is_leap_year);
      };

      it "should recognize Feb. 29" => sub {
        is($date->add(days => 1)->day, 29);
      };

    };

    describe "not in a leap year" => sub {
      before each => sub {
        $date = DateTime->new(year => 2001, month => 2, day => 28);
      };

      it "should know that it is NOT in a leap year" => sub {
        ok(!$date->is_leap_year);
      };

      it "should NOT recognize Feb. 29" => sub {
        is($date->add(days => 1)->day, 1);
      };
    };

  };

  runtests unless caller;

  # Generates the following output:
  # ok 1 - A date in a leap year should know that it is in a leap year
  # ok 2 - A date in a leap year should recognize Feb. 29
  # ok 3 - A date not in a leap year should know that it is NOT in a leap year
  # ok 4 - A date not in a leap year should NOT recognize Feb. 29
  # 1..4


=head1 DESCRIPTION

This is a declarative specification-style testing system for behavior-driven
development (BDD) in Perl. The tests (a.k.a. examples) are named with strings
instead of subroutine names, so your fingers will suffer less fatigue from
underscore-itis, with the side benefit that the test reports are more legible.

This module is inspired by and borrows heavily from L<RSpec|http://rspec.info/documentation>, 
a BDD tool for the Ruby programming language.

=head2 EXPORTS

When given B<no list> (i.e. C<use Test::Spec;>), this class will export:

=over 4

=item * Spec definition functions

These are the functions you will use to define behaviors and run your specs:
C<describe>, C<it>, C<they>, C<before>, C<after>, C<runtests>, C<share>,
C<shared_examples_for>, C<it_should_behave_like>, and C<spec_helper>.

=item * The stub/mock functions in L<Test::Spec::Mocks>.

=item * Everything that L<Test::More> normally exports

This includes C<ok>, C<is> and friends. You'll use these to assert
correct behavior.

=item * Everything that L<Test::Deep> normally exports

More assertions including C<cmp_deeply>.

=item * Everything that C<Test::Trap> normally exports

The C<trap()> function, which let you test behaviors that call C<exit()> and
other hard things like that. "A block eval on steroids."

=back

If you specify an import list, only functions directly from C<Test::Spec>
(those documented below) are available.

=head2 FUNCTIONS

=over 4

=item runtests

=item runtests(@patterns)

Runs all the examples whose descriptions match one of the (non case-sensitive)
regular expressions in C<@patterns>. If C<@patterns> is not provided,
runs I<all> examples. The environment variable "SPEC" will be used as a
default pattern if present.

If called as a function (i.e. I<not> a method call with "->"), C<runtests>
will autodetect the package from which it is called and run that
package's examples. A useful idiom is:

  runtests unless caller;

which will run the examples when the file is loaded as a script (for example,
by running it from the command line), but not when it is loaded as a module
(with C<require> or C<use>).

=item describe DESCRIPTION => CODE

=item describe CODE

Defines a specification context under which examples and more
descriptions can be defined.  All examples I<must> come inside a C<describe>
block.

=over 4

=item C<describe> blocks can be nested to DRY up your specs.

For large specifications, C<describe> blocks can save you a lot of duplication:

  describe "A User object" => sub {
    my $user;
    before sub {
      $user = User->new;
    };
    describe "from a web form" => sub {
      before sub {
        $user->init_from_tree({ username => "bbill", ... });
      };
      it "should read its attributes from the form";
      describe "when saving" => sub {
        it "should require a unique username";
        it "should require a password";
      };
    };
  };

The setup work done in each C<before> block cascades from one level
to the next, so you don't have to make a call to some
initialization function manually in each test. It's done
automatically based on context.

=item Using describe blocks improves legibility without requiring more typing.

The name of the context will be included by default in the
success/failure report generated by Test::Builder-based testing methods (e.g.
Test::More's ok() function).  For an example like this:

  describe "An unladen swallow" => sub {
    it "has an airspeed of 11 meters per second" => sub {
      is($swallow->airspeed, "11m/s");
    };
  };

The output generated is:

  ok 1 - An unladen swallow has an airspeed of 11 meters per second

Contrast this to the following test case to generate the same output:

  sub unladen_swallow_airspeed : Test {
    is($swallow->airspeed, "11m/s",
       "An unladen swallow has an airspeed of 11 meters per second");
  }

=back

C<describe> blocks execute in the order in which they are defined. Multiple
C<describe> blocks with the same name are allowed. They do not replace each
other, rather subsequent C<describe>s extend the existing one of the same
name.

=item context

An alias for C<describe()>.

=item xdescribe

Specification contexts may be disabled by calling C<xdescribe> instead of
C<describe()>. All examples inside an C<xdescribe> are reported as
"# TODO (disabled)", which prevents Test::Harness/prove from counting them
as failures.

=item xcontext

An alias for C<xdescribe()>.

=item it SPECIFICATION => CODE

=item it CODE

=item it TODO_SPECIFICATION

Defines an example to be tested.  Despite its awkward name, C<it> allows
a natural (in my opinion) way to describe expected behavior:

  describe "A captive of Buffalo Bill" => sub {
    it "puts the lotion on its skin" => sub {
      ...
    };
    it "puts the lotion in the basket"; # TODO
  };

If a code reference is not passed, the specification is assumed to be
unimplemented and will be reported as "TODO (unimplemented)" in the test
results (see L<Test::Builder/todo_skip>. TODO tests report as skipped,
not failed.

=item they SPECIFICATION => CODE

=item they CODE

=item they TODO_SPECIFICATION

An alias for L</it>.  This is useful for describing behavior for groups of
items, so the verb agrees with the noun:

  describe "Captives of Buffalo Bill" => sub {
    they "put the lotion on their skin" => sub {
      ...
    };
    they "put the lotion in the basket"; # TODO
  };

=item xit/xthey

Examples may be disabled by calling xit()/xthey() instead of it()/they().
These examples are reported as "# TODO (disabled)", which prevents
Test::Harness/prove from counting them as failures.

=item before each => CODE

=item before all => CODE

=item before CODE

Defines code to be run before tests in the current describe block are
run. If "each" is specified, CODE will be re-executed for every test in
the context. If "all" is specified, CODE will only be executed before
the first test.

The default is "each", due to this logic presented in RSpec's documentation:

I<"It is very tempting to use before(:all) and after(:all) for situations
in which it is not appropriate. before(:all) shares some (not all) state
across multiple examples. This means that the examples become bound
together, which is an absolute no-no in testing. You should really only
ever use before(:all) to set up things that are global collaborators but
not the things that you are describing in the examples.>

I<The most common cases of abuse are database access and/or fixture setup.
Every example that accesses the database should start with a clean
slate, otherwise the examples become brittle and start to lose their
value with false negatives and, worse, false positives.">

(L<http://rspec.info/documentation/before_and_after.html>)

There is no restriction on having multiple before blocks.  They will run in
sequence within their respective "each" or "all" groups.  C<before "all">
blocks run before C<before "each"> blocks.

=item after each => CODE

=item after all => CODE

=item after CODE

Like C<before>, but backwards.  Runs CODE after each or all tests,
respectively.  The default is "each".

C<after "all"> blocks run I<after> C<after "each"> blocks.

=item around CODE

Defines code to be run around tests in the current describe block are
run. This code must call C<yield>..

  our $var = 0;

  describe "Something" => sub {
    around {
      local $var = 1;
      yield;
    };

    it "should have localized var" => sub {
      is $var, 1;
    };
  }; 

This CODE will run around each example.

=item yield

Runs examples in context of C<around> block.

=item shared_examples_for DESCRIPTION => CODE

Defines a group of examples that can later be included in
C<describe> blocks or other C<shared_examples_for> blocks. See
L</Shared example groups>.

Example group names are B<global>, but example groups can be defined at any
level (i.e. they can be defined in the global context, or inside a "describe"
block).

  my $browser;
  shared_examples_for "all browsers" => sub {
    it "should open a URL" => sub { ok($browser->open("http://www.google.com/")) };
    ...
  };
  describe "Firefox" => sub {
    before all => sub { $browser = Firefox->new };
    it_should_behave_like "all browsers";
    it "should have firefox features";
  };
  describe "Safari" => sub {
    before all => sub { $browser = Safari->new };
    it_should_behave_like "all browsers";
    it "should have safari features";
  };

=item it_should_behave_like DESCRIPTION

Asserts that the thing currently being tested passes all the tests in
the example group identified by DESCRIPTION (having previously been
defined with a C<shared_examples_for> block). In essence, this is like
copying all the tests from the named C<shared_examples_for> block into
the current context. See L</Shared example groups> and
L<shared_examples_for>.

=item share %HASH

Registers C<%HASH> for sharing data between tests and example groups.
This lets you share variables with code in different lexical scopes
without resorting to using package (i.e. global) variables or jumping
through other hoops to circumvent scope problems.

Every hash that is C<share>d refers to the B<same data>. Sharing a hash
will make its existing contents inaccessible, because afterwards it
contains the same data that all other shared hashes contain. The result
is that you get a hash with global semantics but with lexical scope
(assuming C<%HASH> is a lexical variable).

There are a few benefits of using C<share> over using a "regular"
global hash. First, you don't have to decide what package the hash will
belong to, which is annoying when you have specs in several packages
referencing the same shared examples. You also don't have to clutter
your examples with colons for fully-qualified names. For example, at my
company our specs go in the "ICA::TestCase" hierarchy, and
"$ICA::TestCase::Some::Package::variable" is exhausting to both the eyes
and the hands. Lastly, using C<share> allows C<Test::Spec> to provide
this functionality without deciding on the variable name for you (and
thereby potentially clobbering one of your variables).

  share %vars;      # %vars now refers to the global share
  share my %vars;   # declare and share %vars in one step

=item spec_helper FILESPEC

Loads the Perl source in C<FILESPEC> into the current spec's package. If
C<FILESPEC> is relative (no leading slash), it is treated as relative to
the spec file (i.e. B<not> the currently running script). This lets you
keep helper scripts near the specs they are used by without exercising
your File::Spec skills in your specs.

  # in foo/spec.t
  spec_helper "helper.pl";          # loads foo/helper.pl
  spec_helper "helpers/helper.pl";  # loads foo/helpers/helper.pl
  spec_helper "/path/to/helper.pl"; # loads /path/to/helper.pl

=back

=head2 Shared example groups

This feature comes straight out of RSpec, as does this documentation:

You can create shared example groups and include those groups into other
groups.

Suppose you have some behavior that applies to all editions of your
product, both large and small.

First, factor out the "shared" behavior:

  shared_examples_for "all editions" => sub {
    it "should behave like all editions" => sub {
      ...
    };
  };

then when you need to define the behavior for the Large and Small
editions, reference the shared behavior using the
C<it_should_behave_like()> function.

  describe "SmallEdition" => sub {
    it_should_behave_like "all editions";
  };

  describe "LargeEdition" => sub {
    it_should_behave_like "all editions";
    it "should also behave like a large edition" => sub {
      ...
    };
  };

C<it_should_behave_like> will search for an example group by its
description string, in this case, "all editions".

Shared example groups may be included in other shared groups:

  shared_examples_for "All Employees" => sub {
    it "should be payable" => sub {
      ...
    };
  };

  shared_examples_for "All Managers" => sub {
    it_should_behave_like "All Employees";
    it "should be bonusable" => sub {
      ...
    };
  };

  describe Officer => sub {
    it_should_behave_like "All Managers";
    it "should be optionable";
  };

  # generates:
  ok 1 - Officer should be optionable
  ok 2 - Officer should be bonusable
  ok 3 - Officer should be payable

=head3 Refactoring into files

If you want to factor specs into separate files, variable scopes can be
tricky. This is especially true if you follow the recommended pattern
and give each spec its own package name. C<Test::Spec> offers a couple
of functions that ease this process considerably: L<share|/share %HASH>
and L<spec_helper|/spec_helper FILESPEC>.

Consider the browsers example from C<shared_examples_for>. A real
browser specification would be large, so putting the specs for all
browsers in the same file would be a bad idea. So let's say we create
C<all_browsers.pl> for the shared examples, and give Safari and Firefox
C<safari.t> and C<firefox.t>, respectively.

The problem then becomes: how does the code in C<all_browsers.pl> access
the C<$browser> variable? In L<the example code|/shared_examples_for DESCRIPTION =E<gt> CODE>,
C<$browser> is a lexical variable that is in scope for all the examples.
But once those examples are split into multiple files, you would have to
use either package global variables or worse, come up with some other
hack. This is where C<share> and C<spec_helper> come in.

  # safari.t
  package Testcase::Safari;
  use Test::Spec;
  spec_helper 'all_browsers.pl';

  describe "Safari" => sub {
    share my %vars;
    before all => sub { $vars{browser} = Safari->new };
    it_should_behave_like "all browsers";
    it "should have safari features";
  };

  # firefox.t
  package Testcase::Firefox;
  use Test::Spec;
  spec_helper 'all_browsers.pl';

  describe "Firefox" => sub {
    share my %vars;
    before all => sub { $vars{browser} = Firefox->new };
    it_should_behave_like "all browsers";
    it "should have firefox features";
  };

  # in all_browsers.pl
  shared_examples_for "all browsers" => sub {
    # doesn't have to be the same name!
    share my %t;
    it "should open a URL" => sub {
      ok $t{browser}->open("http://www.google.com/");
    };
    ...
  };

=head2 Order of execution

This example, shamelessly adapted from the RSpec website, gives an overview of
the order in which examples run, with particular attention to C<before> and
C<after>.

  describe Thing => sub {
    before all => sub {
      # This is run once and only once, before all of the examples
      # and before any before("each") blocks.
    };

    before each => sub {
      # This is run before each example.
    };

    before sub {
      # "each" is the default, so this is the same as before("each")
    };

    it "should do stuff" => sub {
      ...
    };

    it "should do more stuff" => sub {
      ...
    };

    after each => sub {
      # this is run after each example
    };

    after sub {
      # "each" is the default, so this is the same as after("each")
    };

    after all => sub {
      # this is run once and only once after all of the examples
      # and after any after("each") blocks
    };

  };

=head1 SEE ALSO

L<RSpec|http://rspec.info>, L<Test::More>, L<Test::Deep>, L<Test::Trap>,
L<Test::Builder>.

The mocking and stubbing tools are in L<Test::Spec::Mocks>.

=head1 AUTHOR

Philip Garrett <philip.garrett@icainformatics.com>

=head1 CONTRIBUTING

The source code for Test::Spec lives on L<github|https://github.com/kingpong/perl-Test-Spec>

If you want to contribute a patch, fork my repository, make your change,
and send me a pull request.

=head1 SUPPORT

If you have found a defect or have a feature request please report an
issue at https://github.com/kingpong/perl-Test-Spec/issues. For help
using the module, standard Perl support channels like
L<Stack Overflow|http://stackoverflow.com/> and
L<comp.lang.perl.misc|http://groups.google.com/group/comp.lang.perl.misc>
are probably your best bet.

=head1 COPYRIGHT & LICENSE

Copyright (c) 2010-2011 by Informatics Corporation of America.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
