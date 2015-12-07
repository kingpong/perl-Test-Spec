package Test::Spec::Example;

# Purpose: represents an `it` block

use strict;
use warnings;

########################################################################
# NO USER-SERVICEABLE PARTS INSIDE.
########################################################################

use Carp ();
use Scalar::Util ();

sub new {
  my ($class, $args) = @_;

  if (!$args || ref($args) ne 'HASH') {
    Carp::croak "usage: $class->new(\\%args)";
  }

  my $self = bless {}, $class;
  foreach my $attr ( qw/name description code builder context/ ) {
    $self->{$attr} = $args->{$attr} || Carp::croak "$attr missing";
  }

  Scalar::Util::weaken($self->{context});

  return $self;
}

sub name        { shift->{name} }
sub description { shift->{description} }
sub code        { shift->{code} }
sub builder     { shift->{builder} }
sub context     { shift->{context} }

# Build a stack from the starting context
# down to the current context
sub stack {
  my ($self) = @_;

  my $ctx = $self->context;

  my @ancestors = $ctx;
  while ( $ctx = $ctx->parent ) {
      push @ancestors, $ctx;
  }

  return reverse(@ancestors);
}

sub run  {
  my ($self) = @_;

  # clobber Test::Builder's ok() method just like Test::Class does,
  # but without screwing up underscores.
  no warnings 'redefine';
  my $orig_builder_ok = \&Test::Builder::ok;
  local *Test::Builder::ok = sub {
    my ($builder,$test,$desc) = splice(@_,0,3);
    $desc ||= $self->description;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    $orig_builder_ok->($builder, $test, $desc, @_);
  };

  # Run the test
  eval { $self->_runner($self->stack) };

  # And trap any errors
  if (my $err = $@) {
    my $builder = $self->builder;
    my $description = $self->description;

    # eval in case stringification overload croaks
    chomp($err = eval { $err . '' } || 'unknown error');
    my ($file,$line);
    ($file,$line) = ($1,$2) if ($err =~ s/ at (.+?) line (\d+)\.\Z//);

    # disable ok()'s diagnostics so we can generate a custom TAP message
    my $old_diag = $builder->no_diag;
    $builder->no_diag(1);
    # make sure we can restore no_diag
    eval { $builder->ok(0, $description) };
    my $secondary_err = $@;
    # no_diag needs a defined value, so double-negate it to get either '' or 1
    $builder->no_diag(!!$old_diag);

    unless ($builder->no_diag) {
      # emulate Test::Builder::ok's diagnostics, but with more details
      my ($msg,$diag_fh);
      if ($builder->in_todo) {
        $msg = "Failed (TODO)";
        $diag_fh = $builder->todo_output;
      }
      else {
        $msg = "Failed";
        $diag_fh = $builder->failure_output;
      }
      print {$diag_fh} "\n" if $ENV{HARNESS_ACTIVE};
      print {$builder->failure_output} qq[#   $msg test '$description' by dying:\n];
      print {$builder->failure_output} qq[#     $err\n];
      print {$builder->failure_output} qq[#     at $file line $line.\n] if defined($file);
    }
    die $secondary_err if $secondary_err;
  }
}

sub _runner {
  my ($self, $ctx, @remainder) = @_;

  # This recursive closure essentially does this
  # $outer->contextualize {
  #   $outer->before_each
  #   $inner->contextualize {
  #     $inner->before_each
  #     $anon->contextualize {
  #       $anon->before_each (no-op)
  #         execute test
  #       $anon->after_each (no-op)
  #     }
  #     $inner->after_each
  #   }
  #   $outer->after_each
  # }
  #
  return $ctx->contextualize(sub {
    $ctx->_run_before_all_once;
    $ctx->_run_before('each');
    if ( @remainder ) {
      $self->_runner(@remainder);
    }
    else {
      $ctx->_in_anonymous_context($self->code, $self);
    }
    $ctx->_run_after('each');
    # "after 'all'" only happens during context destruction (DEMOLISH).
    # This is the only way I can think to make this work right
    # in the case that only specific test methods are run.
    # Otherwise, the global teardown would only happen when you
    # happen to run the last test of the context.
  }, $self);
}

1;
