package CGI::Session::File;

use strict;
use vars qw($VERSION);
use Carp;
use base qw(CGI::Session CGI::Session::MD5);

use File::Spec;
use Fcntl qw(:DEFAULT :flock);
use Data::Dumper;

# do not use any indentation
$Data::Dumper::Indent = 0;
$VERSION = "2.2";


# constructor is inherited from CGI::Session
sub retrieve {
    my ($self, $sid, $options) = @_;

    # getting the options passed to the constructor
    my $dir     = $options->{Directory};
    my $lckdir  = $options->{LockDirectory};

	unless ( $dir && $lckdir ) {
		my $class = ref($self);
		croak "Usage: $class->new(\$sid, {Directory=>'/some/dir', LockDirectory=>'/some/dir'})";
	}

    # creating an OS independant path to the session file and the lockfile
    my $file    = File::Spec->catfile($dir, "CGI-Session-$sid.dat");
    my $lckfile =File::Spec->catfile($lckdir, "CGI-Session-$sid.lck");

    # opening the lockfile
    sysopen(LCK, $lckfile, O_RDONLY|O_CREAT, 0644) or $self->error("Couldn't create lockfile, $!"), return;
    flock(LCK, LOCK_SH) or $self->error("Couldn't acquire lock on $lckfile, $!"), return;

    # getting the data from the session file
    local ( $/, *FH );
    sysopen(FH, $file, O_RDONLY) or $self->error("Couldn't open data file ($file), $!"), return;
    my $tmp = <FH>;
    close (FH); close (LCK);

    # intializing the hashref
    my $data = {}; eval $tmp;

    # did something go wrong?
    if ( $@ ) { $self->error("Couldn't eval() the data, $!"), return }

    # returning the eval()ed data
    return $data;
}


sub store {
    my ($self, $sid, $hashref, $options) = @_;

    # getting the options passed to the constructor
    my $dir     = $options->{Directory};
    my $lckdir  = $options->{LockDirectory};

    # creating an OS independant path
    my $file    = File::Spec->catfile($dir, "CGI-Session-$sid.dat");
    my $lckfile = File::Spec->catfile($lckdir, "CGI-Session-$sid.lck");

    # opening the lockfile
    sysopen (LCK, $lckfile, O_RDONLY|O_CREAT, 0664) or $self->error("Couldn't open $lckfile, $!"), return;
    flock(LCK, LOCK_EX) or $self->error("Couldn't acquire lock on $lckfile, $!"), return;

    # storing the data in the session file
    local (*FH);
    sysopen (FH, $file, O_RDWR|O_CREAT|O_TRUNC, 0664) or $self->error("Couldn't create $file, $!"), return;

    # creating a Data::Dumper object of $hashref
    my $d = Data::Dumper->new([$hashref], ["data"]);

    # dumping the $hashref into a session file
    print FH $d->Dump();
    close (FH); close LCK;

    return 1;
}


sub tear_down {
    my ($self, $sid, $options) = @_;

    # getting the options passed to the constructor
    my $dir = $options->{Directory};

    # discovering the session filename
    my $file = File::Spec->catfile($dir, "CGI-Session-$sid.dat");

    # deleting the file
    unlink $file or $self->error("Couldn't delete the session data $file: $!"), return;

    return 1;
}



1;

=pod

=head1 NAME

CGI::Session::File - CGI::Session driver for

=head1 SYNOPSIS

	use constant COOKIE => "TEST_SID";	# cookie to store the session id

	use CGI::Session::File;
	use CGI;

	my $cgi = new CGI;

	# getting the session id from the cookie
	my $c_sid = $cgi->cookie(COOKIE) || undef;
	
	my $session = new CGI::Session::File($c_sid, 
		{
			LockDirectory	=>'/tmp/locks', 
			Directory		=>'/tmp/sessions'
		});
	
	# now let's create a sid cookie and send it to the client's browser.
	# if it is an existing session, it will be the same as before,
	# but if it's a new session, $session->id() will return a fresh one
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

C<CGI::Session::File> is the driver for the L<CGI::Session|CGI::Session> to store and retrieve
the session data in and from the plain text files. To be able to write your own
drivers for the L<CGI::Session|CGI::Session>, please consult L<developer section|CGI::Session/DEVELOPER SECTION>
of the L<manual|CGI::Session>

Constructor requires two arguments, as all other L<CGI::Session> drivers do.
The first argument has to be session id to be initialized (or undef to tell
the CGI::Session  to create a new session id). The second argument has to be
a reference to a hash with two following require key/value pairs:

=over 4

=item C<Directory>

path in the file system where all the session data will be stored

=item C<LockDirectory>

path in the file system where all the lock files for the sessions will be stored

=back

C<CGI::Session::File> uses L<Data::Dumper|Data::Dumper> to serialize the session data
before storing it in the session file. 

=head2 Example
	
	# get the sessino id either from the SID cookie, or from
	# the sid parameter in the URL
	my $c_sid = $cgi->cookie("SID") || $cgi->param("sid") || undef;
	my $session = new CGI::Session::File($c_sid, 
		{
			LockDirectory => '/tmp', 
			Directory	  => '/tmp'
		});

For more extensive examples of the L<CGI::Session|CGI::Session> usage, please refer to 
L<CGI::Session> manual.

=head1 AUTHOR

Sherzod B. Ruzmetov <sherzodr@cpan.org>

=head1 COPYRIGHT

This library is free software and can be redistributed under the same
conditions as Perl itself.

=head1 SEE ALSO

L<CGI::Session>, L<CGI::Session::File>, L<CGI::Session::DB_File>,
L<CGI::Session::MySQL>, L<Apache::Session>

=cut

