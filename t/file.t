#!/usr/bin/perl

# file.t - CGI::Session::File test suite

use strict;
use Test;
use CGI;
use CGI::Session::File;

my $hashref = {
	f_name	=> "Sherzod",
	l_name  => "Ruzmetov",
	emails	=> ['sherzodr@cpan.org', 'sherzodr@hotmail.com', 'sherzodr@ultracgis.com'],
	parents => {
		dad => "Bahodir",
		mom => "Faroghat"
	},
};
my $arrayref = [qw(one two three four five six seven eight nine ten)];
my $scalar = "CGI::Session";


ok(1);							# 1: Loaded

my $cgi		= new CGI;
my $_options= { LockDirectory=>'t', Directory=>'t'};
my $session = new CGI::Session::File(undef, $_options);

ok($session);					# 2: Object created

ok($session->id);				# 3: Session id exists

ok($session->ctime);			# 4: Created time exists

ok($session->atime);			# 5: Last access time set

ok($session->expires ? 0 : 1);	# 6: Expires time should be undef

ok($session->param, 0);			# 7: There should be no parameters yet

ok($session->param("_session_id") ?0 : 1);
								# 8: special  names shouldn't be getable

ok($session->param("_session_id", "abcde") ? 0 : 1);
								# 9: special names shouldnt be setable

ok($session->param("libname", $scalar));
								# 10: should return true

ok($session->param("libname"), $scalar);
								# 11: should return the value assigned

ok($session->param, 1);			# 12: Should return 1 since just one assignment done

ok($session->param('bio', $hashref));
								# 13: Another, but more complex assignment

ok($session->param, 2);			# 14: Should indicate presence of 2 params

ok($session->param("numbers", $arrayref));
								# 15: Third assignment

ok($session->param, 3);			# 16: Third indeed


# Let's save the SID and time attributes of the session
my $sid = $session->id();
my $ctime = $session->ctime();
my $atime = $session->atime();

# Now sleep a while to make sure that some time passes
sleep(1);

my $new_session = new CGI::Session::File($sid, $_options);

ok($new_session);					# 17: Seccond object was created

ok($new_session->id, $sid);			# 18: Both IDs are the same

ok($new_session->ctime(), $ctime);  # 19: Creatiion time should be the same

ok($new_session->atime > $atime);   # 20: Check if access times were updated

ok($new_session->param, 3);			# 21: Three params should still be present

ok($new_session->param("libname"), "CGI::Session");
									# 22: Is libname still the same?

ok(ref($new_session->param("bio")), "HASH");
									# 23: bio was supposed to be a hashref


# re-creating the bio as a hashref
my $bio = $new_session->param("bio");

ok($bio->{f_name}, "Sherzod");		# 24: Checking the first name

ok(scalar(@{$bio->{emails}}), 3);	# 25: Should be 3 emails

ok($bio->{parents}->{dad}, "Bahodir");
									# 26: What's my Dad's name


ok($new_session->clear(["libname"]));
									# 27: Clear a param and synchronize

ok($new_session->param, 2);			# 28: Now we should have just 2 params

# make it expire in two days
$new_session->expires("2d");

ok($new_session->expires);			# 29: was expiration date set properly


# Deleting the session 
$new_session->delete;



# now let's try load the same session after delete() was called
my $another_new_session = new CGI::Session::File( $sid, $_options );

ok($another_new_session);			# 30: was it created?

ok($another_new_session->id ne $sid); # 31: should be a differnet ID now

ok($another_new_session->param, 0); # 32: make sure that it is brand new session

BEGIN {
	plan tests => 32;
}

