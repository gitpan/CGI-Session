# $Id: /mirror/cgi-session/trunk/t/g4.t 220 2005-08-30T11:47:14.305150Z sherzodr  $

use strict;
use diagnostics;

use File::Spec;
use CGI::Session::Test::Default;
use Test::More;

my $t = CGI::Session::Test::Default->new(
    args=>{Directory=>File::Spec->catdir('t', 'sessiondata')});

plan tests => $t->number_of_tests;
$t->run();
