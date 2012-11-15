use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker;
WriteMakefile
(
  NAME         => 'Folio-Reader',
  VERSION_FROM => 'lib/Folio/Reader.pm',
  PREREQ_PM    => {
         'Moo'                    => '0.0',
         'MooX::Types::MooseLike' => '0.0',
         'File::Slurp'            => '0.0',
         'Imager'                 => '0.0',
         'PDL'                    => '0.0',
         'Set::Scalar'            => '0.0',
         'Tkx'                    => '0.0',
         'Try::Tiny'              => '0.0',
         'forks'                  => '0.0',
         'Thread::Pool::Simple'   => '0.0',
         'YAML::XS'               => '0.0',
  },
  BUILD_REQUIRES => {
    'Test::More'    => '0.0',
    'Data::Printer' => '0.0',
  },
);
