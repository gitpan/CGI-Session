# file.t - CGI::Session::MySQL test suite

use strict;
use Test;
use CGI;

eval {require DBI; require DBD::mysql; require CGI::Session::MySQL};
if ( $@ ) {
    print "1..0\n";
    exit;
}


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



my $cgi		= new CGI;

my $dbh;

$dbh = DBI->connect("dbi:mysql:test", $ENV{USER} || 'test', undef,
	{RaiseError=>0, PrintError=>0, AutoCommit=>1});

unless ( $dbh ) {
	print "skip\n";
	exit;
}

$dbh->do(qq|DROP TABLE IF EXISTS sessions|);
$dbh->do(qq|CREATE TABLE sessions ( id CHAR(32) NOT NULL PRIMARY KEY, a_session TEXT )|)
		or print "skip\n", exit;


my $_options= { LockHandle=>$dbh, Handle=>$dbh};
tie my %session, "CGI::Session::MySQL", undef, $_options;


ok(tied(%session));                     # 2: Object created

ok($session{_session_id});              # 3: Id exists


ok($session{_session_ctime});           # 4: Created tiem

ok($session{_session_atime});           # 5: Last access time set

ok(tied(%session)->expires ? 0 : 1);    # 6: Expires time should be undef

ok(tied(%session)->param, 0);           # 7: There should be no parameters yet

ok($session{_session_id});              # 8: special  names should be accessible

$session{_session_id} = 'abcde';

ok($session{_session_id} ne 'abcde');   # 9: special names shouldn't be setable

$session{bio} = $hashref;

ok($session{bio});                      # 10: Hashref assignment succeeded

$session{libname} = "CGI::Session";

ok($session{libname});                  # 11: scalar assignment succeeded

$session{nums} = $arrayref;

ok($session{nums});                     # 12: arrayref assignment

# let's save the session id now for future reference
my $sid = $session{_session_id};
my $atime = $session{_session_atime};
my $ctime = $session{_session_ctime};

ok($sid);                               # 13: Could we save session id

untie %session;

ok($session{_session_id} ? 0 : 1);      # 14: We shouldn't have access to
                                        # session data anymore

# Let's load this sessio back again after a while
sleep(1);

tie %session, "CGI::Session::MySQL", $sid, $_options;

ok(tied(%session));						# 15: Could the session be created

ok($session{_session_id} eq $sid);		# 16: Is it the same session as before?

ok($session{_session_ctime}, $ctime);	# 17: Should have the same creation time

ok($session{_session_atime} > $atime);	# 18: Check if last access time was updated

ok(ref($session{bio}) eq 'HASH');		# 19: Check if the hashref was preserved

# loadnig the bio hashref
my $bio = $session{bio};

ok($bio->{f_name}, "Sherzod");			# 20: Checking my first name

ok(@{$bio->{emails}}, 3);				# 21: Checking if i still have 3 emails

ok($bio->{parents}->{dad}, "Bahodir");	# 22: Checking if my Dad's name is correct

ok($session{libname}, "CGI::Session");	# 23: Checking the library name

delete $session{_session_id};

ok($session{_session_id} ? 1 : 0);		# 24: We shouldn't be able to clear()
										# special names

delete $session{libname};

ok($session{libname} ? 0 : 1);			# 25: But we should be able to clear()
										# everything else

ok($session{bio}->{f_name}, "Sherzod");	# 26: Checking if other names still exist

# let's delete the session for good
tied(%session)->delete();

untie %session;

# now let's try to load the same session after we deleted it from the disk

tie %session, "CGI::Session::MySQL", $sid, $_options;

ok(tied(%session));						# 27: Could the object be created?

ok($session{_session_id} ne $sid);		# 28: It should be a new session now

ok($session{bio} ? 0 : 1);				# 29: Just in case :)

$session{exists} = 1;

ok($session{exists});					# 30: Just a flag

%session = ();							# testing CLEAR()	


ok($session{exists} ? 0 : 1);			# 31: our flag should've been cleared too

ok($session{_session_id});				# 32: But our session id should remain

ok(keys %session, 4);					# 33: Checking keys() function


$session{_session_etime} = "2d";		

ok($session{_session_etime} > time());	# 34: Checking if we could set it


BEGIN {
    plan todo=>[1,34];
}
