package CGI::Session::MySQL;

use strict;
use vars qw($VERSION $TABLE_NAME);
use base qw(CGI::Session CGI::Session::MD5);

use Data::Dumper;
use Carp;
eval "require DBI";

if ( $@ ) {
	$CGI::Session::errstr = $@;
}

$VERSION = "2.1";

# chose the most compat from of serialization in Data::Dumper
$Data::Dumper::Indent = 0;

# This is the sessions table. Change it if you want to 
# use some other table for your sessions data
$TABLE_NAME = 'sessions';

# returns $dbh and $lckh
sub MYSQL_dbh {
	my ($self, $option) = @_;

	my $dbh     = $option->{Handle};
    my $lckh    = $option->{LockHandle};
    my $dsn     = $option->{DataSource};
    my $username= $option->{UserName};
    my $psswd   = $option->{Password};
    my $lcksn   = $option->{LockDataSource} || $dsn;
    my $lckuser = $option->{LockUserName} || $username;
    my $lckpsswd= $option->{LockPassword} || $psswd;

	if ( $dbh && $lckh ) {
		return ($dbh, $lckh);
	}

	$dbh	= DBI->connect($dsn, $username, $psswd) or $self->error($DBI::errstr), return;
	$lckh	= DBI->connect($lcksn, $lckuser, $lckpsswd) or $self->error($DBI::errstr), return;

	return ($dbh, $lckh);
}









sub retrieve {
    my ($self, $sid, $option) = @_;

    my ($dbh, $lckh) = $self->MYSQL_dbh($option) or return;
	$lckh->do("LOCK TABLES $TABLE_NAME READ");

    my $tmp = $dbh->selectrow_array(qq|SELECT a_session FROM $TABLE_NAME WHERE id=?|, undef, $sid);	

	$lckh->do("UNLOCK TABLES");	
	
	my $data = {};
	eval $tmp;

	return $data;
}










sub store {
    my ($self, $sid, $hashref, $option) = @_;

	my ($dbh, $lckh) = $self->MYSQL_dbh($option);	
    my $d = Data::Dumper->new([$hashref], ["data"]);
    my $exists = $dbh->selectrow_array(qq|SELECT a_session FROM $TABLE_NAME WHERE id=?|, undef, $sid);

	$lckh->do("LOCK TABLES $TABLE_NAME WRITE");

    if ( $exists ) {		
        my $rv = $dbh->do(qq|UPDATE $TABLE_NAME SET a_session=? WHERE id=?|, undef, $d->Dump(), $sid);
		$lckh->do("UNLOCK TABLES");
		return $rv;
    }

    my $rv =  $dbh->do(qq|INSERT INTO $TABLE_NAME SET id=?, a_session=?|, undef, $sid, $d->Dump());
	$lckh->do("UNLOCK TABLES");
	return $rv;
}








sub tear_down {
    my ($self, $sid, $option) = @_;

	my ($dbh, $lckh) = $self->MYSQL_dbh($option);    

	$lckh->do("LOCK TABLES $TABLE_NAME WRITE");
    my $rv =  $dbh->do(qq|DELETE FROM $TABLE_NAME WHERE id=?|, undef, $sid);  
	$lckh->do("UNLOCK TABLES");
	return $rv;
}







1;


=pod

=head1 NAME

CGI::Session::MySQL - Driver for CGI::Session class

=head1 SYNOPSIS

	use constant COOKIE => "TEST_SID";	# cookie to store the session id

	use CGI::Session::MySQL;
	use CGI;
	use DBI;

	my $dbh = DBI->connect("DBI:mysql:dev", "dev", "marley01");
	my $cgi = new CGI;

	# getting the session id from the cookie
	my $c_sid = $cgi->cookie(COOKIE) || undef;
	
	my $session = new CGI::Session::MySQL($c_sid, 
		{
			LockHandle		=> $dbh,
			Handle			=> $dbh
		});
	
	# now let's create a sid cookie and send it to the client's browser.
	# if it is an existing session, it will be the same as before,
	# but if it's a new session, $session->id() will return a new session id.
	{
		my $new_cookie = $cgi->cookie(-name=>COOKIE, -value=>$session->id);
		print $cgi->header(-cookie=>$new_cookie);
	}

	print $cgi->start_html("CGI::Session::MySQL");

	# assuming we already saved the users first name in the session
	# when he visited it couple of days ago, we can greet him with
	# his first name

	print "Hello", $session->param("f_name"), ", how have you been?";

	print $cgi->end_html();

=head1 DESCRIPTION

C<CGI::Session::MySQL> is the driver for the L<CGI::Session> class to store 
and retrieve the session data in and from the MySQL database 

To be able to write your own drivers for L<CGI::Session>, please consult 
L<CGI::Session manual|CGI::Session>.

Constructor requires two arguments, as all other L<CGI::Session> drivers do.
The first argument has to be session id to be initialized (or undef to tell
the L<CGI::Session>  to create a new session id). The second argument has to be
a reference to a hash with two following required key/value pairs:

=over 4

=item C<Handle>

this has to be a database handler returned from the C<DBI->connect()> 
(see L<DBI manual|DBI>, L<DBD::mysql manual|DBD::mysql>)

=item C<LockHandle>

This is also a handler returned from the C<DBI->connect()> for locking the sessions
table.

=back

You can also ask C<CGI::Session::MySQL> to create a handler for you. To do this
you will need to pass it the following key/value pairs as the second argument:

=over 4

=item C<DataSource>

Name of the datasource L<DBI> has to use. Usually C<DBI:mysql:db_name>

=item C<UserName>

Username who is able to access the above C<DataSource>

=item C<Password>

Password the C<UserName> has to provide to be able to access the C<DataSource>.

=back

It also expects C<LockDatasource>, C<LockUserName> and C<LockPassword> key/values,
but if they are missing defaults to the ones provided by C<DataSource>, C<UserName> 
and C<Password> respectively. 

C<CGI::Session::MySQL> uses L<Data::Dumper|Data::Dumper> to serialize the session data
before storing it in the session file. 

=head1 STORAGE

Since the data should be stored in the mysql table, you will first need to
create a sessions table in your mysql database. The following command should
suffice for basic use of the library:

	CREATE TABLE sessions (
		id CHAR(32) NOT NULL PRIMARY KEY,
		a_session TEXT
	);

=head1 Example
	
	# get the sessino id either from the SID cookie, or from
	# the sid parameter in the URL
	my $c_sid = $cgi->cookie("SID") || $cgi->param("sid") || undef;
	my $session = new CGI::Session::MySQL($c_sid, 
		{
			Handle => $dbh,
			LockHandle => $dbh
		});

For more extensive examples of the L<CGI::Session> usage, please refer to 
the L<manual|CGI::Session>

=head1 AUTHOR

Sherzod B. Ruzmetov <sherzodr@cpan.org>

=head1 COPYRIGHT

This library is free software and can be redistributed under the same
conditions as Perl itself.

=head1 SEE ALSO

L<CGI::Session>, L<CGI::Session::File>, L<CGI::Session::DB_File>,
L<CGI::Session::MySQL>, L<Apache::Session>

=cut
