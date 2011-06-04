package Test::Spec;
use strict;
use warnings;
use Test::Trap ();        # load as early as possible to override CORE::exit

our $VERSION = '0.30';

use base qw(Exporter);

use Carp ();
use Exporter ();
use Tie::IxHash ();

use constant { DEFINITION_PHASE => 0, EXECUTION_PHASE => 1 };

our $TODO;
our $Debug = $ENV{TEST_SPEC_DEBUG} || 0;

our @EXPORT      = qw(runtests describe before after it they *TODO);
our @EXPORT_OK   = ( @EXPORT, qw(DEFINITION_PHASE EXECUTION_PHASE $Debug) );
our %EXPORT_TAGS = ( all => \@EXPORT_OK,
                     constants => [qw(DEFINITION_PHASE EXECUTION_PHASE)] );

our $_Current_Context;
our $_Package_Contexts = _ixhash();
our %_Package_Phase;
our %_Package_Tests;

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

  # specific imports requested
  if (@_) {
    $class->export_to_level(1, $callpkg, @_);
    return;
  }

  eval "package $callpkg; use base 'Test::Spec';";
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

  return $class->_execute_tests( $class->_pick_tests(@_) );
}

sub builder {
  # this is a singleton.
  Test::Builder->new;
}

sub _pick_tests {
  my ($class,@matchers) = @_;
  my @tests = $class->tests;
  for my $pattern (@matchers) {
    # ignore case unless uppercase is present, i.e. "smartcase"
    my $expr = ($pattern =~ /[[:upper:]]/) ? qr/$pattern/ : qr/$pattern/i;
    @tests = grep { $_ =~ $expr } @tests;
  }
  return @tests;
}

sub _execute_tests {
  my ($class,@tests) = @_;
  for my $test (@tests) {
    $class->can($test)->();
  }
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
  push @{ _autovivify_context($package)->tests }, { name => $name, code => $code };
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

  my ($parent,$context);
  if ($_Current_Context) {
    $parent = $_Current_Context->context_lookup;
  }
  else {
    $parent = $_Package_Contexts->{$package} ||= _ixhash();
  }

  # Don't clobber contexts of the same name, aggregate them.
  if ($parent->{$name}) {
    $context = $parent->{$name};
  }
  else {
    $context = Test::Spec::Context->new;
    $context->name( $name );
    $context->class( $package );
    $context->parent( $_Current_Context ); # might be undef
    $parent->{$name} = $context;
  }

  # push a context onto the stack
  local $_Current_Context = $context;

  # evaluate the context function, which will set up lexical variables and
  # define tests and other contexts
  $context->contextualize(sub { $code->() }); 
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

sub _materialize_tests {
  my $class = shift;
  my $contexts = $_Package_Contexts->{$class};
  if (not $contexts && %$contexts) {
    warn "no examples defined in spec package $class";
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
    return $_Package_Contexts->{$package}{$name} ||= 
      Test::Spec::Context->new({ name => $name, class => $package, parent => undef });
  }
}

# Public interface.
sub current_context {
  $_Current_Context
}

sub contexts {
  my ($class) = @_;
  my @ctx = values %{ $_Package_Contexts->{$class} || {} };
  return wantarray ? @ctx : \@ctx;
}

sub _ixhash {
  tie my %h, 'Tie::IxHash';
  \%h;
}

# load context implementation
require Test::Spec::Context;

1;

=head1 NAME

Test::Spec - Write tests in a declarative specification style

=head1 SYNOPSIS

  use Test::Spec; # automatically turns on strict

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

This module is inspired by and borrows heavily from RSpec
(http://rspec.info/documentation/), a BDD tool for the Ruby programming
language.

=head2 EXPORTS

When given B<no list> (i.e. C<use Test::Spec;>), this class will export:

=over 4

=item * C<describe>, C<it>, C<before>, C<after>, and C<runtests>

These are the functions you will use to define behaviors and run your specs.

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

Runs all the examples whose descriptions match one of the regular expressions
in C<@patterns>. If C<@patterns> is not provided, runs I<all> examples.  The
environment variable "SPEC" will be used as a default pattern if present.

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

=item TODO_SPECIFICATION

An alias for L</it>.  This is useful for describing behavior for groups of
items, so the verb agrees with the noun:

  describe "Captives of Buffalo Bill" => sub {
    they "put the lotion on their skin" => sub {
      ...
    };
    they "put the lotion in the basket"; # TODO
  };

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


=back

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

RSpec (http://rspec.info), L<Test::More>, L<Test::Deep>, L<Test::Trap>,
L<Test::Builder>.

The mocking and stubbing tools are in L<Test::Spec::Mocks>.

=head1 AUTHOR

Philip Garrett <philip.garrett@icainformatics.com>

=head1 CONTRIBUTING

The source code for Test::Spec lives on github:
  https://github.com/kingpong/perl-Test-Spec

If you want to contribute a patch, fork my repository, make your change,
and send me a pull request.

=head1 COPYRIGHT & LICENSE

Copyright (c) 2010 by Informatics Corporation of America.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
