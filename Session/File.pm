package CGI::Session::File;

use strict;
use vars qw($VERSION);
use base qw(CGI::Session CGI::Session::MD5);
use Carp 'croak';
use File::Spec;
use Fcntl qw(:DEFAULT :flock);
use Data::Dumper;


###########################################################################
######## CGI::Session::File - for storing session data in plain files #####
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



$Data::Dumper::Indent = 0;
$VERSION = "2.5";


# So that CGI::Session's AUTOLOAD doesn't bother looking for it. 
# Too expensive
sub DESTROY { }



# Constructor is inherited from base class



sub retrieve {
    my ($self, $sid, $options) = @_;

    # getting the options passed to the constructor
    my $dir     = $options->{Directory};

	unless ( $dir ) {
		my $class = ref($self);
		croak "Usage: $class->new(\$sid, {Directory=>'/some/dir'})";
	}

    # creating an OS independant path to the session file and the lockfile
    my $file    = File::Spec->catfile($dir, "CGI-Session-$sid.dat");    
    
    sysopen(LCK, $file, O_RDWR|O_CREAT, 0644) or $self->error("Could not open $file: $!"), return;
    flock(LCK, LOCK_SH) or $self->error("Couldn't acquite lock on $file: $!"), return;
	
    # getting the data from the session file
    local ( $/, *FH );
    sysopen(FH, $file, O_RDONLY) or $self->error("Couldn't open data file ($file), $!"), return;
    my $tmp = <FH>;
    close (FH);

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

    # creating an OS independant path
    my $file    = File::Spec->catfile($dir, "CGI-Session-$sid.dat");
	
    # opening the lockfile
    sysopen (LCK, $file, O_RDWR|O_CREAT, 0664) or $self->error("Couldn't open $file: $!"), return;
    flock(LCK, LOCK_EX) or $self->error("Couldn't acquire lock on $file, $!"), return;

    # storing the data in the session file
    local (*FH);
    sysopen (FH, $file, O_RDWR|O_CREAT|O_TRUNC, 0664) or $self->error("Couldn't create $file, $!"), return;

    # creating a Data::Dumper object of $hashref
    my $d = Data::Dumper->new([$hashref], ["data"]);

    # dumping the $hashref into a session file
    print FH $d->Dump();
    close (FH);

    return 1;
}



sub tear_down {
    my ($self, $sid, $options) = @_;
   
    my $dir = $options->{Directory};    
    my $file = File::Spec->catfile($dir, "CGI-Session-$sid.dat");
    
	unlink $file or $self->error("Couldn't delete the session data $file: $!"), return;
    return 1;
}



1;



=pod

=head1 NAME

CGI::Session::File - For stroing session data in plain files.

=head1 SYNOPSIS

	use constant COOKIE => "TEST_SID";	# cookie to store the session id

	use CGI::Session::File;
	
	$session = new CGI::Session::File(undef,
		{			
			Directory		=>'/tmp/sessions'
		});

	# for more examples see CGI::Session manual
	
=head1 DESCRIPTION

C<CGI::Session::File> is the driver for the L<CGI::Session|CGI::Session> 
to store and retrieve the session data in and from plain text files. To be 
able to write your own drivers for the L<CGI::Session|CGI::Session>, please
consult L<developer section|CGI::Session/DEVELOPER SECTION> of the 
L<manual|CGI::Session>

Constructor requires two arguments, as all other L<CGI::Session> drivers do.
The first argument has to be session id to be initialized (or undef to tell
the CGI::Session  to create a new session id). The second argument has to be
a reference to a hash with two following require key/value pairs:

=over 4

=item C<Directory>

path in the file system where all the session data will be stored

=back

In versions prior to 2.6 one also had to indicate the LockDirectory, but
it is no longer required.

C<CGI::Session::File> serializes session data using  L<Data::Dumper|Data::Dumper>
before storing it in the session file.

=head1 AUTHOR

Sherzod B. Ruzmetov <sherzodr@cpan.org>

=head1 COPYRIGHT

	This library is free software and can be redistributed under the same
	conditions as Perl itself.

=head1 SEE ALSO

L<CGI::Session>, L<CGI::Session::File>, L<CGI::Session::DB_File>,
L<CGI::Session::MySQL>, L<Apache::Session>

=cut

