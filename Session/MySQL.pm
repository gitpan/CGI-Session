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

$VERSION = "2.4";

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

    my ($tmp) = $dbh->selectrow_array(qq|SELECT a_session FROM $TABLE_NAME WHERE id=?|, undef, $sid);	

	$lckh->do("UNLOCK TABLES");	
	
	my $data = {}; eval $tmp;

	if ( $@ ) {
		$self->error("Couldn't eval() the data, $@"), return;
	}

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

	use CGI::Session::MySQL;	
	use DBI;

	my $dbh = DBI->connect("DBI:mysql:dev", "dev", "marley01");

	my $session = new CGI::Session::MySQL(undef, 
		{
			LockHandle		=> $dbh,
			Handle			=> $dbh
		});
	
	
	# For examples see CGI::Session manual

=head1 DESCRIPTION

C<CGI::Session::MySQL> is the driver for the L<CGI::Session> class to store 
and retrieve the session data in and from the MySQL database 

To be able to write your own drivers for L<CGI::Session>, please consult 
L<developer section|CGI::Session/DEVELOPER SECTION> of L<CGI::Session manual|CGI::Session>.

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


C<sessions> is the default name CGI::Session::MySQL would work with. We
suggest you to stick with this name for consistency. In case for any reason
you want to use a different name, just update $CGI::Session::MySQL::TABLE
variable before creating the object:

	use CGI::Session::MySQL;
	my DBI;

	$CGI::Session::MySQL::TABLE = 'my_sessions';
	$dbh = DBI->connect("dbi:mysql:dev", "dev", "marley01");

	$session = new CGI::Session::MySQL(undef, {
				Handle => $dbh,
				LockHandle => $dbh});

=head1 AUTHOR

Sherzod B. Ruzmetov <sherzodr@cpan.org>

=head1 COPYRIGHT

This library is free software and can be redistributed under the same
conditions as Perl itself.

=head1 SEE ALSO

L<CGI::Session>, L<CGI::Session::File>, L<CGI::Session::DB_File>,
L<CGI::Session::MySQL>, L<Apache::Session>

=cut
