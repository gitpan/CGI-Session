package CGI::Session;

require 5.003;
use strict;
use Carp 'croak';
use AutoLoader 'AUTOLOAD';



###########################################################################
#### CGI::Session - Session management in CGI Applications ################
###########################################################################
#                                                                         #
# Copyright (c) 2002 Sherzod B. Ruzmetov. All rights reserved.            #
# This library is free software. You may copy and/or redistribute it      #
# under the same conditions as Perl itself. But I do request that this    #
# copyright notice remains attached to the file.                          #
#                                                                         #
# In case you modify the code, please document all the changes you have   #
# made prior to distributing the library                                  #
###########################################################################



# Global variables
use vars qw($VERSION $errstr);



$VERSION = "2.7";



###########################################################################
############### PRELOADED METHODS #########################################
###########################################################################



# new(): initializes the object for the derived class.
# Options passed to the constructor will be placed inside
# the $self->{_options} hashref. And all the session data
# will be loaded into the $self->{_data} hashref.
#
# Usage: CLASS->new($sid, {Key1 => Value1, Key2 => Value2})
#
# RETURN VALUE: object (or undef on failure)
sub new {
    my $class = shift;
    $class = ref($class) || $class;

    unless ( @_ == 2 ) {
        croak "Usage: $class->new(\$sid, {OPTIONS=>VALUES})";
    }

    my $self = {
        # _options holds all the options passed to new()
        _options => {
            sid     => $_[0],
            %{ $_[1] },
        },
        # _data holds actual session data as an in-memory
        # hash table
        _data => { },
    };

    bless $self => $class;

    # calling session initializer
    $self->_init() or return;

    return $self;
}



# I really hope derived class provided a destructor.
# But if it didn't, let us provide it for them so that
# AutoLoader doesn't bother looking for it. Too expensive!
sub DESTORY { }



# _init(): called from within new() to initialize $self->{_data},
# which is the session data. It also decides whether to
# create new session, or initialize existing one. In case
# it fails for any reason, it creates new session.
#
# RETURN VALUE: whatever _old_session() or _new_session() returns
sub _init {
    my $self = shift;

    my $sid = $self->{_options}->{sid};

    if ( defined $sid ) {

        # we are asked to initialize a certain session. So let's see
        # if we can do it.
        $self->{_data} = $self->retrieve( $self->{_options}->{sid}, $self->{_options} );

        if ( $self->{_data}->{_session_id} ) {
            # yes, we did it!

            # following line just updates the last access time of the session
            # and synchronizes the in-memory data with the one in the disk
            return $self->_old_session();

        } else {
            # oops, something wrong happened, and we couldn't load the
            # previously stored session data. So let's ret run a new session
            return $self->_new_session();
        }

    } else {

        # No one asked us for a new session, so let's create a new
        # one then
        return $self->_new_session();

    }
}



# _new_session(): initializes a new session with meta information and
# tries to store() it in the disk. Called from w/in _init().
#
# RETURN VALUE: whatever store() returns from derived class
sub _new_session {
    my $self = shift;

    # creating the session meta-table
    $self->{_data} = {
        _session_id => $self->generate_id(),
        _session_ctime => time(),
        _session_atime => time(),
        _session_etime => undef,
    };

    # storing the session
    return $self->store($self->id(), $self->{_data}, $self->{_options});
}



# _old_session(): just updates the last access time of the session
# and saves it back to the disk.
#
# RETURN VALUE: whatever store() returns (instance class method)
sub _old_session {
    my $self = shift;

    $self->{_data}->{_session_atime} = time();

    # If any server side expirations are to be performed,
    # I believe they should be right here.

    return $self->store($self->id(), $self->{_data}, $self->{_options});
}



# _assign_param(): assigns a new parameter to session and
# synchronizes with the data in disk
#
# RETURN VALUE: boolean
sub _assign_param {
    my ($self, $key, $value)  = @_;


    # check if key doesn't start with an underscore (_)
    $key =~ m/^_/ and $self->error("$key - illegal name"), return;

    # assing new value to the parameter
    $self->{_data}->{$key} = $value;

    # get the session id
    my $sid = $self->id();

    # call derived store() method
    return $self->store( $sid, $self->{_data}, $self->{_options} );
}



# _return_param(): returns a parameter
#
# RETURN VALUE: string
sub _return_param {
    my ($self, $key) = @_;

    $key =~ m/^_/ and $self->error("$key - illegal name"), return;

    return $self->{_data}->{$key};
}



# Public interface for _set_param() and _return_param() methods
# Usage: CLASS->param('name')
# Usage: CLASS->param(-name=>'name')
# Usage: CLASS->param('name', 'value')
# Usage: CLASS->param(-name=>'name', -value=>'value')
sub param {
    my $self = shift;

    my $sid = $self->id();
    my $data = $self->{_data};

    unless ( @_ ) {     # called w/o arguments
        my @params = ();
        for ( keys %{ $data } ) {
            /^_/ or push (@params, $_);
        }
        return @params;
    }

    if ( @_ == 1 ) {        # called with single argument
        return $self->_return_param($_[0]);
    }

    # assume that we've been called with -name=>'', -value=>'' syntax
    my $args = {-name => undef,  -value => undef, @_ };
    my ($name, $value) = ( $args->{'-name'}, $args->{'-value'} );

    if ( $name && $value) { # called with extended name/value syntax:
                            # (-name=>'..', -value=>'..')
        return $self->_assign_param($name, $value);

    } elsif ( $name ) {     # called with extended name syntax (-name=>'')

        return $self->_return_param( $name );

    } elsif ( @_ == 2 ) {   # called with simple name/value syntax:
                            # (key, value)
        return $self->_assign_param($_[0], $_[1]);

    }

    # if we came this far, definitely something went wrong
    my $class = ref($self);
    croak qq~Usage: $class->param("name"),\n
        $class->param(-name=>"name"),\n
        $class->param("name", "value"), \n
        $class->param(-name=>"name", -value=>"value")~;
}



1;



__END__;



###########################################################################
################ FOLLOWING METHODS ARE LOADED ON DEMAND ###################
###########################################################################



# id(): returns the session id for the current session
# Usage: CLASS->id();
#
# RETURN VALUE: string
sub id {
    my $self = shift;

    if ( @_ ) {
        my $class = ref($self);
        croak "Usage: $class->id()";
    }
    return $self->{_data}->{_session_id};
}



# close(): closes the session
# Usage: CLASS->close()
#
# RETURN VALUE: whatever DESTROY() returns
sub close {
    my $self = shift;

    if ( @_ ) {
        my $class = ref($self);
        croak   "Usage: $class->close()";
    }

    $self->DESTROY();
}



# _date_shortcuts: provides a lookup table for date shortcuts
# used by expires().
#
# RETURN VALUE: CORE::time() value
sub _date_shortcuts {
    my $arg = shift;

    my $map = {
        s => 1 ,
        m => 60 ,
        h => 3600,
        d => 86400,
        w => 604800,
        M => 2592000,
        y => 31536000
    };
		
	my ($d, $l) = $arg =~ m/^(\d+)(\w)$/;

	if ( $d && $l) {
		return $d * $map->{"$l"};
	}

    return $arg;
}



# expires(): gets/sets the expiration time for the session
# Usage: CLASS->expires([seconds]);
#
# RETURN VALUE: if used w/out arguments, returns time() value
# if expire time was set.
# if used w/ argument, returns 1
sub expires {
    my ($self, $date) = @_;

    unless ( $date ) {
        return $self->{_data}->{_session_etime};
    }

    my $in_seconds = _date_shortcuts($date);
	
    $self->{_data}->{_session_etime} = time() + $in_seconds;
}



# ctime(): created time of the session
#
# RETURN VALUE: CORE::time() value
sub ctime {
    my $self = shift;

    return $self->{_data}->{_session_ctime};
}



# atime(): last accessed time
# Usage: CLASS->atime()
#
# RETURN VALUE: CORE::time() value
sub atime {
    my $self = shift;

    if ( $_[0] ) {
        $self->{_data}->{_session_atime} = time();
    }

    return $self->{_data}->{_session_atime};
}



# This should return the hash reference to the session data
# Usage: CLASS->param_hashref();
#
# RETURN VALUE: hashref
sub param_hashref {
    my $self = shift;

    my $dataref = {};
    while ( my ($key, $value) = each %{$self->{_data}} ) {
        /^_/    or $dataref->{$key} = $value;
    }
    return $dataref;
}



# save_param(): saves the parameters in the CGI object into the session
# object.
# Usage: CLASS->save_param($cgi [, \@array])
#
# RETURN VALUE: number of parameters successfully saved
sub save_param {
    my $self = shift;
    my $cgi  = shift;
    my $class = ref($self) || $self;

    unless ( $cgi->isa("CGI") ) {
        # We didn't receive a CGI object as the first argument
        croak "Usage: $class->save_param(\$cgi [,\@array]). Where \$cgi is the CGI.pm object";
    }

    # Get the names of all the parameters the user wants to save.
    # I believe @params = @{ $_[0] } || $cgi->param() syntax looks more
    # elegant, but if $_[0] is missing, Perl will issue warnings
    my @params = ();
    if ( defined $_[0] ) {

        # If we receive other than arrayref, we're still going to die
        # with less helpful error message. So let's kill it ourselves with
        # more friendly (yeah, right) diagnostic
        unless ( ref($_[0]) eq 'ARRAY' ) {
            croak "Usage: $class->save_param(\$cgi, [\@array])";
        }

        @params = @{ $_[0] };
    }

    # If fields to be saved are not given, let's save all the available
    # fields
    unless ( @params ) {
        @params = $cgi->param();
    }

    # We have to be careful here, since CGI.pm's param('name') syntax
    # can also return an array. It is most likely to happen in checkboxes
    # and multi-select popup menus.
    my (@values, $nsaved);
    for ( @params ) {

        # Let's assume it always returns an array.
        @values = $cgi->param($_);

        if ( @values > 1 ) {
            # if it really returned a list, save the reference to it
            # in the session parameter under the same name
            $self->param($_, \@values) && ++$nsaved;
            next;
        }

        # If it returned a single value, just save the first index
        $self->param($_, $values[0]) && ++$nsaved;
    }

    # now return number of parameters successfully saved
    return $nsaved;
}



# Loads the parameters from the session object to current CGI object
# Usage: CLASS->load_param($cgi [,\@array])
#
# RETURN VALUE: number of parameters successfully loaded
sub load_param {
    my $self = shift;
    my $cgi  = shift;
    my $class = ref($self) || $self;


    unless ( $cgi->isa("CGI") ) {
        # We didn't receive a CGI object as the first argument
        croak "Usage: $class->load_param(\$cgi [,\@array]). Where \$cgi is the CGI.pm object";
    }

    # Get the names of parameters to load. If no parameters
    # provided, load all the session parameters to the current
    # CGI object
    my @params = ();
    if ( defined $_[0] ) {
        unless ( ref($_[0]) eq 'ARRAY' ) {
            croak "Usage: $class->load_param(\$cgi [,\@array])";
        }
        @params = @{ $_[0] };
    }

    unless ( @params ) {
        @params = $self->param();
    }

    # Saving CGI params into session params were not tough at all because
    # CGI->param() could return either a scalar or a list element.
    # But CGI::Session->param() can return all the available Perl
    # data structures. So we'll need to make sure to load only scalars
    # and arrayrefs and ignore all others
    my ($value, $nloaded);
    for ( @params ) {
        $value = $self->param($_);

        if ( my $type = ref($value) ) {

            if ( $type eq 'ARRAY' ) {
                # It is an arrayref
                $cgi->param(-name=>$_, -values=>$value);
                ++$nloaded;
            }

        } else {
            $cgi->param(-name=>$_, -value=>$value);
            ++$nloaded;
        }
    }

    return $nloaded;
}




# Clears all the data from the session
# Usage: CLASS->clear([\@array])
sub clear {
    my $self = shift;
    my $class = ref($self) || $self;

    # get the list of all the params the user wants to clear
    my @params = ();
    if ( defined $_[0] ) {

        unless ( ref($_[0]) eq 'ARRAY' ) {
            # It is not an arrayref we're expecting
            croak "Usage: $class->clear([\@arrayref])";
        }

        @params = @{ $_[0] };
    }

    # If the user doesn't provide with names, let's clear
    # everything
    unless ( @params ) {
        @params = $self->param();
    }

    for ( @params ) {
        /^_/ and next;      # skip  special  names
         delete $self->{_data}->{$_};
    }


    # getting session id
    my $sid = $self->id();

    # let's synchronize data in disk with the in-memory session data
    $self->store($sid, $self->{_data}, $self->{_options});
}



# sets/gets the error message to/from $CGI::Session::errstr
# Usage: CLASS->error([$msg]);
sub error {
    my ($self, $msg) = @_;

    if ( $msg ) {   $errstr = $msg  }
    else {          return $errstr  }

}



# deletes the session from the disk for good
# Usage: CLASS->delete()
sub delete {
    my $self = shift;

    my $sid = $self->id();

    $self->tear_down($sid, $self->{_options});
}



# version(): returns the version number of the
sub version {
    return $VERSION;
}



# dump(): returns string representation of the CGI::Session object.
# mostly used for debugging
# Usage: CLASS->dump([file]);
#
# RETURN VALUE: eval()able string
sub dump {
    my ($self, $file) = @_;

    require Data::Dumper;
    $Data::Dumper::Indent = 4;

    my $d = Data::Dumper->new([$self], ["session"]);

    if ( $file ) {
        # I am sure this line is subject to race conditions.

        unless ( open (DUMP, '<' . $file) ) {
            open (DUMP, '>' . $file) or croak "Couldn't' dump the object, $!\n";
            print DUMP $d->Dump();
            CORE::close (DUMP);
        }
    }

    return $d->Dump();
}



###########################################################################
################ tie() INTERFACE ##########################################
###########################################################################



# TIEHASH(): constructor required for tie() call
# Usage: tie %session, CLASS, $sid, {key1=>value1, key2=>value2, ...}
#
# RETURN VALUE: CGI::Session object
sub TIEHASH {
    my $class = shift;
    $class = ref($class) || $class;

    return $class->new($_[0], $_[1]);
}



# FETCH(): called when the hash tie()d to the class is
# accessing keys of the hash
# Usage: $session{some_key}
#
# RETURN VALUE: any Perl data stored in the session
sub FETCH {
    my ($self, $key) = @_;
    return $self->{_data}->{$key};
}



# STORE(): called when a value is assigned to a session hash
# Usage: $session{some_key} = "Some Value"
#
# RETURN VALUE: same as $session->param("some_key", "Some Value")
sub STORE {
    my ($self, $key, $value) = @_;

	# Map of the function related to the private data.
	# If user tries to set these values, we'll do it for them.
	# For everything else we'll call param() method which will return undef
	# on Special Names (see manual)
	my %ok_map = (
		_session_etime => \&expires,
		_session_atime => \&atime,
	);

	if ( exists $ok_map{$key} ) {
		return $ok_map{$key}->($self, $value);
		
	}

    return $self->param($key, $value);
}



# DELETE(): called when you delete a key from the session hash
# Usage: delete $session{some_key}
#
# RETURN VALUE: same as $self->clear([$key]);
sub DELETE {
    my ($self, $key) = @_;
    return $self->clear([$key]);
}



# EXISTS(): called when you check for the existence of a key in the
# session hash
# Usage: exists $session{some_name}
#
# RETURN VALUE: boolean
sub EXISTS {
    my ($self, $key) = @_;
    return exists $self->{_data}->{$key};
}



# FIRSTKEY(): returns the first key for each(), keys() or values()
# functions
sub FIRSTKEY {
    my ($self) = @_;

    my $temp = keys %{ $self->{_data} };
    return scalar each %{$self->{_data} };
}



# NEXTKEY(): Iterator for keys(), values() and each() functions
sub NEXTKEY {
    my ($self) = @_;

    return scalar each %{ $self->{_data} };
}



# This method is called when we empty the session hash
# by assigning it the empty list:
# Usage: %session = ();
sub CLEAR {
    my $self = shift;

    return $self->clear();
}


###########################################################################
################ POD Documentation of the library #########################
###########################################################################

=pod

=head1 NAME

CGI::Session - Perl extension for persistent session management

=head1 SYNOPSIS

    # OO interface
    use CGI::Session::File;
    use CGI;

    $cgi = new CGI;
    $sid = $cgi->cookie("SID") || $cgi->param("sid") || undef;
    $session = new CGI::Session::File($sid,
                { Directory => "/tmp"  });

    # Let's update the session id:
    $sid = $session->id;

    # Let's get the first name of the user from the form
    # and save it in the session:
    $f_name = $cgi->param( "f_name" );
    $session->param( "f_name", $f_name );

    # Later we can just initialize the user's session
    # and retrieve his first name from session data:
    $f_name = $session->param( "f_name" );




    # tie() interface:
    use CGI::Session::File;
    use CGI;

    $cgi = new CGI;
    $sid = $cgi->cookie("SID") || $cgi->param("sid") || undef;
    tie %session, "CGI::Session::File", $sid,
                { Directory => "/tmp" };


    # Let's update the session id:
    $sid = $session{ _session_id };

    # Let's get the first name of the user from the form
    # and save it in the session:
    $f_name = $cgi->param( "f_name" );
    $session{f_name} = $f_name;

    # Later we can just initialize the user's session
    # and retrieve his first name from session data:
    $f_name = $session{f_name};


    # Tricks are endless!


=head1 NOTE

As of this release there seems to be two completely different CGI::Session
libraries on CPAN. This manual refers to CGI::Session by Sherzod Ruzmetov

=head1 DESCRIPTION

C<CGI::Session> is Perl5 library that provides an easy persistent
session management system across HTTP requests. Session persistence is a
very important issue in web applications. Shopping carts, user-recognition
features, login and authentication methods and etc. all require persistent
session management mechanism, which is both secure and reliable.
C<CGI::Session> provides with just that. You can read the whole documentation
as a tutorial on session management. But if you are already familiar with
C<CGI::Session> go to the L<methods|"METHODS"> section for the list
of all the methods available.

=head1 DISTRIBUTION

Latest distribution includes:

=over 4

=item *

L<CGI::Session|CGI::Session> - base class. Heart of the distribution.

=item *

L<CGI::Session::File|CGI::Session::File> - driver for storing session data in plain files.

=item *

L<CGI::Session::DB_File|CGI::Session::DB_File> - driver for storing session data in Berkeley DB files. This is for Berkeley Database 1.x and 2.x version. For
versions higher than 2.x see L<CGI::Session::BerkeleyDB|CGI::Session::BerkeleyDB>

=item *

L<CGI::Session::MySQL|CGI::Session::MySQL> - driver for storing session data in L<MySQL tables|CGI::Session::MySQL/STORAGE>.

=back

=head1 INSTALLATION

You can download the latest release of the library either from
http://www.CPAN.org or from http://modules.ultracgis.com/dist. The library
is distributed as .tar.gz file, which is a zipped tar-ball. You can
unzip and unpack the package with the following single command (% is your shell
prompt):

    % gzip -dc CGI-Session-2.6.tar.gz | tar -xof -

It should create a folder named the same as the distribution name except the
C<.tar.gz> extension. If you have access to system's @INC folders
( usually if you are a super user in the system ) you should go with
L<standard installation|"STANDARD INSTALLATION">. Otherwise
L<custom installation|"CUSTOM INSTALLATION"> is the way to go.

=head2 STANDARD INSTALLATION

The library is installed with just like other Perl libraries, or via CPAN interactive
shell (Perl -MCPAN -e install CGI::Session).

Installation can also be done by following below instructions:

=over 4

=item 1

After downloading the distribution, C<cd> to the distribution folder

=item 2

In your shell type the following commands in the order listed:

=over 5

=item *

Perl Makefile.PL

=item *

make

=item *

make test

If the tests show positive results, type:

=item *

make install

=back

=back

=head2 CUSTOM INSTALLATION

If you do not have access to install libraries in the system folders,
you should install the library in your own private folder, somewhere in your
home directory. For this purpose, first choose/create a folder where you
want to keep your Perl libraries. I use C<perllib/> under my home folder.
Then install the library following the below steps:

=over 4

=item 1

After downloading the distribution, C<cd> to the distribution folder

=item 2

In your shell type the following commands in the order listed:

=over 5

=item *

Perl Makefile.PL INSTALLDIRS=site INSTALLSITELIB=/home/your_folder/perllib

=item *

make

=item *

make test

If the tests show positive results, type:

=item *

make install

=back

=back

Then in your Perl programs do not forget to include the following line at
the top of your code:

    use lib "/home/your_folder/perllib";

or the following a little longer alternative works as well:

    BEGIN {
        unshift @INC, "/home/your_folder/perllib";
    }

=head1 WHAT YOU NEED TO KNOW FIRST

As of version 2.6 CGI::Session offers two distinct interfaces: 1) Object
Oriented and 2) tied hash access. In Object Oriented Interface you will
first create an object of CGI::Session's derived class (driver) and
manipulate session data by calling special methods. Example:

    # Creating a new session object:
    $session = new CGI::Session::File(undef,
                        { Directory=>"/tmp" });

    print "Your session id is ", $session->id();


In tied hash method, you will tie() a regular hash variable to the
CGI::Session's derived class and from that point on you will be
treating a session just hash variable. And Perl will do all
other job for you transparently:

    # Creating a new session object:
    tie %session, "CGI::Session::File", undef, {
                        { Directory=>"/tmp" };

    print "Your session id is ", $session{_session_id};

In the examples throughout the manual I will give syntax and notes
for both interfaces. Which interface to use is totally up to you.
I personally prefer Object Oriented Interface, for it is full of
features.

Also, somewhere in this manual I will talk about L<"SPECIAL NAMES"> which 
are not accessible via C<param()> method for neither writing nor reading. 
But this rule differ in tied hash access method, where all those
L<"SPECIAL NAMES"> but few are writable

=head1 REFRESHER ON SESSION MANAGEMENT

Since HTTP is a stateless protocol, web programs need a way of recognizing
clients across different HTTP requests. Each click to a site by the
same user is considered brand new request for your web applications, and
all the state information from the previous requests are lost. These
constraints make it difficult to write web applications such as shopping
carts, users' browsing history, login/authentication routines, users'
preferences among hundreds of others.

But all of these constraints can be overcome by making use of CGI::Session

=head1 WORKING WITH SESSIONS

Note: Before working with sessions, you will need to decide what kind of storage
best suits your needs. If your application makes extensive use of MySQL,
Oracle or other RDBMS, go with  that storage. But plain file or DB_File
should be adequate for almost all the situations. Examples in this manual
will be using plain files as the session storage device for they are available
for all the users. But you can choose any CGI::Session::* driver available.

=head2 CREATING A NEW SESSION

To create a new session, you will pass CGI::Session::File a false
expression as the first argument:

    # OO interface
    $session = new CGI::Session::File(undef,
        {            
            Directory    => "/tmp/sessions",
    });


    # tie() interface
    tie %session, "CGI::Session::File", undef, {            
            Directory    => "/tmp/sessions"  };

We're passing two arguments, the fist one is session id, which is undefined
in our case, and the second one is the anonymous hash

    {       
        Directory    => "/tmp/sessions",
    }

which points to the locations where session files and their lock files
should be created. You might want to choose a more secure location than
I did in this example.

Note: second hashref argument is dependant on the driver. Please check
with the driver manual.

If the session id is undefined, the library will generate a new id,
and you can access it's value via id() method: (see L<methods|"METHODS">)

    # OO:
    $sid = $session->id();


    # tie():
    $sid = $session{_session_id};

=head2 INITIALIZING EXISTING SESSIONS

We create new sessions when new visitors visit our site. What if they
click on a link in our site, should we create another session again?
Absolutely not! The sole purpose of the session management is to keep
the session open as along as the user is surfing our site. Sometimes
we might want to choose to keep the session for several days, weeks or months
so that we can recognize the user and/or re-create his preferences if
required.

So how do we know if the user already opened a session or not? At their first
visit, we should "mark" the users with the session id we created in the
above example. So, how do we "mark" the user? There are several ways of
"marking".

=head3 IDENTIFYING THE USER VIA CGI QUERY

One way of doing it is to append the session id to every single link in the
web site:

    # get the session id...
    my $sid = $session->id();

    # printing the link
    print qq<a href="$ENV{SCRIPT_NAME}?sid=$sid">click here</a>~;

When the user clicks on the link, we just check the value of C<sid>
CGI parameter. And if it exists, we consider it as an existing session id
and pass it to the C<CGI::Session>'s constructor:

    use CGI::Session::File;
    use CGI;

    my $cgi = new CGI;
    my $sid = $cgi->param("sid") || undef;
    my $session = new CGI::Session::File($sid,
        {
            Directory    => "/tmp/sessions"
        });

If the C<sid> CGI parameter is present, the C<CGI::Session> will try to
initialize the object with previously created session data. If
C<sid> parameter is not present in the URL, it will default to undef,
forcing the C<CGI::Session> to create a new session just like in our first
example. Also, when the user is asked to submit a form, we should include
the session id in the HIDDEN field of the form, so that it will be sent
to the application and will be available via $cgi->param("sid") syntax: (see L<methods|"METHODS"> )

    # get the session id...
    my $sid = $session->id();

    # print the hidden field
    print qq~<input type="hidden" name="sid" value="$sid">~;

This session management technique stays good as long as the user is
browsing our site. What if the user clicks on an external link, or visits
some other site before checking out his shopping cart? Then when he
comes back to our site within next 5 minutes or so, he will be surprised to
find out that his shopping cart is gone! Because when they visit the site next
time by typing the URL, C<sid> parameter will not be present in the URL,
and our application will not recognize the user resulting in the creation of
a new session id, and all the links in the web site will have that new
session id appended to them. Too bad, because the client has to start
everything over again.

=head3 INDENTIFYING THE USER VIA COOKIES

We can deal with the above problem by sending the client a cookie. This cookie
will hold the session id only! Thus if the client visits some other site, or
even closes the browser accidentally, we can still keep his session
open till the next time he/she visits the site. While the implementation
is  concerned, it will not the different then the one above, with some
minor changes:

    use constant SESSION_COOKIE => "MY_SITE_SID";

    use CGI::Session::File;
    use CGI;

    my $cgi = new CGI;
    my $sid = $cgi->cookie(SESSION_COOKIE) || undef;
    my $session = new CGI::Session::File($sid,
        {            
            Directory    => "/tmp/sessions"
        });

    # now, do not forget to send the cookie back to the client:
    {
        my $cookie = $cgi->param(-name   => SESSION_COOKIE,
                                 -value  => $session->id,
                                 -expires=> "+1M");
        print $cgi->header(-cookie=>$cookie);
    }


I can hear critics saying "what if the user disabled cookies? The above
technique will fail!". Surprisingly, they are absolutely right. If the
client disabled cookies in his/her browser (which is less likely) the above
technique of ours is even worse than the previous one. It will not work
AT ALL. So we should combine both of the techniques together. This will
require the change only in one line from the above code:

    my $sid = $cgi->cookie(SESSION_COOKIE) || $cgi->param("sid") || undef;

and the reset of the code stays the same. As you see, it will first try to
get the session id from the cookie, if it does not exist, it will look for
the C<sid> parameter in the URL, and if that fails, then it will default to
undef, which will force C<CGI::Session> to create a new id for the client.

=head3 IDENTIFYING THE USER VIA PATH_INFO

The least common, but at the same time quite convenient way of C<marking> users
with a session id is appending the session id to the url of the script
as a C<PATH_INFO>. C<PATH_INFO> is somewhat similar to C<QUERY_STRING>,
but unlike C<QUERY_STRING> it does not come after the question mark (C<?>),
but it comes before it, and is separated from the script url with a slash
(C</>) just like a folder. Suppose our script resides in /cgi-bin/session.cgi.
And after we append session id to the url as a C<PATH_INFO> if will look
something like:

    /cgi-bin/session.cgi/KUQa0zT1rY-X9knH1waQug

and the query string would follow C<PATH_INFO>:

    /cgi-bin/session.cgi/KUQa0zT1rY-X9knH1waQug?_cmd=logout

You can see examples of this in the L<examples|"EXAMPLES"> section
of the manual.

And when it comes to initializing the session id from the C<PATH_INFO>,
consider the following code:

    my ($sid) = $cgi->path_info =~ /\/([^\?\/]+)/;

    my $session = new CGI::Session::File($sid, {
                                        Directory    => "/tmp"});


L<CGI.pm|CGI>'s C<path_info()> method returns the PATH_INFO environmental
variable with a leading slash (C</>). And we are using regex to get rid of
the leading slash and retrieve the session id only. The rest of the code
is identical to the previous examples.

=head2 ERROR HANDLING

C<CGI::Session> itself never die()s (at least tries not to die), neither
should its drivers. But the methods' return value indicates the
success/failure of the call, and C<$CGI::Session::errstr> global variable
will be set to an error message in case something goes wrong. So you should
always check the return value of the methods to see if they succeeded:

    my $session = new CGI::Session::File($sid,
        {            
            Directory    => "/tmp/sessions"
        }) or die $CGI::Session::errstr;

=head2 STORING DATA IN THE SESSION

=over 4

=item 1

After you create a session id or initialize existing one you can now save
data in the session using C<param()> method: (see L<methods|"METHODS">)
	
    $session->param('email', 'sherzodr@cpan.org');

This will save the email address sherzodr@cpan.org in the C<email> session
parameter. A little different syntax that also allows you to do this is:

    $session->param(-name=>'email', -value=>'sherzodr@cpan.org');

	# tie() interface
	$session{email} = 'sherzodr@cpan.org';

=item 2

If you want to store more values  in the same session parameter, you can
pass a reference to an array or a hash. This is the most frequently
exercised technique in shopping cart applications, or for storing users'
browsing history. Here is the example where we store the user's
shopping cart as a reference to a hash-table, keys holding the item name,
and their values indicating the number of items in the cart.
( I would go with item id rather than item names, but we choose
item names here to make the things clearer for the reader):

    # OO Interface
	$session->param(-name=>'cart', -value=>{
                                    "She Bang Hat"    => 1,
                                    "The Came T-shirt"=> 1,
                                    "Perl Mug"        => 2
                                   });

	# tie() Interface
	$session{cart} = {	"She Bang Hat"		=> 1,
                         "The Came T-shirt"	=> 1,
                         "Perl Mug"			=> 2 };
								
the same assignment could be performed in the following two steps as well:

    my $cart = {
        "She Bang Hat"    => 1,
        "The Came T-shirt"=> 1,
        "Perl Mug"        => 2
    };

	# OO Interface
    $session->param(-name=>'cart', -value=>$cart);

	# tie() Interface
	$session{cart} = $cart;

=item 3

Sometimes, you want to store the contents of a form the user submitted,
or want to copy the contents of the CGI query into the session object
to be able to restore them later. For that purpose C<CGI::Session>
provides with C<save_param()> method which does just that.

Suppose, a user filled in lots of fields in an advanced search form in your
web site. After he submits the form, you might want to save the generated CGI
query (either via GET or POST method) into the session object, so that
you can keep the forms filled in with the previously submitted data throughout
his session. Here is the portion of the code after the user submits the
form:

    # if the user submitted the form..
    if ( $cgi->param("_cmd") eq "search") {
        # save the generated CGI query in the session:
        $session->save_param($cgi);
    }


	# tie() Interface: n/a

It means, if the search form had a text field with the name "keyword":

    <input type="textfield" name="keyword" />

after calling L<save_param($cgi)|"METHODS">, the value of the text field will be
available via L<$session->param("keyword")|"METHODS">, and you can re-write the above
text field like the following:

    my $keyword = $session->param("keyword");
    print qq~<INPUT TYPE="textfield" name="keyword" value="$keyword" />~;

=item 4

Sometimes you don't want to save all the CGI parameters, but want
to pick from the list. L<save_param()|"METHODS"> method optionally accepts an arrayref
as the second argument telling it which L<CGI> parameters it should save
in the session:

    $session->save_param($cgi, [ "keyword", "order_by",
                                 "order_type", "category" ]);

Now only the above listed parameters will be saved in the session for future
access. Inverse of the L<save_param()|"METHODS"> is L<load_param()|"METHODS">.

=back

=head3 SPECIAL NAMES

When you create a fresh-blank session, it's not blank as it seems. It is
initialized with the following 4 parameters, which are serialized together
with other session data. We call these L<"SPECIAL NAMES">.

=over 4

=item *

C<_session_id> - stores the ID of the session

=item *

C<_session_ctime> - stores the creation date of the session

=item *

C<_session_atime> - stores the last access time for the session

=item *

C<_session_etime> -  stores expiration date for the session

=back

So you shouldn't be using parameter names with leading underscore, because
C<CGI::Session> preserves them for internal use. They are required for the
library to function properly. Even though you try to do something like:

    $session->param(-name=>"_some_param", -value=>"Some value");

C<param()> returns C<undef>, indicating the failure and assigns the
error message in the C<$CGI::Session::errstr>, which reads:

    Names with leading underscore are preserved for internal use by CGI::Session.
    _some_param - illegal name

You cannot access these L<"SPECIAL NAMES"> directly via C<param()> either, but
you can do so by provided accessory methods, C<id()>, C<ctime()>, C<atime()> and
C<expires()> (see L<methods|"METHODS">).

If you are using tied hash access interface, these rules differ slightly, 
where you can read all these name from the hash, but you can set only
_session_etime and _session_atime names:

	printf ("Session last accessed on %s\n", localtime($session{_session_atime}));

	# updating last access time. You don't have to do it, it will be done 
	# automatically though
	$session{_session_atime} = time();


	# setting expiration date, setting in 2 months
	$session{_session_etime} = "2M";

=head2 ACCESSING SESSION DATA

=over 4

=item 1

Now the client has to check the items out of his/her shopping cart, and
we need to access our session parameters.

The same method used for storing the data, L<param()|"METHODS">, can be used to
access them:

    my $login = $session->param("login");

This example will get the user's login name from the previously stored
session. This could be achieved with a slightly different syntax that
C<param()> supports:

    my $login = $session->param(-name=>"login");

Which syntax to use is up to you! Now let's dump the user's shopping cart
that was created earlier:

    # remember, it was a hashref?
    my $cart = $session->param(-name=>"cart");

    while ( my ($name, $qty) = each %{$cart} ) {
        print "Item: $name ($qty)", "<br />";
    }

=item 2

Another commonly usable way of accessing the session data is via
C<load_param()> method, which is the inverse of L<save_param()|"METHODS">. This loads
the parameters saved in the session object into the CGI object. It's very
helpful when you want L<CGI> object to have access to those parameters:

    $session->load_param($cgi);

After the above line, CGI has access to all the session parameters. We talked
about filling out the search form with the data user previously entered.
But how can we present the user pre-checked group of radio buttons according
to his/her previous selection? How about checkboxes or popup menus? This
is quite challenging unless we call CGI library for help, which provides
a sticky behavior for most of the form elements generated with L<CGI.pm|CGI>


    # load the session parameters into the CGI object first:
    $session->load_param($cgi, ["checked_items"]);

    # now print the group of radio buttons,it CGI.pm will check them
    # according to the previously saved session data
    print $cgi->group_radio(-name=>"checked_items",
                            -values => ["eenie", "meenie", "minie", "moe"]);

Notice the second argument passed to the L<load_param()|"METHODS">. In this case
it is loading only the "checked_items" parameter from the session. If it
were missing it would load the whole session data.

=back

=head2 CLEARING THE SESSION DATA

When the user click on the "clear the cart" button or purchases the contents
of the shopping cart, that's a clue that we have to clear the cart.
C<CGI::Session>'s L<clear()|"METHODS"> method deals with clearing the session data:

	# OO Interface
    $session->clear("cart");
    
	# tie() Interface
	delete $session{cart};

What happens is, it deletes the given parameter from the session for good.
If you do not pass any arguments to C<clear()>, then all the parameters
of the session will be deleted. Remember that C<clear()> method DOES NOT
delete the session. Session stays open, only the contents of the session
data will be deleted.

=head2 DELETING THE SESSOIN

If you want to delete the session for good together with all of its contents,
then L<delete()|"METHODS"> method is the way to go. After you call this method,
the C<CGI::Session> will not have access to the pervious session at all,
because it was deleted from the disk for good. So it will have to generate
a new session id instead:

	# OO Interface
	$session->delete();

	# tie() Interface:
	tied(%session)->delete();
	

=head2 CLEAR OR DELETE?

So, should we L<delete()|"METHODS"> the session when the user finishes browsing the site
or clicks on the "sign out" link? Or should we C<clear()> it? And I'll answer
the question with another question; bright mind should be able to see me through!
If the user click on the "sign out" link, does it mean he is done browsing
the site? Absolutely not. The user might keep surfing the site even after
he signs out or clears his shopping cart. He might even continue his shopping
after several hours, or several days. So for the comfort of the visitors
of our site, we still should keep their session data at their fingertips,
and only C<clear()> unwanted session parameters, for example, the user's
shopping cart, after he checks out. Sessions should be deleted if
they haven't been accessed for a certain period of time, in which case
we don't want unused session data occupying the storage in our disk.

=head2 EXPIRING SESSIONS

While I was coding this feature of the C<CGI::Session>, I wasn't quite sure
how to implement auto-expiring sessions in more friendly way. So I decided
to leave to the programmer implementing C<CGI::Session> and introduced
3 brand new methods to the library, L<expires()|"METHODS">,
L<atime()|"METHODS"> and L<ctime()|"METHODS">;

L<ctime()|"METHODS"> method returns the C<time()> value when the session was created
for the first time. L<atime()"METHODS"> method returns the C<time()> value when then
session data was accessed for the last time. If we use C<expires()> without
any arguments, it returns the L<time()|perlfunc/time> value of the date when the session
should expire. Returns undef if it's non-expiring session. If you use
it with an argument, then it will set the expiration date for the session.
For the list of possible arguments L<expires()|"METHODS"> expects, please check out the
L<"METHODS"> section below.

Remember, even though you set an expiration date, C<CGI::Session 2.0> itself
doesn't deal with expiring sessions, the above 3 method just provide you
with all the required tools to implement your expiring sessions. I will
put some more effort on this issue in the next releases of the library. But
if you have any bright ideas or patches, scroll down to the L</AUTHOR>
section and get in touch.

The following script is best suited for a cron job, and will be deleting the
sessions that haven't accessed for the last one year.

    use constant YEAR => 86400 * 365; # in seconds

    use CGI::Session::File;
    use IO::Dir;

    tie my %dir, "IO::Dir", "/tmp/sessions", DIR_UNLINK or die $!;

    my $session;
    my $options = {Directory=>"/tmp/sessions"};

    while ( my ($file, $info) = each %db ) {

        my ($sid) = $file =~ m/CGI-Session-([^\.]+)\.dat) or next;
        $session = CGI::Session::File->new($sid, $options);

        if ( (time - $session->atime) > YEAR ) {

            $session->delete();

        }
    }

    untie %dir;


=head1 EXAMPLES

=head2 SESSION PREFERENCES

This example will show how to remember users' preference/choices for the
duration of their session while they are browsing the site.

=over 4

=item URL: http://modules.ultracgis.com/cgi-bin/session

=item DESCRIPTION

This example is L<marking|"INITIALIZING EXISTING SESSIONS"> the user both with
a cookie and with a C<PATH_INFO> appended to every url. Thus even though the
application is at /cgi-bin/session, the url looks something like
/cgi-bin/session/KUQa0zT1rY-X9knH1waQug?_cmd=profile, which tricks untrained
eyes into thinking that C</cgi-bin/session> is a folder, and the script has
a quite long and unpleasant name. But C<CGI::Session> users should easily
be able to guess that we're just appending a path to the url.

=back

=head1 METHODS

=over 4

=item new()

constructor method. Requires two arguments, first one is the session id
the object has to initialize, and the second one is the hashref to driver
specific options. If session is evaluates to C<undef>, the CGI::Session
will generate a new session id stores it automatically. If defined session id
is passed, but the library fails to initializes the object with that
session, then new session will be created instead. If an error occurs either
in storing the session in the disk, or retrieving the session from the disk,
C<new()> returns undef, and sets the error message in the
C<$CGI::Session::errstr> global variable. Example:

    use CGI::Session::DB_File;
    my $session = new CGI::Session::DB_File(undef,
        {
            LockDirectory=>'/tmp',
            FileName        => '/tmp/sessions.db'
    }) or die "Session couldn't be initialized: $CGI::Session::errstr";

=item id()

returns the session id for the current session.

=item error()

returns the error message. Works only after the session object
was initialized successfully. Other times, please use
C<$CGI::Session::errstr> variable to access the error message

=item param()

the most important method of the library. It is used for accessing the
session parameters, and setting their values. It supports several syntax,
all of which are discussed here.

=over 6

=item *

C<param()> - if passed no arguments, returns the list of all the existing
session parameters

=item *

C<param("first_name")> returns the session value for the C<first_name>
parameter.

=item *

C<param(-name=E<gt>"first_name")> - the same as C<param("first_name")>,
returns the value of C<first_name> parameter

=item *

C<param("first_name", "Sherzod")> - assigns C<Sherzod> to the C<first_name>
session parameter. Later you can retrieve the C<first_name> with either
C<param("first_name")> or C<param(-name=E<gt>"first_name")> syntax. Second
argument can be either a string, or it can be reference to a more complex
data structure like arrayref, hashref, or even a file handle. Example,

    $session->param("shopping_cart_items", [1, 3, 66, 2, 43]);

later, if you wish to retrieve the above arrayref form the
C<shopping_cart_items> parameter:

    my $cart = $session->param("shopping_cart_items");

now $cart holds C<[1, 3, 66, 2, 43]>.

=item *

C<param(-name=E<gt>"first_name", -value=E<gt>"Sherzod")> - the same as
C<param("first_name", "Sherzod")>, assigns C<Sherzod> to C<first_name>
parameter.

=back

=item save_param()

Saves the CGI object parameters into the session object. It's very helpful
if you want to save the user's form entries, like email address and/or
username in the session, for later use. The first argument has to be a
CGI.pm object as returned from the C<CGI-E<gt>new()> method, and the second
argument (optional) is expected to be a reference to an array holding the
names of CGI parameters that need to be saved in the session object. If the
second argument is missing, it will save all the existing CGI parameters,
skipping the ones that start with an underscore (_). Example,

    $session->save_param($cgi, ["login_name", "email_address"]);

Now, if the user submitted the text field with his "login_name", his login
is saved in our session already. Unlike CGI parameters, Session parameters
do not disappear, they will be saved in the disk for a lot longer period
unless you choose to delete them. So when the user is asked to login after
several weeks, we just fill the login_name text field with the values of the
field submitted when the user visited us previously. Example:

    # let's get his login_name which was saved via save_param() method:
    my $login_name = $session->param("login_name");

    # now let's present the text field with login_name already typed in:
    print $cgi->textfield(-name=>"login_name", -value=>$login_name);


=item load_param()

This is the opposite of the above C<save_param()> method. It loads the
previously saved session parameters into the CGI object. The first argument
to the method has to be a CGI.pm object returned from CGI->new() method.
The second argument, if exists, is expected to be a reference to an array
holding the names of the parameters that need to be loaded to the CGI object.
If the second argument is missing, it will load all the session parameters
into the CGI object, skipping the ones that start with an underscore (_).
If we're using CGI.pm to produce our HTML forms, the above example  could
also be written like the following:

    $session->load_param($cgi);
    print $cgi->textfield(-name=>"login_name");

This method is quite handy when you have checkboxes or multiple section
boxes which assign array of values for a single element. To keep those
selection the way your visitor chooses throughout his/her session is
quite challenging  task. But CGI.pm's "sticky" behavior comes quite handy here.

All you need to do is to load the parameters from the session to your CGI
object, then CGI.pm automatically restores the previous selection of checkboxes:

	# load it from the disk to the CGI.pm object
	$session->load_param($cgi, "lists");

	# now we can just print the checkbox, and previously saved checks
	# would remain selected:
	print $cgi->checkbox_group(-name=>"lists", -values=>["CGI-Perl", "Perl5-Porters", "CGI-Session"]);


Note: C<load_param()> and C<save_param()> methods didn't work on parameters that 
return multiple values. This problem was fixed in version 2.6 of the library.

=item clear()

this method clears the session data. Do not confuse it with C<delete()>,
which deletes the session data together with the session_id. C<clear()> only
deletes the data stored in the session, but keeps the session open. If you
want to clear/delete certain parameters from the session, you just pass an
arrayref to the method. For example, here is the revised copy of the code I
used in one of my applications that clear the contents of the user's
shopping cart when he/she click on the 'clear the cart' link:

    $session->clear(["SHOPPING_CART"]);

	# tie() Interface
	delete $session{"SHOPPING_CART"};
	

I could as well use C<clear()> with no arguments, in which case it would
delete all the data from the session, not only the SHOPPING_CART:

	# OO Interface
	$session->clear();

	# tie() Interface
	%session = ();

=item expires()

When a session is created, it's expiration date is undefined, which means,
it never expires. If you want to set an expiration date to a session,
C<expires()> method can be used. If it's called without arguments, will
return the time() value of the expiration date, which is the number of
seconds since the epoch. If you pass an argument, it will consider it either
as a number of seconds, or a special shortcut for date values. For example:

    # will it ever expire?
    unless ( $session->expires ) {
        print "Your session will never expired\n";
    }


    # how many seconds left?
    my $expires_in = $session->expires() - time();
    print "Your session will expire in $expires_in seconds\n";

    # when exactly will it expire?
    my $date = scalar(localtime( $session->expires ));
    print "Your session will expire on $date\n";

    # let the session expire in 60 seconds...
    $session->expires(60);

    # the same
    $session->expires("60s");

    # expires in 30 minutes
    $session->expires("30m");

    #expires in 1 month
    $session->expires("1M");


For tie() interface you will need to update one of the L<"SPECIAL NAMES">
C<_session_etime>:

	$session{_session_etime} = "2d";

	printf("Your session will expires in %d seconds\n", 
		$session{_session_etime} - time);

Here is the table of the shortcuts available for C<expires()>:

    +===========+===============+
    | shortcut  |   meaning     |
    +===========+===============+
    |     s     |   Second      |
    |     m     |   Minute      |
    |     h     |   Hour        |
    |     w     |   Week        |
    |     M     |   Month       |
    |     y     |   Year        |
    +-----------+---------------+


see L<expiring sessions|"EXPIRING SESSIONS"> for more on this.


=item ctime()

Returns the time() value of the date when the session was created:

    # OO Interface
	printf("Session was created on %s\n", localtime($session->ctime));

	# tie() Interface
	printf("Session was created on %s\n", localtime($session{_session_ctime});

=item atime()

Returns the time() value of the date when the session was last accessed:

	# OO Interface
    printf("Session was last accessed on %s\n", localtime($session->atime));
    printf("Session was last accessed %d seconds ago\n", time() - $session->atime);

	# tie() Interface
	printf("Session was last accessed on %s\n", localtime($session{_session_atime}));
    printf("Session was last accessed %d seconds ago\n", time() - $session{_session_atime});

=item delete()

deletes the session data from the disk permantly:

	# OO Interface
	$session->delete();

	# tie() Interface
	tied(%session)->delete();

=back

=head1 DEVELOPER SECTION

If you noticed, C<CGI::Session> has never been accessed directly, but we
did so using its available drivers. As of version 2.0 C<CGI:Session> comes
with drivers for File, DB_File and MySQL databases. If you want to write
your own driver for different storage type ( for example, Oracle, Sybase,
Postgres so forth) or if you want to implement your own driver, this section
is for you. Read on!

=head2 HOW IS THE LIBRARY DESIGNED?

C<CGI::Session> itself doesn't deal with such things as storing the data
in the disk (or other device), retrieving the data or deleting it from the
persistent storage. These are the issues specific to the storage type
you want to use and that's what the driver is for. So driver is just another
Perl library, which uses C<CGI::Session> as a base class, and provides three
additional methods, C<store()>, C<retrieve()> and C<tear_down()>. As long
as you provide these three methods, C<CGI::Session> will handle all the
other part.

=head2 WHAT ARE THE SPECS?

=over 4

=item *

C<store()> will receive four arguments, C<$self>, which is the object itself,
C<$sid>, which is the session id, C<$hashref>, which is the session data as
the reference to an antonymous hash, and <$options>, which is another hash
reference that was passed as the second argument to C<new()>. C<store()>'s
task is to store the hashref (which is the session data)in the disk in such
a way so that it could be retrieved later. It should return true on success,
undef otherwise, passing the error message to C<$self-E<gt>error()> method.


=item *

C<retrieve()> will receive three arguments, C<$self>, which is the object
itself, C<$sid>, which is the session id and C<$options>, which is the
hash references passed  to C<new()> as the first argument. C<retrieve()>'s
task is to access the data which was saved previously by the C<store()>
method, and re-create the same C<$hashref> as C<store()> once received, and
return it. Method should return the data on success, undef otherwise,
passing the error message to C<$self-E<gt>error()> method.


=item *

C<tear_down()> is called when C<delete()> is called. So its task is to
delete the session data and all of its traces from the disk. C<tear_down()>
will receive three arguments, C<$self>, which is the object itself, C<$sid>,
which is the session id and C<$options>, which is the hash reference passed
to C<new()> as the second argument. The method should return true on
success, undef otherwise, passing the error message to C<$self-E<gt>error()>.

=back

If you open the B<dev/> folder in the C<CGI::Session> distribution, you will
find a blueprint for the driver, B<MyDriver.pm>, which looks something like
this:

    package CGI::Session::MyDriver;

    use strict;
    use vars qw($VERSION);
    use base qw(CGI::Session CGI::Session::MD5);

    # all other driver specific libraries go below


    sub store {
        my ($self, $sid, $hashref, $options) = @_;


        return 1;
    }


    sub retrieve {
        my ($self, $sid, $options) = @_;

        return {};
    }


    sub tear_down {
        my ($self, $sid, $option) = @_;


        return 1;
    }

It is inheriting from two classes, C<CGI::Session> and C<CGI::Session::MD5>.
The second library just provides C<generate_id()> method that returns a
sting which will be used as a session id. Default C<generate_id()> uses
Digest::MD5 library to generate a unique identifier for the session.
If you want to implement your own C<generate_id()> method, you can override
it by including one in your module as the fourth method.

=over 4

=item *

C<generate_id()> receives only one argument, C<$self>, which is the object
itself. The method is expected to return a string to be used as the session
id for new sessions.

=back

The challenging part might seem to store the C<$hashref> and to be able
to restore it back. But there are already libraries that you can make use of
to do this job very easily. Drivers that come with C<CGI::Session> depend on
L<Data::Dumper||Data::Dumper>, but you can as well go with L<Storable> or L<FreezeThaw>
libraries which allow you to C<freeze()> the Perl data and C<thaw()> it later,
thus you will be able to re-create the the C<$hashref>. The reason we
preferred L<Data::Dumper|Data::Dumper> is, it comes standard with Perl.

=head2 LOCKING

Writing and reading from the disk requires a locking mechanism to prevent
corrupted data. Since CGI::Session itself does not deal with disk access,
it's the drivers' task to implement their own locking. For more information
please refer to the driver manuals distributed with the L<package|"DISTRIBUTION">.

=head2 OTHER NOTES

Don't forget to include an empty DESTROY() method in your library for
CGI::Session's AUTOLOAD would be looking for it thus wasting its precious time.

=head1 TODO

I still have lots of features in mind that I want to add and/or fix. Here is
a short list for now. Feel free to email me your fantasies and patches.

=over 4

=item 1

Fix C<expires()> and implement expiring sessions in more friendly way

=item 2

Implement more sophisticated locking mechanism for session data

=item 3

Customizable session id generator

=item 4

Combining passive client identification methods

=back

=head1 FREQUANTLY ASKED QUESTIONS

The following section of the library lists answers to some frequently asked
questions:

=over 4

=item Q: Can I use CGI::Session in my shell scripts, or is it just for CGI Applications?

=item A: Yes, you can!

CGI::Session does not depend on the presence of the Web Server, so you can
use it on all kinds of applications, crons, shell scripts, you name it

=back

=over 4

=item Q: What if the user ask for the session which was deleted from the disk?

=item A: New session will be initialized!

Previous version of CGI::Session had a bug, and returned no id for the session
if the session didn't exist in the disk. But latest version of the library
should create a new session if the session data cannot be initialized!

=item Q: Is it safe to store sensitive information in the session?

=item A: Yes, it is safe, but read on

If you noticed in the manual, we were sending on the session id to the client
either in the form of cookie or a URL parameter. And all other session data
is stored in the server side. So if you want to store sensitive information
in your session, I advise you to pick a very safe location for your C<Directory>
so that no one will be able to access session files to find out the users' passwords,
etc.

But there are alternative ways of user authentication, which I will try to
cover in my C<cgiauth||CGI::Session::auth> tutorial soon

=item Q:  Where can I get detailed information on managing user sessions
in web applications?

=item A: I myself did a lot of research on this, and the only article
on session management in CGI/Perl was the CGI::Session manual
at http://modules.ultracgis.com/CGI/Session.html (same as the current
manual). You can also check out L<Apache::Session>

=back

=head1 SUPPORT

I might not be able to answer all of your questions regarding C<CGI::Session>,
so please subscribe to CGI::Session mailing list. Visit
http://ultracgis.com/mailman/listinfo/cgi-session_ultracgis.com to subscribe.

For commercial support and/or custom programming, contact UltraCgis team
( send email to support@ultracgis.com )

=head1 HISTORY

Initial release of the library was just a front-end to Jeffrey Baker
<jwbaker@acm.org>'s Apache::Session and provided L<CGI.pm|CGI>-like syntax for
Apache::Session hashes. But as of version 2.0, the class is independent of
third party libraries and comes with L<File|CGI::Session::File>,
L<DB_File|CGI::Session::DB_File> and L<MySQL|CGI::Session::MySQL> drivers.
It also allows developers to L<write|"DEVELOPER SECTION"> their own drivers
for other storage mechanisms very easily.

Since CGI::Session used to depend on L<Apache::Session>, the session data used
to be serialized using L<Storable>. Now it relies on standard L<Data::Dumper|Data::Dumper>
module to "freeze" and "thaw" the data.

=head1 CREDITS

=over 4

=item Andy Lester <alester@flr.follett.com>

Thanks for his patience for helping me to fix the bug in L<CGI::Session::File|CGI::Session::File>,
which kept failing in Solaris.

=item Brian King <mrbbking@mac.com>

Helped to fix the B<t/mysql.t> test suite that was failing on MacOS X

=back


=head1 BUGS

Currently the only know bug is in the C<load_param()> and C<save_param()>
methods. They cannot deal with the parameters that return other than strings
( for example, arrays ).







=head1 AUTHOR

Sherzod B. Ruzmetov <sherzodr@cpan.org>

=head1 SEE ALSO

L<CGI::Session::File>, L<CGI::Session::DB_File>, L<CGI::Session::MySQL>
L<Apache::Session>, L<Data::Dumper>, L<Digest::MD5>, L<FreezeThaw>,
L<Storable>, L<CGI>

=cut
