## *** THIS IS A WORK IN PROGRESS ***
## Brett Whitty <brett@gnomatix.com>, January 2017

## Translates C=64 Sound Effects Code
## From Macross Assembly into BASIC,
## Executes with VICE C=64 Emulator,
## Captures Audio Output as MP3 

## See comments in 'c64_sfx_to_mp3.pl' for details...

## Software Dependencies:

  VICE C=64 Emulator
    $ brew install vice
    $ brew install lame ## (??? not sure, but maybe for mp3)

  FFMPEG
    $ brew install ffmpeg

  tok64
    Included under 'src'; run 'make'; see tok64 README for author info.
    Modified by me to compile without errors with 'gcc'.

## Perl Module Dependencies
## (Some of these may be in Perl core, others from CPAN::Plus)

  Cwd
  Encode
  Encode::Encoder
  File::Basename
  File::Copy
  File::Slurp
  File::Spec::Functions
  File::Temp
  File::Which
  Getopt::Long
  IPC::Open2
