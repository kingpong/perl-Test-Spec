Test::Spec ![Travis CI Build Status](https://travis-ci.org/kingpong/perl-Test-Spec.svg?branch=master)
==========

Test::Spec is a declarative specification‐style testing system for behavior‐
driven development (BDD) in Perl. The tests (a.k.a. examples) are named
with strings instead of subroutine names, so your fingers will suffer
less fatigue from underscore−itis, with the side benefit that the test
reports are more legible.

This module is inspired by and borrows heavily from RSpec
(http://rspec.info/documentation/), a BDD tool for the Ruby programming
language.

See `perldoc Test::Spec` for syntax examples and usage information.

Installation
------------
To install this module type the following:

   perl Makefile.PL
   make
   make test
   make install

Dependencies
------------
This module requires these other modules and libraries:

 * constant
 * Devel::GlobalPhase (for tests)
 * List::Util
 * Package::Stash (>= 0.23)
 * Scalar::Util (XS version)
 * TAP::Parser (for tests)
 * Test::Deep (>= 0.103)
 * Test::More (>= 0.88)
 * Test::Trap
 * Tie::IxHash

Author
------
Philip Garrett <philip.garrett@icainformatics.com>

Source Code
-----------
The source code for Test::Spec lives at github:
  https://github.com/kingpong/perl-Test-Spec

Copyright and License
---------------------
Copyright (c) 2011 by Informatics Corporation of America.
Copyright (c) 2015 by Philip Garrett.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.
