# file.t - CGI::Session::File test

use constant MYSQL_DSN => "DBI:mysql:test";
use constant MYSQL_USER => $ENV{USER} || "test";
use constant MYSQL_PSSWD => undef;

use constant F_NAME => "Sherzod";
use constant L_NAME => "Ruzmetov";
use constant BROTHERS => [qw(Hasan Husan Sherzod Behzod)];
use constant PARENTS => { dad => "Bahodir", mom=>"Faroghat"};


use strict;
use Test;
use CGI::Session::MySQL;
use CGI;

BEGIN { 
	plan todo => [1..18],
};

# let's check if DBI is available. If not skip the whole test
eval "require DBI";
if ( $@ ) {	
	print "skip\n";
	exit(0);
}

# let's check if DBI supports mysql
# thanks to Brian King for his efforts on testing
# the library on DBD-disabled MacOS X (darwin)
eval "require DBD::mysql";
if ( $@ ) {
	print "skip\n";
	exit(0);
}

my $cgi = new CGI;

my $dbh = DBI->connect(MYSQL_DSN, MYSQL_USER, MYSQL_PSSWD,
	{RaiseError=>0, PrintError=>0, AutoCommit=>1});

unless ( $dbh ) {
	print "skip\n";
	exit(0);
}

$dbh->do(qq|DROP TABLE IF EXISTS sessions|) or print "skip", exit(0);
$dbh->do(qq|CREATE TABLE sessions (id CHAR(32) NOT NULL, a_session TEXT)|) or print "skip", exit(0);

my $session = new CGI::Session::MySQL(undef, {Handle=>$dbh, LockHandle=>$dbh});

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

$session = new CGI::Session::MySQL($sid, {Handle=>$dbh, LockHandle=>$dbh});

ok($session);

$worked = ($session->id() eq $sid) ? 0 : 1;
ok($worked);

