package #
Locale::Codes::LangExt_Retired;


use strict;
require 5.006;
use warnings;
use utf8;

our($VERSION);
$VERSION='3.56';

$Locale::Codes::Retired{'langext'}{'alpha'}{'code'} = {
   q(rsi) => q(Rennellese Sign Language),
   q(yds) => q(Yiddish Sign Language),
};

$Locale::Codes::Retired{'langext'}{'alpha'}{'name'} = {
   q(hawai'i pidgin sign language) => [ q(hps), q(Hawai'i Pidgin Sign Language) ],
   q(rennellese sign language) => [ q(rsi), q(Rennellese Sign Language) ],
   q(yiddish sign language) => [ q(yds), q(Yiddish Sign Language) ],
};


1;
