# file.t - CGI::Session::File test

use constant F_NAME => "Sherzod";
use constant L_NAME => "Ruzmetov";
use constant BROTHERS => [qw(Hasan Husan Sherzod Behzod)];
use constant PARENTS => { dad => "Bahodir", mom=>"Faroghat"};

use strict;
use Test;
use File::Spec;
use CGI::Session::File;
use CGI;
use Cwd;

BEGIN { 
	plan tests => 26
};

ok(1);

my $cgi = new CGI;
my $lockdir = "t"; # File::Spec->catfile('t', 'lockdir');
my $dir     = "t"; # File::Spec->catfile('t', 'sessions');

my $session = new CGI::Session::File(undef, {LockDirectory=>$lockdir, Directory=>$dir})
	or die $CGI::Session::errstr;

ok($session);
ok($session->id);

$session->param("fname", F_NAME);
$session->param("lname", L_NAME);
$session->param("brothers", BROTHERS);
$session->param("parents", PARENTS);

ok($session->param("fname"), F_NAME);
ok($session->param("lname"), L_NAME); # test 5

my $brothers = $session->param("brothers");

ok($brothers);
ok($brothers->[2], BROTHERS->[2]);

my $parents = $session->param("parents");

ok($parents->{mom}, "Faroghat");
ok($parents->{dad}, "Bahodir");

ok($session->param(), 4); # test 10

$session->clear(["brothers"]);

ok($session->param(), 3);

$session->load_param($cgi, "fname", "lname");

ok($cgi->param(), 2);
ok($session->param("lname"), $cgi->param("lname"));

$session->clear();
my $worked = ($session->param) ? 0 : 1;
ok($worked);

$session->save_param($cgi);

ok($session->param, 2); # test 15

$worked = ( $session->param("_session_id") ) ? 0 : 1;
ok($worked);

my $sid = $session->id();

$session->delete();

$session = new CGI::Session::File($sid, {LockDirectory=>$lockdir, Directory=>$dir});

ok($session);

$worked = ($session->id() eq $sid) ? 0 : 1;
ok($worked);

# in the new sesssion atime and ctime have to be the same
ok( $session->atime(), $session->ctime() );

# in the new session, expiration date has to be undef
ok($session->expires() ? 0 : 1);  # test 20

# let's set the exp date, and see if expires() works this time
$session->expires("1M");
ok($session->expires() ? 1 : 0);


$sid = $session->id();
#now let's reopen the session with the new SID

undef $session;

$session = new CGI::Session::File($sid, {LockDirectory=>$lockdir, Directory=>$dir});

ok($session);
ok($session->id(), $sid);
#warn "atime: ", $session->atime(), "ctime: ", $session->ctime(), "\n";
ok($session->atime, $session->ctime);



$session->param("Author", "Sherzod B. Ruzmetov");
$session->param("Name", "CGI::Session::File");
$session->param("Version", CGI::Session::File->VERSION);
$session->param("email", 'sherzodr@cpan.org');

ok($session->param('Version'), $CGI::Session::File::VERSION);  # 25
ok($session->param("Name"), "CGI::Session::File");


