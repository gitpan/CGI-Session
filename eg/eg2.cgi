#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Session::DB_File;

my ($cgi, $Session, $sid);

$cgi = new CGI;

# Getting the previuosly stored cookie.
$sid = $cgi->cookie("Example2_SID");

$Session = new CGI::Session::DB_File($sid, {FileName=>'sessions.db', LockDirectory=>'.'});

# Load the paramters to CGI environment is $sid exists.
if ($sid) { $Session->load_param($cgi) }

# Generate a new cookie just in case if $sid doesn't yet exist.
my $cookie = $cgi->cookie(-name=>'Example2_SID', -value=>$Session->id, -expires=>"+1d");

# Print the header, and don't forget to send the cookie as well
print $cgi->header(-cookie=>$cookie),
    $cgi->start_html("CGI::Session / Example 2"),
    $cgi->h2("Example 2");


if ($cgi->param('_cmd') eq 'save') {

    # Save the parameters once they were submitted
    $Session->save_param($cgi);


    print $cgi->div("Thanks, for your registration. Just hope that we're not one of those bastards who keep sending you all kinds of spam.");

    # now you could do smt more with that email, but we won't.

} else {

    $Session->param('name') and
        print $cgi->div("Wellcome back" . $Session->param('name') );

    print $cgi->h2("Please, subscribe to our magazine");
    print $cgi->start_form,
        $cgi->hidden(-name=>'_cmd', -value=>'save'),
        $cgi->div("Your name:"),
        $cgi->textfield(-name=>'name', -size=>40),
        $cgi->div("Your email address:"),
        $cgi->textfield(-name=>'email', -size=>40),$cgi->br,
        $cgi->submit(-value=>'Subscribe'),
        $cgi->end_form;

}

print $cgi->end_html;