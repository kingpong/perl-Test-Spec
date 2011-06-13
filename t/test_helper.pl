use strict;
use FindBin qw($Bin);

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

sub capture_tap {
  require File::Spec;
  my ($spec_name) = @_;
  my @incflags = map { "-I$_" } @INC;
  open(my $SPEC, '-|') || do {
    open(STDERR, ">&STDOUT") || die "can't reopen stderr: $!";  # 2>&1
    exec($^X, @incflags, File::Spec->catfile($Bin, $spec_name));
  };
  my $tap = do { local $/; <$SPEC> };
  close($SPEC);
  return $tap;
}

sub parse_tap {
  require TAP::Parser;
  my ($spec_name) = @_;
  my $tap = capture_tap($spec_name);
  my $parser = TAP::Parser->new({ tap => $tap });
  my @results;
  while (my $result = $parser->next) {
    push @results, $result;
  }
  return @results;
}

1;
