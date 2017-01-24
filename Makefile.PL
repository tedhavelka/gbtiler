use ExtUtils::MakeMaker;
WriteMakefile (
    NAME         => 'TilerArguments',
    VERSION      => "2.0",
    EXE_FILES    => [ qw(script/gbtiler) ],
    ($] >= 5.005
      ? (ABSTRACT   => 'Routines gbtiler project.')
      : ()),
     'dist' => {COMPRESS=>'gzip',SUFFIX=>'gz'}
);
