package CGI::Session::DB_File;

use strict;
use vars qw($VERSION);
use base qw(CGI::Session CGI::Session::MD5);

use File::Spec;
use Data::Dumper;
use Fcntl qw(:DEFAULT :flock);
use DB_File;

$VERSION = "2.4";


# do not use any indentation
$Data::Dumper::Indent = 0;

sub retrieve {
    my ($self, $sid, $options) = @_;

    my $file    = $options->{FileName};
    my $lckdir  = $options->{LockDirectory};

	my $lckfile = File::Spec->catfile($lckdir, "CGI-Session-$sid.lck");
	sysopen (LCK, $lckfile, O_RDWR|O_CREAT, 0664) 
		or $self->error("Couldn't create lockfile $lckfile, $!"), return;
	flock (LCK, LOCK_SH) 
		or $self->error("Couldn't lock $lckfile	, $!"), return;

    tie my %session, "DB_File", $file, O_RDWR|O_CREAT, 0777 
		or $self->error("Couldn't open $file, $!"), return;

    my $tmp = $session{$sid} or $self->error("Session ID '$sid' doesn't exist"), return;
    
	untie %session;
	close (LCK);

	my $data = {};	eval $tmp;

	return $data;
}





sub store {
    my ($self, $sid, $hashref, $options) = @_;

    my $file    = $options->{FileName};
    my $lckdir  = $options->{LockDirectory};

	my $lckfile = File::Spec->catfile($lckdir, "CGI-Session-$sid.lck");
	sysopen (LCK, $lckfile, O_RDWR|O_CREAT, 0664) or $self->error("Couldn't create lockfile $lckfile, $!"), return;
	flock (LCK, LOCK_EX) 
		or $self->error("Couldn't lock $lckfile, $!"), return;
	
    tie my %session, "DB_File", $file, O_RDWR|O_CREAT, 0777 
		or $self->error("Couldn't open $file: $!"), return;
	
	my $d = Data::Dumper->new([$hashref], ["data"]);
    
	$session{$sid} = $d->Dump();
    
	untie %session;
	close (LCK);

    return 1;
}



sub tear_down {
	my ($self, $sid, $options) = @_;
	
	my $file = $options->{FileName};
	my $lckdir = $options->{LockDirectory};

	tie (my %session, "DB_File", $file) or die $!;
	delete $session{$sid};
	untie %session;

}

1;

=pod

=head1 NAME

CGI::Session::DB_File - Driver for CGI::Session class

=head1 SYNOPSIS

	use constant COOKIE => "TEST_SID";	# cookie to store the session id

	use CGI::Session::DB_File;
	use CGI;

	my $cgi = new CGI;

	# getting the 
	my $c_sid = $cgi->cookie(COOKIE) || undef;
	
	my $session = new CGI::Session::DB_File($c_sid, 
		{
			LockDirectory	=>'/tmp/locks', 
			FileName		=> '/tmp/sessions.db'
		});
	
	# now let's create a sid cookie and send it to the client's browser.
	# if it is an existing session, it will be the same as before,
	# but if it's a new session, $session->id() will return a new session id.
	{
		my $new_cookie = $cgi->cookie(-name=>COOKIE, -value=>$session->id);
		print $cgi->header(-cookie=>$new_cookie);
	}

	print $cgi->start_html("CGI::Session::File");

	# assuming we already saved the users first name in the session
	# when he visited it couple of days ago, we can greet him with
	# his first name

	print "Hello", $session->param("f_name"), ", how have you been?";

	print $cgi->end_html();

=head1 DESCRIPTION

C<CGI::Session::DB_File> is the driver for C<CGI::Session> to store and retrieve
the session data in and from the Berkeley DB 1.x. To be able to write your own
drivers for the L<CGI::Session>, please consult L<developer section|CGI::Session/DEVEROPER SECTION>
of the L<manual|CGI::Session>.

Constructor requires two arguments, as all other L<CGI::Session> drivers do.
The first argument has to be session id to be initialized (or undef to tell
the L<CGI::Session>  to create a new session id). The second argument has to be
a reference to a hash with two following require key/value pairs:

=over 4

=item C<Filename>

path to a file where all the session data will be stored

=item C<LockDirectory>

path in the file system where all the lock files for the sessions will be stored

=back

C<CGI::Session::DB_File> uses L<Data::Dumper|Data::Dumper> to serialize the session data
before storing it in the session file. 

=head2 Example
	
	# get the sessino id either from the SID cookie, or from
	# the sid parameter in the URL
	my $c_sid = $cgi->cookie("SID") || $cgi->param("sid") || undef;
	my $session = new CGI::Session::DB_File($c_sid, 
		{
			LockDirectory=>'/tmp', 
			FileName=>'/tmp/sessions.db'
		});

For more extensive examples of the C<CGI::Session> usage, please refer to L<CGI::Session manual|CGI::Session>

=head1 AUTHOR

Sherzod B. Ruzmetov <sherzodr@cpan.org>

=head1 COPYRIGHT

This library is free software and can be redistributed under the same
conditions as Perl itself.

=head1 SEE ALSO

L<CGI::Session>, L<CGI::Session::File>, L<CGI::Session::DB_File>,
L<CGI::Session::MySQL>, L<Apache::Session>

=cut
