package CGI::Session;

# $Id: Session.pm,v 3.2.2.1 2002/11/28 03:16:50 sherzodr Exp $

#use strict;
#use diagnostics;
use Carp ('confess');
use AutoLoader 'AUTOLOAD';

use vars qw($VERSION $errstr $IP_MATCH $NAME $API_3);

($VERSION)  = '$Revision: 3.2.2.1 $' =~ m/Revision:\s*(\S+)/;
$NAME     = 'CGISESSID';

# import() - we do not import anything into the callers namespace, however,
# we enable the user to specify hooks at compile time
sub import {
    my $class = shift;
    @_ or return;
    for ( my $i=0; $i < @_; $i++ ) {
        $IP_MATCH   = ( $_[$i] eq '-ip_match'   ) and next;
        $API_3      = ( $_[$i] eq '-api3'       ) and next;
    }
}


# Session _STATUS flags
sub SYNCED   () { 0 }
sub MODIFIED () { 1 }
sub DELETED  () { 2 }


# new() - constructor.
# Returns respective driver object
sub new {
    my $class = shift;
    $class = ref($class) || $class;

    my $self = {
        _OPTIONS    => [ @_ ],
        _DATA       => undef,
        _STATUS     => MODIFIED,
        _API3       => { },
    };

    if ( $API_3 ) {
        return $class->api_3(@_);
    }

    bless ($self, $class);
    $self->_validate_driver() && $self->_init() or return;
    return $self;
}










sub api_3 {
    my $class = shift;
    $class = ref($class) || $class;


    my $self = {
        _OPTIONS    => [ $_[1], $_[2] ], # for now settle for empty option
        _DATA       => undef,
        _STATUS     => MODIFIED,
        _API_3      => {
            DRIVER      => 'File',
            SERIALIZER  => 'Default',
            ID          => 'MD5',
        }
    };

    if ( defined $_[0] ) {
        my @arg_pairs = split (/;/, $_[0]);
        for my $arg ( @arg_pairs ) {
            my ($key, $value) = split (/:/, $arg) or next;
            $self->{_API_3}->{ uc($key) } = $value || $self->{_API_3}->{uc($key)};
        }
    }

    my $driver = "CGI::Session::$self->{_API_3}->{DRIVER}";
    eval "require $driver" or die $@;

    my $serializer = "CGI::Session::Serialize::$self->{_API_3}->{SERIALIZER}";
    eval "require $serializer" or die $@;

    my $id = "CGI::Session::ID::$self->{_API_3}->{ID}";
    eval "require $id" or die $@;


    # Now re-defining ISA according to what we have above
    {
        no strict 'refs';
        @{$driver . "::ISA"} = ( 'CGI::Session', $serializer, $id );
    }

    bless ($self, $driver);
    $self->_validate_driver() && $self->_init() or return;
    return $self;
}



# DESTROY() - destructor.
# Flushes the memory, and calls driver's teardown()
sub DESTROY {
    my $self = shift;

    $self->flush();
    $self->can('teardown') && $self->teardown();
}



# _validate_driver() - checks driver's validity.
# Return value doesn't matter. If the driver doesn't seem
# to be valid, it croaks
sub _validate_driver {
    my $self = shift;

    my @required = qw(store retrieve remove generate_id);

    for my $method ( @required ) {
        unless ( $self->can($method) ) {
            my $class = ref($self);
            confess "$class doesn't seem to be a valid CGI::Session driver. " .
                "At least one method('$method') is missing";
        }
    }
    return 1;
}




# _init() - object initialializer.
# Decides between _init_old_session() and _init_new_session()
sub _init {
    my $self = shift;

    my $claimed_id = undef;
    my $arg = $self->{_OPTIONS}->[0];
    if ( defined ($arg) && ref($arg) ) {
        if ( $arg->isa('CGI') ) {
            $claimed_id = $arg->cookie($NAME) || $arg->param($NAME) || undef;
            $self->{_SESSION_OBJ} = $arg;
        } elsif ( ref($arg) eq 'CODE' ) {
            $claimed_id = $arg->() || undef;

        }
    } else {
        $claimed_id = $arg;
    }

    if ( defined $claimed_id ) {
        my $rv = $self->_init_old_session($claimed_id);

        unless ( $rv ) {
            return $self->_init_new_session();
        }
        return 1;
    }
    return $self->_init_new_session();
}




# _init_old_session() - tries to retieve the old session.
# If suceeds, checks if the session is expirable. If so, deletes it
# and returns undef so that _init() creates a new session.
# Otherwise, checks if there're any parameters to be expired, and
# calls clear() if any. Aftewards, updates atime of the session, and
# returns true
sub _init_old_session {
    my ($self, $claimed_id) = @_;

    my $options = $self->{_OPTIONS} || [];
    my $data = $self->retrieve($claimed_id, $options);

    # Session was initialized successfully
    if ( defined $data ) {

        $self->{_DATA} = $data;

        # Check if the IP of the initial session owner should
        # match with the current user's IP
        if ( $IP_MATCH ) {
            unless ( $self->_ip_matches() ) {
                $self->delete();
                $self->flush();
                return undef;
            }
        }

        # Check if the session's expiration ticker is up
        if ( $self->_is_expired() ) {
            $self->delete();
            $self->flush();
            return undef;
        }

        # Expring single parameters, if any
        $self->_expire_params();

        # Updating last access time for the session
        $self->{_DATA}->{_SESSION_ATIME} = time();

        # Marking the session as modified
        $self->{_STATUS} = MODIFIED;

        return 1;
    }
    return undef;
}





sub _ip_matches {
    return ( $_[0]->{_DATA}->{_SESSION_REMOTE_ADDR} eq $ENV{REMOTE_ADDR} );
}





# _is_expired() - returns true if the session is to be expired.
# Called from _init_old_session() method.
sub _is_expired {
    my $self = shift;

    unless ( $self->expire() ) {
        return undef;
    }

    return ( time() >= ($self->expire() + $self->atime() ) );
}





# _expire_params() - expires individual params. Called from within
# _init_old_session() method on a sucessfully retrieved session
sub _expire_params {
    my $self = shift;

    # Expiring
    my $exp_list = $self->{_DATA}->{_SESSION_EXPIRE_LIST} || {};
    my @trash_can = ();
    while ( my ($param, $etime) = each %{$exp_list} ) {
        if ( time() >= ($self->atime() + $etime) ) {
            push @trash_can, $param;
        }
    }

    if ( @trash_can ) {
        $self->clear(\@trash_can);
    }
}





# _init_new_session() - initializes a new session
sub _init_new_session {
    my $self = shift;

    $self->{_DATA} = {
        _SESSION_ID => $self->generate_id($self->{_OPTIONS}),
        _SESSION_CTIME => time(),
        _SESSION_ATIME => time(),
        _SESSION_ETIME => undef,
        _SESSION_REMOTE_ADDR => $ENV{REMOTE_ADDR} || undef,
        _SESSION_EXPIRE_LIST => { },
    };

    $self->{_STATUS} = MODIFIED;

    return 1;
}




# id() - accessor method. Returns effective id
# for the current session. CGI::Session deals with
# two kinds of ids; effective and claimed. Claimed id
# is the one passed to the constructor - new() as the first
# argument. It doesn't mean that id() method returns that
# particular id, since that ID might be either expired,
# or even invalid, or just data associated with that id
# might not be available for some reason. In this case,
# claimed id and effective id are not the same.
sub id {
    my $self = shift;

    return $self->{_DATA}->{_SESSION_ID};
}



# param() - accessor method. Reads and writes
# session parameters ( $self->{_DATA} ). Decides
# between _get_param() and _set_param() accordingly.
sub param {
    my $self = shift;


    unless ( defined $_[0] ) {
        return keys %{ $self->{_DATA} };
    }

    if ( @_ == 1 ) {
        return $self->_get_param(@_);
    }

    # If it has more than one arguments, let's try to figure out
    # what the caller is trying to do, since our tricks are endless ;-)
    my $arg = {
        -name   => undef,
        -value  => undef,
        @_,
    };

    if ( defined($arg->{'-name'}) && defined($arg->{'-value'}) ) {
        return $self->_set_param($arg->{'-name'}, $arg->{'-value'});

    }

    if ( defined $arg->{'-name'} ) {
        return $self->_get_param( $arg->{'-name'} );
    }

    if ( @_ == 2 ) {
        return $self->_set_param(@_);
    }

    unless ( @_ % 2 ) {
        my $n = 0;
        my %args = @_;
        while ( my ($key, $value) = each %args ) {
            $self->_set_param($key, $value) && ++$n;
        }
        return $n;
    }

    confess "param(): something smells fishy here. RTFM!";
}



# _set_param() - sets session parameter to the '_DATA' table
sub _set_param {
    my ($self, $key, $value) = @_;

    if ( $self->{_STATUS} == DELETED ) {
        return;
    }

    # session parameters starting with '_session_' are
    # private to the class
    if ( $key =~ m/^_session_/ ) {
        return undef;
    }

    $self->{_DATA}->{$key} = $value;
    $self->{_STATUS} = MODIFIED;

    return $value;
}




# _get_param() - gets a single parameter from the
# '_DATA' table
sub _get_param {
    my ($self, $key) = @_;

    if ( $self->{_STATUS} == DELETED ) {
        return;
    }

    return $self->{_DATA}->{$key};
}


# flush() - flushes the memory into the disk if necessary.
# Usually called from within DESTROY() or close()
sub flush {
    my $self = shift;

    my $status = $self->{_STATUS};

    if ( $status == MODIFIED ) {
        $self->store($self->id, $self->{_OPTIONS}, $self->{_DATA});
        $self->{_STATUS} = SYNCED;
    }

    if ( $status == DELETED ) {
        return $self->remove($self->id, $self->{_OPTIONS});
    }

    $self->{_STATUS} = SYNCED;

    return 1;
}






# Autoload methods go after =cut, and are processed by the autosplit program.

1;

__END__;


# $Id: Session.pm,v 3.2.2.1 2002/11/28 03:16:50 sherzodr Exp $

=pod

=head1 NAME

CGI-Session - persistent session in CGI applications

=head1 SYNOPSIS

    # Object initialization:
    use CGI::Session qw/-api3/;

    my $session = new CGI::Session("driver:File", undef, {Directory=>'/tmp'});

    # getting the effective session id:
    my $CGISESSID = $session->id();

    # storing data in the session
    $session->param('f_name', 'Sherzod');
    # or
    $session->param(-name=>'l_name', -value=>'Ruzmetov');

    # retrieving data
    my $f_name = $session->param('f_name');
    # or
    my $l_name = $session->param(-name=>'l_name');

    # clearing a certain session parameter
    $session->clear(["_IS_LOGGED_IN"]);

    # expire '_IS_LOGGED_IN' flag after 10 idle minutes:
    $session->expire(_IS_LOGGED_IN => '+10m')

    # expire the session itself after 1 idle hour
    $session->expire('+1h');

    # delete the session for good
    $session->delete();

=head1 DESCRIPTION

CGI-Session is a Perl5 library that provides an easy, reliable and modular
session management system across HTTP requests. Persistency is a key feature for
such applications as shopping carts, login/authentication routines, and
application that need to carry data accross HTTP requests. CGI::Session
does that and many more

=head1 TO LEARN MORE

Current manual is optimized to be used as a quick reference. To learn more both about
the logic behind session management and CGI::Session programming style, consider
the following:

=over 4

=item *

L<CGI::Session::Tutorial|CGI::Session::Tutorial> - extended CGI::Session manual. Also 
includes library architecture and driver specifications.

=item *

L<CGI::Session::CookBook|CGI::Session::CookBook> - practical solutions for real life 
problems

=item *

B<RFC 2965> - "HTTP State Management Mechanism" found at ftp://ftp.isi.edu/in-notes/rfc2965.txt

=item *

L<CGI|CGI> - standard CGI library

=item *

L<Apache::Session|Apache::Session> - another fine alternative to CGI::Session

=back

=head1 METHODS

Following is the overview of all the available methods accessible via
CGI::Session object.

=over 4

=item C<new( DSN, SID, HASHREF )>

Requires three arguments. First is the Data Source Name, second should be
the session id to be initialized or an object which provides either of 'param()'
or 'cookie()' mehods. If Data Source Name is undef, it will fall back
to default values, which are "driver:File;serializer:Default;id:MD5".

If session id is missing, it will force the library to generate a new session
id, which will be accessible through C<id()> method.

Examples:

    $session = new CGI::Session(undef, undef, {Directory=>'/tmp'});
    $session = new CGI::Session("driver:File;serializer:Storable", undef,  {Directory=>'/tmp'})
    $session = new CGI::Session("driver:MySQL;id:Incr", undef, {Handle=>$dbh});

Following data source variables are supported:

=over 4

=item *

C<driver> - CGI::Session driver. Available drivers are "File", "DB_File" and
"MySQL". Default is "File".

=item *

C<serializer> - serializer to be used to encode the data structure before saving
in the disk. Available serializers are "Storable", "FreezeThaw" and "Default".
Default is "Default", which uses standard L<Data::Dumper|Data::Dumper>

=item *

C<id> - ID generator to use when new session is to be created. Available ID generators are "MD5" and "Incr". Default is "MD5".

=back


=item C<id()>

Returns effective ID for a session. Since effective ID and claimed ID
can differ, valid session id should always be retrieved using this
method.

=item C<param($name)>

=item C<param(-name=E<gt>$name)>

this method used in either of the above syntax returns a session
parameter set to C<$name> or undef on failure.

=item C<param( $name, $value)>

=item C<param(-name=E<gt>$name, -value=E<gt>$value)>

method used in either of the above syntax assigns a new value to $name
parameter, which can later be retrieved with previously introduced
param() syntax.

You can also save several parameters at once by passing param() a hash:

	$cgi->param(%params);

=item C<param_hashref()>

returns all the session parameters as a reference to a hash


=item C<save_param($cgi)>

=item C<save_param($cgi, $arrayref)>

Saves CGI parameters to session object. In otherwords, it's calling
C<param($name, $value)> for every single CGI parameter. The first
argument should be either CGI object or any object which can provide
param() method. If second argument is present and is a reference to an array, only those CGI parameters found in the array will
be stored in the session

=item C<load_param($cgi)>

=item C<load_param($cgi, $arrayref)>

loads session parameters to CGI object. The first argument is required
to be either CGI.pm object, or any other object which can provide
param() method. If second argument is present and is a reference to an
array, only the parameters found in that array will be loaded to CGI
object.

=item C<clear()>

=item C<clear([@list])>

clears parameters from the session object. If passed an argument as an
arrayref, clears only those parameters found in the list.

=item C<flush()>

synchronizes data in the buffer with its copy in disk. Normally it will
be called for you just before the program terminates, session object
goes out of scope or close() is called.

=item C<close()>

closes the session temporarily until new() is called on the same session
next time. In other words, it's a call to flush() and DESTROY(), but
a lot slower. Normally you never have to call close().

=item C<atime()>

returns the last access time of the session in the form of seconds from
epoch. This time is used internally while auto-expiring sessions and/or session parameters.

=item C<ctime()>

returns the time when the session was first created. 

=item C<expires()>

=item C<expires($time)>

=item C<expires($param, $time)>

Sets expiration date relative to atime(). If used with no arguments, returns the expiration date if it was ever set. If no expiration was ever set, returns undef.

Second form sets an expiration time. This value is checked when previously stored session is asked to be retrieved, and if its expiration date has passed will be expunged from the disk immediately and new session is created accordingly. Passing 0 would cancel expiration date.

By using the third syntax you can also set an expiration date for a
particular session parameter, say "~logged-in". This would cause the
library call clear() on the parameter when its time is up.

All the time values should be given in the form of seconds. Following
time aliases are also supported for your convenience:

    +===========+===============+
    |   alias   |   meaning     |
    +===========+===============+
    |     s     |   Second      |
    |     m     |   Minute      |
    |     h     |   Hour        |
    |     w     |   Week        |
    |     M     |   Month       |
    |     y     |   Year        |
    +-----------+---------------+

Examples:

    $session->expires("+1y");   # expires in one year
    $session->expires(0);       # cancel expiration
    $session->expires("~logged-in", "+10m");# expires ~logged-in flag in 10 mins

Note: all the expiration times are relative to session's last access time, not to its creation time. To expire a session immediately, call C<delete()>. To expire a specific session parameter immediately, call C<clear()> on that parameter.

=item C<remote_addr()>

returns the remote address of the user who created the session for the
first time. Returns undef if variable REMOTE_ADDR wasn't present in the
environment when the session was created

=item C<delete()>

deletes the session from the disk. In other words, it calls for
immediate expiration after which the session will not be accessible

=item C<error()>

returns the last error message from the library. It's the same as the
value of $CGI::Session::errstr. Example:	

    $session->flush() or die $session->error();

=item C<dump()>

=item C<dump("logs/dump.txt")>

creates a dump of the session object. Argument, if passed, will be
interpreted as the name of the file object should be dumped in. Used
mostly for debugging.

=back

=head1 DISTRIBUTION

CGI::Session consists of several modular components such as L<drivers|"DRIVERS">, L<serializers|"SERIALIZERS"> and L<id generators|"ID Generators">. This section lists what is available. 

=head2 DRIVERS

Following drivers are included in the standard distribution:

=over 4

=item *

L<File|CGI::Session::File> - default driver for storing session data in plain files. Full name: B<CGI::Session::File>

=item *

L<DB_File|CGI::Session::DB_File> - for storing session data in BerkelyDB. Requires: L<DB_File>. Full name: B<CGI::Session::DB_File>

=item *

L<MySQL|CGI::Session::MySQL> - for storing session data in MySQL tables. Requires L<DBI|DBI> and L<DBD::mysql|DBD::mysql>. Full name: B<CGI::Session::MySQL>

=back

=head2 SERIALIZERS

=over 4

=item *

L<Default|CGI::Session::Serialize::Default> - default data serializer. Uses standard L<Data::Dumper|Data::Dumper>. Full name: B<CGI::Session::Serialize::Default>.

=item *

L<Storable|CGI::Session::Serialize::Storable> - serializes data using L<Storable>. Requires L<Storable>. Full name: B<CGI::Session::Serialize::Storable>.

=item *

L<FreezeThaw|CGI::Session::Serialize::FreezeThaw> - serializes data using L<FreezeThaw>. Requires L<FreezeThaw>. Full name: B<CGI::Session::Serialize::FreezeThaw>

=back

=head2 ID GENERATORS

Following ID generators are available:

=over 4

=item *

L<MD5|CGI::Session::ID::MD5> - generates 32 character long hexidecimal string. 
Requires L<Digest::MD5|Digest::MD5>. Full name: B<CGI::Session::ID::MD5>.

=item *

L<Incr|CGI::Session::ID::Incr> - generates auto-incrementing ids. Full name: B<CGI::Session::ID::Incr>

=back


=head1 COPYRIGHT

This library is free software. You can modify and or distribute it under the same terms as Perl itself.

=head1 AUTHOR

Sherzod Ruzmetov <sherzodr@cpan.org>. Feedbacks, suggestions are welcome.

=head1 SEE ALSO

=over 4

=item *

L<CGI::Session::Tutorial|CGI::Session::Tutorial> - extended CGI::Session manual

=item *

L<CGI::Session::CookBook|CGI::Session::CookBook> - practical solutions for real life problems

=item *

B<RFC 2965> - "HTTP State Management Mechanism" found at ftp://ftp.isi.edu/in-notes/rfc2965.txt

=item *

L<CGI|CGI> - standard CGI library

=item *

L<Apache::Session|Apache::Session> - another fine alternative to CGI::Session

=back

=cut

# dump() - dumps the session object using Data::Dumper
sub dump {
    my ($self, $file, $data_only) = @_;

    require Data::Dumper;
    local $Data::Dumper::Indent = 1;

    my $ds = $data_only ? $self->{_DATA} : $self;

    my $d = new Data::Dumper([$ds], ["cgisession"]);

    if ( defined $file ) {
        unless ( open(FH, '<' . $file) ) {
            unless(open(FH, '>' . $file)) {
                $self->error("Couldn't open $file: $!");
                return undef;
            }
            print FH $d->Dump();
            unless ( close(FH) ) {
                $self->error("Couldn't dump into $file: $!");
                return undef;
            }
        }
    }
    return $d->Dump();
}



sub version {   return $VERSION()   }


# delete() - sets the '_STATUS' session flag to DELETED,
# which flush() uses to decide to call remove() method on driver.
sub delete {
    my $self = shift;

    # If it was already deleted, make a confession!
    if ( $self->{_STATUS} == DELETED ) {
        confess "delete attempt on deleted session";
    }

    $self->{_STATUS} = DELETED;
}





# clear() - clears a list of parameters off the session's '_DATA' table
sub clear {
    my $self = shift;
    $class   = ref($class);

    my @params = ();
    if ( defined $_[0] ) {
        unless ( ref($_[0]) eq 'ARRAY' ) {
            confess "Usage: $class->clear([\@array])";
        }
        @params = @{ $_[0] };

    } else {
        @params = $self->param();

    }

    my $n = 0;
    for ( @params ) {
        /^_session_/ and next;
        # If this particular parameter has an expiration ticker,
        # remove it.
        if ( $self->{_DATA}->{_SESSION_EXPIRE_LIST}->{$_} ) {
            delete ( $self->{_DATA}->{_SESSION_EXPIRE_LIST}->{$_} );
        }
        delete ($self->{_DATA}->{$_}) && ++$n;
    }

    # Set the session '_STATUS' flag to MODIFIED
    $self->{_STATUS} = MODIFIED;

    return $n;
}


# save_param() - copies a list of third party object parameters
# into CGI::Session object's '_DATA' table
sub save_param {
    my ($self, $cgi, $list) = @_;

    unless ( ref($cgi) ) {
        confess "save_param(): first argument should be an object";

    }
    unless ( $cgi->can('param') ) {
        confess "save_param(): Cannot call method param() on the object";
    }

    my @params = ();
    if ( defined $list ) {
        unless ( ref($list) eq 'ARRAY' ) {
            confess "save_param(): second argument must be an arrayref";
        }

        @params = @{ $list };

    } else {
        @params = $cgi->param();

    }

    my $n = 0;
    for ( @params ) {
        # It's imporatnt to note that CGI.pm's param() returns array
        # if a parameter has more values associated with it (checkboxes
        # and crolling lists). So we should access its parameters in
        # array context not to miss anything
        my @values = $cgi->param($_);

        if ( defined $values[1] ) {
            $self->_set_param($_ => \@values);

        } else {
            $self->_set_param($_ => $values[0] );

        }

        ++$n;
    }

    return $n;
}


# load_param() - loads a list of third party object parameters
# such as CGI, into CGI::Session's '_DATA' table
sub load_param {
    my ($self, $cgi, $list) = @_;

    unless ( ref($cgi) ) {
        confess "save_param(): first argument must be an object";

    }
    unless ( $cgi->can('param') ) {
        my $class = ref($cgi);
        confess "save_param(): Cannot call method param() on the object $class";
    }

    my @params = ();
    if ( defined $list ) {
        unless ( ref($list) eq 'ARRAY' ) {
            confess "save_param(): second argument must be an arrayref";
        }
        @params = @{ $list };

    } else {
        @params = $self->param();

    }

    my $n = 0;
    for ( @params ) {
        $cgi->param(-name=>$_, -value=>$self->_get_param($_));
    }
    return $n;
}




# another, but a less efficient alternative to undefining
# the object
sub close {
    my $self = shift;

    $self->DESTROY();
}



# error() returns/sets error message
sub error {
    my ($self, $msg) = @_;

    if ( defined $msg ) {
        $errstr = $msg;
    }

    return $errstr;
}


# errstr() - alias to error()
sub errstr {
    my $self = shift;

    return $self->error(@_);
}



# atime() - rerturns session last access time
sub atime {
    my $self = shift;

    if ( @_ ) {
        confess "_SESSION_ATIME - read-only value";
    }

    return $self->{_DATA}->{_SESSION_ATIME};
}


# ctime() - returns session creation time
sub ctime {
    my $self = shift;

    if ( defined @_ ) {
        confess "_SESSION_ATIME - read-only value";
    }

    return $self->{_DATA}->{_SESSION_CTIME};
}


# expire() - sets/returns session/parameter expiration ticker
sub expire {
    my $self = shift;

    unless ( @_ ) {
        return $self->{_DATA}->{_SESSION_ETIME};
    }

    if ( @_ == 1 ) {
        return $self->{_DATA}->{_SESSION_ETIME} = _time_alias( $_[0] );
    }

    # If we came this far, we'll simply assume user is trying
    # to set an expiration date for a single session parameter.
    my ($param, $etime) = @_;

    # Let's check if that particular session parameter exists
    # in the '_DATA' table. Otherwise, return now!
    defined ($self->{_DATA}->{$param} ) || return;

    if ( $etime == -1 ) {
        delete $self->{_DATA}->{_SESSION_EXPIRE_LIST}->{$param};
        return;
    }

    $self->{_DATA}->{_SESSION_EXPIRE_LIST}->{$param} = _time_alias( $etime );
}



# parses such strings as '+1M', '+3w', accepted by expire()
sub _time_alias {
    my ($str) = @_;

    # If $str consists of just digits, return them as they are
    if ( $str =~ m/^\d+$/ ) {
        return $str;
    }

    my %time_map = (
        s           => 1,
        m           => 60,
        h           => 3600,
        d           => 3600 * 24,
        w           => 3600 * 24 * 7,
        M           => 3600 * 24 * 30,
        y           => 3600 * 24 * 365,
    );

    my ($koef, $d) = $str =~ m/([+-]?\d+)(\w)/;

    if ( defined($koef) && defined($d) ) {
        return $koef * $time_map{$d};
    }
}


# remote_addr() - returns ip address of the session
sub remote_addr {
    my $self = shift;

    return $self->{_DATA}->{_SESSION_REMOTE_ADDR};
}


# param_hashref() - returns parameters as a reference to a hash
sub param_hashref {
    my $self = shift;

    return $self->{_DATA};
}


# name() - returns the cookie name associated with the session id
sub name {
	my ($class, $name)  = @_;

	if ( defined $name ) {
		return $CGI::Session::NAME = $name;
	}

    return $CGI::Session::NAME;
}


# cookie() - returns CGI::Cookie object
sub cookie {
    my $self = shift;
    confess "cookie(): don't use me! I'm broken";
}





# $Id: Session.pm,v 3.2.2.1 2002/11/28 03:16:50 sherzodr Exp $
