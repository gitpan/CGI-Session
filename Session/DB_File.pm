package CGI::Session::DB_File;

use strict;
use vars qw($VERSION);
use base qw(CGI::Session CGI::Session::MD5);

use File::Spec;
use Data::Dumper;
use Fcntl qw(:DEFAULT :flock);
use DB_File;
use Safe;

###########################################################################
######## CGI::Session::DB_File - for storing session data in Berkely DB  ##
###########################################################################
#                                                                         #
# Copyright (c) 2002 Sherzod B. Ruzmetov. All rights reserved.            #
# This library is free software. You may copy and/or redistribute it      #
# under the same conditions as Perl itself. But I do request that this    #
# copyright notice remains attached to the file.                          #
#                                                                         #
# In case you modify the code, please document all the changes you have   #
# made prior to destributing the library                                  #
###########################################################################


$VERSION = "2.6";

# Configuring Data::Dumper for our needs
$Data::Dumper::Indent	= 0;
$Data::Dumper::Purity	= 0;
$Data::Dumper::Useqq	= 1;
$Data::Dumper::Deepcopy	= 0;



# So that CGI::Session's AUTOLOAD doesn't bother looking for it. 
# Too expensive
sub DESTROY {
	my $self = shift;
	my $options = $self->options;
	my $sid = $self->id;

	# our job here is to get rid of the lock files. They are nasty!
	my $lockfile = File::Spec->catfile($options->{LockDirectory}, "CGI-Session-$sid.lck");

	if ( -e $lockfile ) {		
		unlink $lockfile;
	}
}



sub retrieve {
    my ($self, $sid) = @_;

	
	my $options = $self->options();
    my $file    = $options->{FileName};
    my $lckdir  = $options->{LockDirectory};

	my $lckfile = File::Spec->catfile($lckdir, "CGI-Session-$sid.lck");
	sysopen (LCK, $lckfile, O_RDWR|O_CREAT, 0664) 
		or $self->error("Couldn't create lockfile $lckfile, $!"), return;
	flock (LCK, LOCK_SH) 
		or $self->error("Couldn't lock $lckfile	, $!"), return;

    tie my %session, "DB_File", $file, O_RDWR|O_CREAT, 0664 
		or $self->error("Couldn't open $file, $!"), return;

    my $tmp = $session{$sid} or $self->error("Session ID '$sid' doesn't exist"), return;
 
	untie %session;
	close (LCK);

	
	# Following line is to keep -T line happy. In fact it is an evil code,
	# that's why we'll be compiling $tmp under the restricted eval() later
	# to ensure it's indeed safe. If you have a better solution, please
	# take this burden of guilt off my conscious.
    ($tmp) = $tmp =~ m/^(.+)$/s;

    my $cpt = Safe->new("CGI::Session::File::CPT");
    $cpt->reval($tmp);

    if ( $@ ) {
        $self->error("Couldn't eval() the data, $!"), return undef;
    }
    
    return $CGI::Session::File::CPT::data;
}





sub store {
    my ($self, $sid) = @_;

	my $options = $self->options();
	
	my $hashref = $self->raw_data();

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
	my ($self, $sid) = @_;

	my $options = $self->options();
	
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

	my $session = new CGI::Session::DB_File(undef, 
		{
			LockDirectory	=>'/tmp/locks', 
			FileName		=> '/tmp/sessions.db'
		});
		
	# For examples look at CGI::Session manual

=head1 DESCRIPTION

C<CGI::Session::DB_File> is the driver for C<CGI::Session> to store and retrieve
the session data in and from the Berkeley DB 1.x. To be able to write your own
drivers for the L<CGI::Session>, please consult L<developer section|CGI::Session/DEVELOPER SECTION>
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
