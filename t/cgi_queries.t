#!/usr/bin/perl

# file.t - CGI::Session::MySQL test suite

use strict;
use Test;
use CGI;
use CGI::Session::File;

ok(1);						# 1: Loaded ok

my $_options = {Directory=>'t'};
my @fruits = qw(apple peach grapes cherry);

my $cgi = CGI->new();
ok($cgi);					# 2: CGI object created 

my $session = CGI::Session::File->new(undef, $_options);
ok($session);				# 3: session object created

# Now we are setting some CGI parameters
$cgi->param(-name=>"fruits", -values=>\@fruits);

$session->save_param($cgi);

my $old = $session->param("fruits");

ok(ref($old) eq 'ARRAY');	# 4: Checking if it really stored an arrayref
ok( @{$old} == 4 );			# 5: checking if we it realy saved 4 fruits

ok ( $old->[0], 'apple');	# 6: checking if the first  fruit is really an apple


# now ceating a new session, but first let's save the old  session id
my $sid = $session->id();
ok($sid);					# 7: checking if we have the session id


my $session1 = new CGI::Session::File($sid, $_options);

ok($session1);				# 8: checking if the new session  was created

ok($session->id, $sid);		# 9: are the session ids the same?

my $new_cgi = new CGI;

ok($new_cgi);				# 10: new CGI object

# loading the fruits
$session1->load_param($new_cgi, ["fruits"]);

ok($new_cgi->param("fruits"));


BEGIN {
	plan (tests => 11);
}

