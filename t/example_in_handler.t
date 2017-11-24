#!/usr/bin/env perl
package Testcase::Spec::ExampleInHandler;
use Test::Spec;

describe "Test::Spec" => sub {
  it "should pass an example instance" => sub {
    my ($example) = @_;
    ok($example);
    isa_ok($example, 'Test::Spec::Example');
  };
};

runtests unless caller;
