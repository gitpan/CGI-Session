# file.t - CGI::Session::File test

use constant F_NAME => "Sherzod";
use constant L_NAME => "Ruzmetov";
use constant BROTHERS => [qw(Hasan Husan Sherzod Behzod)];
use constant PARENTS => { dad => "Bahodir", mom=>"Faroghat"};

use strict;
use Test;
use File::Spec;
use CGI::Session::DB_File;
use CGI;

ok(1);

my $cgi = new CGI;
my $lockdir = "t"; # File::Spec->catfile('t', 'lockdir');
my $filename = File::Spec->catfile('t', 'sessions.db');

my $session = new CGI::Session::DB_File(undef, {LockDirectory=>$lockdir, FileName=>$filename});

ok($session);
ok($session->id);

$session->param("fname", F_NAME);
$session->param("lname", L_NAME);
$session->param("brothers", BROTHERS);
$session->param("parents", PARENTS);

ok($session->param("fname"), F_NAME);
ok($session->param("lname"), L_NAME);

my $brothers = $session->param("brothers");

ok($brothers);
ok($brothers->[2], BROTHERS->[2]);

my $parents = $session->param("parents");

ok($parents->{mom}, "Faroghat");
ok($parents->{dad}, "Bahodir");

ok($session->param(), 4);

$session->clear(["brothers"]);

ok($session->param(), 3);

$session->load_param($cgi, "fname", "lname");

ok($cgi->param(), 2);
ok($session->param("lname"), $cgi->param("lname"));

$session->clear();
my $worked = ($session->param) ? 0 : 1;
ok($worked);

$session->save_param($cgi);

ok($session->param, 2);

$worked = ( $session->param("_session_id") ) ? 0 : 1;
ok($worked);

my $sid = $session->id();
$session->delete();

$session = new CGI::Session::DB_File($sid, {LockDirectory=>$lockdir, FileName=>$filename});

ok($session);

$worked = ($session->id() eq $sid) ? 0 : 1;
ok($worked);

BEGIN { 
	
	plan tests => 18

};

