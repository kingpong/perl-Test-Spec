use strict;

{
  package SpecStub;
  sub new { bless do { \my $stub }, shift() }
  sub AUTOLOAD { shift }
}

sub stub_builder_in_packages {
  my $code = pop;
  my @packages = @_ ? @_ : 'A';
  push @packages, 'Test::More';

  my $stub = SpecStub->new;
  my @locals = map { "local *${_}::builder = sub { \$stub };" } @packages;

  local $, = " ";
  eval "@locals; \$code->()";
  die $@ if $@;
}

1;
