package Test::Spec::TodoExample;

# Purpose: represents a `xit` block (ie. a pending/todo test)

use strict;
use warnings;

use Test::Spec qw(*TODO);

sub new {
    my ($class, $args) = @_;

    my $self = bless {}, $class;
    $self->{name}        = $args->{name};
    $self->{description} = $args->{description};
    $self->{reason}      = $args->{reason} || '(unimplemented)';
    $self->{builder}     = $args->{builder};

    return $self;
}

# Attributes
sub name        { shift->{name} }
sub description { shift->{description} }
sub reason      { shift->{reason} }
sub builder     { shift->{builder} }

# Methods
sub run {
    my ($self) = @_;

    local $TODO = $self->reason;
    my $builder = $self->builder;

    $builder->todo_start($TODO);
    $builder->ok(1, $self->description); # XXX: could fail the TOOD (or even run it?)
    $builder->todo_end();
}

1;
