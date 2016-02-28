package Test::Spec::Example;

# Purpose: represents an `it` block

use strict;
use warnings;

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

sub _name       { shift->{name} }
sub description { shift->{description} }
sub _code       { shift->{code} }
sub _builder    { shift->{builder} }
sub _context    { shift->{context} }

# Build a stack from the starting context
# down to the current context
sub _stack {
  my ($self) = @_;

  my $ctx = $self->_context;

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
  eval { $self->_runner($self->_stack) };

  # And trap any errors
  if (my $err = $@) {
    my $builder = $self->_builder;
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
      $ctx->_in_anonymous_context($self->_code, $self);
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

__END__

=head1 NAME

Test::Spec::Example - An example test case within a group

=head1 SYNOPSIS

  use Test::Spec; # automatically turns on strict and warnings

  describe "A test example" => sub {

    it "has a description" => sub {
      my $example = shift;

      is $example->description => 'has a description';
    };

  };

  runtests unless caller;

=head1 DESCRIPTION

L<Test::Spec::Context> will create an instance that represents the example
test case and pass it to your C<it> block.

You are unlikely to use this class directly.

=head2 ATTRIBUTES

=over 4

=item description()

Returns the string used to create the example.

=back

=head2 METHODS

=over 4

=item run()

Runs the current example

=back

=head1 SEE ALSO

L<Test::Spec>.

=head1 AUTHOR

Philip Garrett <philip.garrett@icainformatics.com>

=head1 CONTRIBUTING

The source code for Test::Spec lives on github:
  https://github.com/kingpong/perl-Test-Spec

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
