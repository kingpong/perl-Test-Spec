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
  my ($spec_name) = @_;

  require File::Spec;
  require File::Temp;
  my ($fh,$filename) = File::Temp::tempfile('tmpfileXXXXXX', UNLINK => 1, TMPDIR => 1);
  my $pid = fork || do {
    STDOUT->fdopen(fileno($fh), "w") || die "can't reopen stdout: $!";
    STDERR->fdopen(fileno($fh), "w") || die "can't reopen stderr: $!";
    exec($^X, (map { "-I$_" } @INC), File::Spec->catfile($Bin, $spec_name));
    die "couldn't exec '$spec_name'";
  };
  waitpid($pid,0);
  seek($fh, 0, 0);
  my $tap = do { local $/; <$fh> };
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
