use strict;
use FindBin qw($Bin);

#
# Shim to make Win32 behave during the test suite.
#
# Using fork+exec causes an APPCRASH during show_exceptions.t. Simply
# reopening STDOUT and STDERR to the same duped filehandle causes errors in
# the output where STDOUT and STDERR are written on top of each other (even
# when autoflush is turned on). Reopening STDERR on top of STDOUT in the child
# process seems to fix this problem.
open(STDERR, ">&STDOUT") || die "can't reopen STDERR on STDOUT: $!";


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
  my ($fh,$filename) = File::Temp::tempfile('tmpfileXXXXXX', TMPDIR => 1);
  close($fh);

  open my $oldout, ">&STDOUT" or die "can't dup stdout: $!";
  open my $olderr, ">&STDERR" or die "can't dup stderr: $!";
  open(STDOUT, ">", $filename) || die "can't open '$filename' for out: $!";
  open(STDERR, ">&STDOUT")     || die "can't reopen stderr on stdout: $!";

  system($^X, (map { "-I$_" } @INC), File::Spec->catfile($Bin, $spec_name));

  open(STDERR, ">&", $olderr) || do {
    print {$olderr} "can't reopen stderr: $! " .  "at " . __FILE__ . " line " .  __LINE__ . "\n";
    exit(1);
  };
  open(STDOUT, ">&", $oldout) || die "can't reopen stdout: $!";
  open($fh, "<", $filename) || die "can't open '$filename' for read: $!";
  my $tap = do { local $/; <$fh> };
  unlink($filename) || warn "can't unlink '$filename': $!";
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
