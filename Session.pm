package CGI::Session;

require 5.003;
use strict;
use Carp 'croak';
use AutoLoader 'AUTOLOAD';

# $Id: Session.pm,v 2.94 2002/08/26 08:01:33 sherzodr Exp $

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



($VERSION) = '2.94';



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
        # hash table. It will be filled by _init() method
        _data => { },

    };

    bless ($self, $class);

    # now is a very good time to validate the driver
    $self->_validate_driver() or return;

    # If we are this far, _validate_driver() didn't kill us. So we
    # can try to initialize the session data safely
    $self->_init() or return;

    return $self;
}



# Hopefully derived class will provide it. If it doesn't we will still
# catch the call without letting the AUTOLOAD look for it. Too expensive!
sub DESTROY { }



# _validate_driver(): checks if the derived class is a valid
# CGI::Session driver.
sub _validate_driver {
    my $self = shift;
    my $class = ref($self);

    # Following methods should be either present in the driver or the
    # driver should be able to inherit them from other classes
    my @required_methods = qw(store retrieve tear_down generate_id);

    for ( @required_methods ) {
        unless ( $self->UNIVERSAL::can($_) ) {
            croak "$class doesn't seem to be a valid CGI::Session driver.\n" .
                "$_() method is missing.";
        }
    }
    return 1;
}




# _init(): called from within new() to initialize $self->{_data},
# which is the session data. It also decides whether to
# create new session, or initialize existing one. In case
# it fails for any reason, it creates new session.
#
# RETURN VALUE: whatever _old_session() or _new_session() returns
sub _init {
    my $self = shift;

    my $sid = $self->{_options}->{sid};

    if (  $sid ) {

        # we are asked to initialize a certain session. So let's see
        # if we can do it.
        $self->{_data} = $self->retrieve( $sid );

        if ( $self->{_data}->{_session_id} ) {
            # yes, we did it!

            # following line just updates the last access time of the session
            # and synchronizes the in-memory data with the one in the disk
            return $self->_old_session();

        } else {
            # oops, something wrong happened, and we couldn't load the
            # previously stored session data. So let's return a new session
            return $self->_new_session();
        }

    } else {

        # No one asked us for a session, so let's create a new one
        return $self->_new_session();

    }
}



# _new_session(): initializes a new session with meta information and
# tries to store() it in the disk. Called from w/in _init().
#
# RETURN VALUE: whatever store() returns from derived class
sub _new_session {
    my $self = shift;

    # creating the session meta table
    $self->{_data} = {
        _session_id => $self->generate_id(),
        _session_ctime => time,
        _session_atime => time,
        _session_etime => undef,
        _session_remote_addr => $ENV{REMOTE_ADDR} || undef,
        _session_remote_host => undef,
    };

    my $sid = $self->{_data}->{_session_id};

    # storing the session
    return $self->store($sid);
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

    my $sid = $self->{_data}->{_session_id};
    return $self->store($sid);
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
    my $sid = $self->{_data}->{_session_id};


    # call derived store() method
    return $self->store( $sid );
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

    # we cannot use $self->{_options}->{sid}! We always have to
    # use the following syntax to get the session id. id() method is good
    # too, but it triggers AUTLOAD, so let's stay away from it.
    my $sid  = $self->{_data}->{_session_id};
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

    if ( $name && $value) { # called with extended name/value syntax
        return $self->_assign_param($name, $value);

    } elsif ( $name ) {     # called with extended name syntax (-name=>'')
        return $self->_return_param( $name );

    } elsif ( @_ == 2 ) {   # called with simple name/value syntax
        return $self->_assign_param($_[0], $_[1]);

    }

    # if we came this far, definitely something went wrong
    my $class = ref($self);
    croak qq~Usage: $class->param("name"),\n
        $class->param(-name=>"name"),\n
        $class->param("name", "value"), \n
        $class->param(-name=>"name", -value=>"value")~;
}




# options(): returns the options passed to the constructor. Mostly
# used by the driver developers
sub options {   return $_[0]->{_options}    }



# raw_data(): returns the raw data in hashref form.
# This method is for the drivers only
sub raw_data {  return $_[0]->{_data}       }



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



1;



__END__;



###########################################################################
################ FOLLOWING METHODS ARE LOADED ON DEMAND ###################
###########################################################################



# remote_addr(): returns the IP address of the user responsible
# for the new session
sub remote_addr {
    my $self = shift;

	if ( @_ ) {
		croak "remote_addr() is read only";
	
	}

    return $self->{_data}->{_session_remote_addr};
}



# remote_host(): returns the claimed hostname of the requested client.
# If reverse lookup is not enabled and/or could not be succeeded, it is
# the same as the remote_addr
sub remote_host {
    my $self = shift;

	if ( @_ ) {
		croak "remote_host() is read only";
	}

    return $self->{_data}->{_session_remote_host};
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

    if ( defined ($d) && defined ($l) ) {
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

	# getting the session id
	my $sid = $self->{_data}->{_session_id};

	# call derived store() method. 
    # Thanks to Olivier Dragon <dragon@shadnet.shad.ca> for noticing
    # missing store() here
    $self->store($sid);
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

    unless ( $cgi->UNIVERSAL::isa("CGI") ) {
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


    unless ( $cgi->UNIVERSAL::isa("CGI") ) {
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




# clear(): clears data from the session
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
    my $sid = $self->{_data}->{_session_id};

    # let's synchronize data in disk with the in-memory session data
    $self->store( $sid );
}



# error(): sets/gets the error message to/from $CGI::Session::errstr
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

    $self->tear_down($sid);
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

    # First I thought calling param() would be a good a idea.
    # But in that case user will not have access to SPECIAL NAMES.
    # So I decided to give the user read access to those keys bu
    # not calling param().
    return $self->{_data}->{$key};
}



# STORE(): called when a value is assigned to a session hash
# Usage: $session{some_key} = "Some Value"
#
# RETURN VALUE: same as $session->param("some_key", "Some Value")
sub STORE {
    my ($self, $key, $value) = @_;

    # Map of the function related to the private data.
    # If user tries to set these values, we call respective methods
    # But for anything else we call param(), which will be ignoring
    # special names
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

