# $Id: /mirror/cgi-session/trunk/t/g4_dbfile_storable.t 220 2005-08-30T11:47:14.305150Z sherzodr  $

use strict;
use diagnostics;

use Test::More;
use File::Spec;
use CGI::Session::Test::Default;

for ( "DB_File", "Storable" ) {
    eval "require $_";
    if ( $@ ) {
        plan(skip_all=>"$_ is NOT available");
        exit(0);
    }
}

my $t = CGI::Session::Test::Default->new(
    dsn => "d:DB_File;s:Storable;id:md5",
    args=>{FileName => File::Spec->catfile('t', 'sessiondata', 'cgisess.db')});

plan tests => $t->number_of_tests;
$t->run();
