use 5.008005;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
my %MM_ARGS = (
    NAME              => 'Test::Spec',
    VERSION_FROM      => 'lib/Test/Spec.pm', # finds $VERSION
    PREREQ_PM         => {
      'Carp'           => 0,
      'Exporter'       => 0,
      'List::Util'     => 0,
      'Package::Stash' => 0.23,
      'Scalar::Util'   => 1.11,
      'Test::Deep'     => 0.103, # earlier versions clash with UNIVERSAL::isa
      'Test::More'     => 0.88,
      'Test::Trap'     => 0,
      'Tie::IxHash'    => 0,
      'constant'       => 0,
    },
    TEST_REQUIRES => {
      'TAP::Parser'        => 0,
      'Devel::GlobalPhase' => 0,
    },
    ABSTRACT_FROM  => 'lib/Test/Spec.pm', # retrieve abstract from module
    AUTHOR         => 'Philip Garrett <philip.garrett@icainformatics.com>',
    LICENSE => 'perl',
    META_MERGE        => {
        'meta-spec' => { version => 2.0 },
        resources => {
            repository => {
                type => 'git',
                web => 'https://github.com/kingpong/perl-Test-Spec',
                url => 'https://github.com/kingpong/perl-Test-Spec',
            },
            bugtracker => {
                web => 'https://github.com/kingpong/perl-Test-Spec/issues',
            },
        },
    },
);

$MM_ARGS{BUILD_REQUIRES} = {%{$MM_ARGS{BUILD_REQUIRES}}, %{delete $MM_ARGS{TEST_REQUIRES}}}
  if $eumm_version < 6.63_03;
$MM_ARGS{PREREQ_PM} = {%{$MM_ARGS{PREREQ_PM}}, %{delete $MM_ARGS{BUILD_REQUIRES}}}
  if $eumm_version < 6.55_01;
WriteMakefile(%MM_ARGS);
