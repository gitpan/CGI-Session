# $Id: /local/cgi-session/trunk/t/g4_storable.t 220 2005-08-30T11:47:14.305150Z sherzodr  $

use strict;
use diagnostics;

use Test::More;
use File::Spec;
use CGI::Session::Test::Default;

eval { require Storable };
plan(skip_all=>"Storable is NOT available") if $@;

my $t = CGI::Session::Test::Default->new(
    dsn => "driver:file;serializer:Storable",
    args=>{Directory=>File::Spec->catdir('t', 'sessiondata')});

plan tests => $t->number_of_tests;
$t->run();
