package Test::Spec::SharedHash;
use strict;
use warnings;
use Tie::Hash;
use base qw(Tie::StdHash);

# a semaphore
our $Initialized = 0;

our %STASH;

sub TIEHASH {
  my $class = shift;
  my $ref = \%STASH;
  bless $ref, $class;
  return $ref;
}

sub reset {
  %STASH = ();
}

1;
