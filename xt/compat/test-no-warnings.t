use Test::Spec; # need to load Test::Spec first so it's END {} block is called last
use Test::NoWarnings;

describe "Test::Spec" => sub {
    it "works with Test::NoWarnings" => sub {
        pass;
    };
};

runtests if !caller;
