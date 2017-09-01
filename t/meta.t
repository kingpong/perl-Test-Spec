use strict;
use warnings;

unless ($ENV{RELEASE_TESTING}) {
    plan(skip_all => "Author tests not required for installation");
}

eval "use CPAN::Meta";
plan(skip_all => "CPAN::Meta required for testing MYMETA.json") if $@;
my $mymeta = CPAN::Meta->load_file('MYMETA.json');

use Test::More;
my (@requirements) = required_modules($mymeta);
ok scalar(@requirements);
done_testing();

sub required_modules {
    my $prereqs = $mymeta->effective_prereqs;
    my $requires = $prereqs->merged_requirements;
    return $requires->required_modules;
}

__END__
use Test::Spec;
describe 'MYMETA.json' => sub {
    it 'lists prereqs' => sub {
        my $mymeta = CPAN::Meta->load_file('MYMETA.json');
        print STDERR Dumper($mymeta->effective_prereqs);



    };
};

run_tests();
