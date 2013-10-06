use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Test::Spec',
    VERSION_FROM      => 'lib/Test/Spec.pm', # finds $VERSION
    PREREQ_PM         => {
      'Carp'           => 0,
      'Exporter'       => 0,
      'List::Util'     => 0,
      'Package::Stash' => 0.23,
      'Scalar::Util'   => 0,
      'TAP::Parser'    => 0,
      'Test::Deep'     => 0.103, # earlier versions clash with UNIVERSAL::isa
      'Test::More'     => 0,
      'Test::Trap'     => 0,
      'Tie::IxHash'    => 0,
      'constant'       => 0,
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Test/Spec.pm', # retrieve abstract from module
       AUTHOR         => 'Philip Garrett <philip.garrett@icainformatics.com>') : ()),
    LICENSE => 'perl',
    META_MERGE        => {
        resources => {
            repository => 'https://github.com/kingpong/perl-Test-Spec',
        },
    },
);
