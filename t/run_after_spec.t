use Test::Spec;
my($first_nested_after, $second_nested_after, $inner_after, $second_inner_after, $todo_after);

describe "outer describe block" => sub {
    describe "inner block" => sub {
        describe "first nested block" => sub {
            it "runs first" => sub {
                ok(! $first_nested_after ,"first nested block");
            };
            after all => sub {
                $first_nested_after = 1;
                ok(1, "after all - first nested block");
            };
        };
        describe "second nested block" => sub {
            it "first nested after has run by now" => sub {
                ok($first_nested_after, "first nested after has run");
            };
            it "doesn't run second nest after until all it's have run" => sub {
                ok(! $second_nested_after, "second nested after hasn't run yet")
            };
            after all => sub {
                $second_nested_after = 1;
                ok(1, "after all - second nested block");
            };
        };

        after all => sub {
            $inner_after = 1;
            ok($second_nested_after, "second nested after has run");
        };
    };
    describe "second inner" => sub {
        it "inner block after has run" => sub {
            ok($inner_after, "inner blocks after has run");
        };
        after all => sub {
            $second_inner_after = 1;
            ok(1, "after all - second inner");
        }
    };
    xdescribe "TODO context" => sub {
        it "shouldn't run the after all here" => sub {
            ok(0);
        };
        after all => sub {
            $todo_after = 1;
            ok(0, "I should never run\n");
        };
    };
    after all => sub {
        ok(! $todo_after, "todo after block didn't run");
        ok($second_inner_after, "second inner after has run");
    };
};

runtests;
