#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Session::DB_File;

my ($cgi, $Session, $sid);

$cgi = new CGI;

# Assume we prevously saved the session_id in the user's computer as a cookie.
# Let's see if it's still there. If not, just assign $sid an undef.
$sid = $cgi->cookie('TESTER_SID') || undef;

# If the $sid could be found in the cookie, than the object will be
# initialized with all the previous information saved in the session.
$Session = new CGI::Session::DB_File($sid, {FileName=>'sessions.db', LockDirectory=>'.'});

# If session_id couldn't be retrieved from the cookie, new id was supposed to be
# created, right? So let's find out what id that is
$sid ||=$Session->id;

# Now we need to construct a cookie, and save it into the user's
# computer so that we can access it next time the user logs in
my $cookie = $cgi->cookie(-name=>'TESTER_SID', -value=>$sid, -expires=>"+3d");

# Now we're sending the cookie back to the user's computer.
print $cgi->header(-cookie=>$cookie),
    $cgi->start_html("CGI::Session");

print $cgi->a({-href=>$cgi->script_name()."?_cmd=delete"}, "Delete the session");


if ($Session->param('last_visited_time') ) {

    print $cgi->h2("Hi, your last visit was on " .
                    localtime($Session->param('last_visited_time')));

} else {

    print $cgi->h2("Welcome to my site, I hope you'll enjoy it");

}


# Now update the session.

$Session->param(-name=>'last_visited_time', -value=>time());

$Session->close();

print $cgi->end_html;
