package CGI::Session;

use strict;
use Carp;
use vars qw($VERSION $errstr);

$VERSION = "2.1";

# constructor
# Usage: CLASS->new($sid, {Key1 => Value1, Key2 => Value2})
sub new {
    my $class = shift;

    unless ( @_ == 2 ) {
        $class = ref($class) || $class;
        croak "Usage: $class->new(\$sid, {OPTIONS=>VALUES})";
    }

    my $self = {
        _options => {
            sid     => $_[0],
            %{$_[1]},
        },
        _data => { },
    };

    bless $self, ref($class) || $class;
    $self->_init() or return;
    return $self;
}


sub _new_session {
    my $self = shift;

    $self->{_data} = {
        _session_id => $self->generate_id(),
        _session_ctime => time(),
        _session_atime => time(),
        _session_etime => undef,
    };

    return $self->store($self->id(), $self->{_data}, $self->{_options});
}


sub _old_session {
    my $self = shift;

    $self->{_data}->{_session_atime} = time();

    return $self->store($self->id(), $self->{_data}, $self->{_options});
}


# initializer for the new()
sub _init {
    my $self = shift;
    my $sid = $self->{_options}->{sid};

    if ( $sid ) {

        $self->{_data} = $self->retrieve( $self->{_options}->{sid}, $self->{_options} );

        if ( $self->{_data}->{_session_id} ) {

            return $self->_old_session();

        } else {

            return $self->_new_session();

        }

    } else {

        return $self->_new_session();

    }
}




# returns the session id
# Usage: CLASS->id();
sub id {
    my $self = shift;

    if ( @_ ) {
        my $class = ref($self);
        croak "Usage: $class->id(). No arguments!";
    }
    return $self->{_data}->{_session_id};
}



# closes the session
# Usage: CLASS->close()
sub close {
    my $self = shift;

    if ( @_ ) {
        my $class = ref($self);
        croak   "Usage: $class->close(). No arguments!";
    }

    $self->DESTROY();
}



# parses date shortcuts for the expires() method
# Usage: _date_shortcuts("5M")
sub _date_shortcuts {
    my $arg = shift;

    my $ident_table = {
        s => 1,             # one second is one second, surprise :-)
        m => 60,            # one minute is 60 seconds
        h => 3600,          # one hour is 3,600 seconds
        d => 86400,         # one day is 86,400 seconds
        w => 604800,        # one week is 604800 seconds
        M => 2592000,       # one month
        y => 86400 * 365,   # one year
    };

    my ($coeff, $ident);
    if ( $arg =~ m/(\d+)(\w)/ ) {
        ($coeff, $ident) = ($1, $2);
        return ( $coeff * $ident_table->{$ident} );
    }

    return $arg;
}




# gets/sets the expiration time for the session
# Usage: CLASS->expires([seconds]);
sub expires {
    my ($self, $date) = @_;

    unless ( $date ) {
        return $self->{_data}->{_session_etime};
    }

    my $in_seconds = _date_shortcuts($date);
    $self->{_data}->{_session_etime} = time() + $in_seconds;
}

# returns the created date of the session as a time() value
sub ctime {
    my $self = shift;

    return $self->{_data}->{_session_ctime};
}


# returns the last accessed time for the session
sub atime {
    my $self = shift;

    if ( $_[0] ) {
        $self->{_data}->{_session_atime} = time();
    }

    return $self->{_data}->{_session_atime};
}


# assigns the param
sub _assign_param {
    my ($self, $key, $value)  = @_;

    $key =~ m/^_/ and return;

    my $sid = $self->id();

    $self->{_data}->{$key} = $value;
    return $self->store( $sid, $self->{_data}, $self->{_options} );
}

# return param
sub _return_param {
    my ($self, $key) = @_;

    $key =~ m/^_/ and return;

    return $self->{_data}->{$key};
}

# sets/gets the session parameters
# Usage: CLASS->param('name')
# Usage: CLASS->param(-name=>'name')
# Usage: CLASS->param('name', 'value')
# Usage: CLASS->param(-name=>'name', -value=>'value')
sub param {
    my $self = shift;

    my $sid = $self->id();
    my $data = $self->{_data};

    unless ( @_ ) {
        my @params = ();
        for ( keys %{$self->{_data}} ) {
            /^_/ and next;
            push @params, $_;
        }
        return @params;
    }

    if ( @_ == 1 ) {

        return $self->_return_param($_[0]);
    }

    my $args = {-name => undef,  -value => undef,  -values => undef,  @_ };
    my ($name, $value) = ( $args->{'-name'}, $args->{'-value'} );

    if ( $name && $value) {

        return $self->_assign_param($name, $value);

    } elsif ( $name ) {

        return $self->_return_param( $name );

    } elsif ( @_ == 2 ) {

        return $self->_assign_param($_[0], $_[1]);

    }

    my $class = ref($self);
    croak qq~Usage: $class->param("name"),\n
        $class->param(-name=>"name"),\n
        $class->param("name", "value"), \n
        $class->param(-name=>"name", -value=>"value")~;
}



# stores the CGI parameters in the session object.
# Usage: CLASS->save_param($cgi [, \@array])
sub save_param {
    my $self = shift;
    my $cgi = shift;

    # get the names of all the parameters
    # the user wants to save...
    my @param = ();
    if ( defined $_[0] ) {
        @param = @{ $_[0] };
    }

    # if user didn't specify parameters, then decide
    # what to save yourself
    unless ( @param ) { @param = $cgi->param()  }

    foreach ( @param ) {
        /^_/ and next;      # skip the special names (/^_/)
        $self->param(-name=>$_, -value=>$cgi->param($_));
    }
}



# loads the parameters from the session object to CGI object
# Usage: CLASS->load_param($cgi [,\@array])
sub load_param {
    my $self = shift;
    my $cgi = shift;

    # get the names of all the parameters
    # the user wants to load to CGI object
    my @param = @_;

    # if user didn't specify parameters, then decide
    # what to save yourself
    unless ( @param ) { @param = $self->param() }

    foreach ( @param ) {
        /^_/ and next;      # skip the special names (/^_/)
        $cgi->param(-name=>$_, -value=>$self->param($_));
    }
}




# clears all the data from the session
# Usage: CLASS->clear([\@array])
sub clear {
    my $self = shift;

    # get the list of all the params the user
    # wants to clear
    my @params = ();

    if ( defined $_[0] ) {
        @params = @{ $_[0] };
    }

    # if the user doesn't provide with names, let's clear
    # everything
    unless ( @params ) { @params = $self->param() }

    # getting the session_id
    my $sid = $self->id();

    for ( @params ) {
        /^_/ and next;      # skip  the special  names
         delete $self->{_data}->{$_};
    }

    # let's store the session data back
    $self->store($sid, $self->{_data}, $self->{_options});
}

# sets/gets the error
# Usage: CLASS->error([$msg]);
sub error {
    my ($self, $msg) = @_;

    if ( $msg ) {   $errstr = $msg  }
    else {          return $errstr  }

}



sub delete {
    my $self = shift;

    my $sid = $self->id();

    $self->tear_down($sid, $self->{_options});
}


1;

__END__;

=head1 NAME

CGI::Session 2.0 - Perl extension for persistent session management in CGI 
applications

=head1 SYNOPSIS

    use CGI::Session::DB_File;
    use CGI;

    my $cgi = new CGI;

    # get the user's session id either from the cookie, or from the query_string.
    # If it is  not present, create a new session for the visitor
    my $session;
    {
        my $sid = $cgi->cookie("SITE_SID") || $cgi->param("sid") || undef;

        $session  = new CGI::Session::DB_File($sid, { FileName=>'sessions.db',
                                                     LockDirectory=>'/tmp'});
    }

    # now, don't forget to send the session id back as a cookie
    {
        my $cookie = $cgi->cookie(-name=>"SITE_SID", -value=>$session->id);
        print $cgi->header(-cookie=>$cookie);
    }


    # now, if the user submitted his first name in a form, we can save it
    # in our session
    my $first_name  = $cgi->param("first_name");
    $session->param("first_name", $first_name);


    # if it is an old session, we can recognize the user and greet him
    # with his first name:
    if ( $session->param("first_name") ) {
        print "Hello ", $session->param("first_name"), " how have you been?\n";
        print "You last visited the site on ", scalar(localtime($session->atime));
    }

    # posibilities are endless!

=head1 DEPENDANCIES

The library requires Perl 5.003 or higher. No other dependencies.

=head1 DESCRIPTION

C<CGI::Session> is the Perl5 library which provides an easy persistent
session management system across HTTP requests. Session persistence is a
very important issue in web applications. Shopping carts, user-recognition
features, login and authentication methods and many more require persistent
session management mechanism, which is both secure and reliable.
C<CGI::Session> provides with just that. You can read the whole documentation
as a tutorial on session management. But if you are already familiar with
C<CGI::Session> please go to the L<methods|"METHODS"> section for the list
of all the methods available. 

=head1 REFRESHER ON SESSION MANAGEMENT

Since HTTP protocol is stateless, web programs need a way of recognizing
clients across different HTTP requests. Each click to a site by the
same user is considered brand new request for your web applications, and
all the state information from the previous requests will be lost. These
constraints make it difficult to write web applications such as shopping
carts, users' browsing history, login/authentication routines, users'
preferences among hundreds of others.

But all of these constraints can be overcome by applying a persistent
session management mechanism. That's where C<CGI::Session> comes in.

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

    my $session = new CGI::Session::File(undef,
        {
            LockDirectory=> "/tmp/sessions",
            Directory    => "/tmp/sessions",
    });

we're passing two arguments, the fist one is session id, which is undefined
in our case, and the second one is the anonymous hash

    {
        LockDirectory=> "/tmp/sessions",
        Directory    => "/tmp/sessions",
    }

which points to the locations where session files and their lock files
should be created. You might want to choose a more secure location than
I did in this example.

If the session id is undefined, the library will generate a new id,
and you can access it's value via id() method: (see L<methods|"METHODS">)

    my $sid = $session->id();

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

then, when the user clicks on the link, we just check the value of C<sid>
CGI parameter. And if it exists, we consider it as an existing session id
and pass it to the C<CGI::Session>'s constructor:

    use CGI::Session::File;
    use CGI;

    my $cgi = new CGI;
    my $sid = $cgi->param("sid") || undef;
    my $session = new CGI::Session::File($sid,
        {
            LockDirectory=>"/tmp/sessions",
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
and our application will not recognize the user resulting in the creaion of
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
            LockDirectory=> "/tmp/sessions",
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

=head2 ERROR CHECKING

C<CGI::Session> itself never die()s (at least tries not to die), neither
should its drivers. But the methods' return value indicates the
success/failure of the call, and C<$CGI::Session::errstr> global variable
will be set to an error message in case something goes wrong. So you should
always check the return value of the methods to see if they succeeded:

    my $session = new CGI::Session::File($sid,
        {
            LockDirectory=>"/tmp/sessions",
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


=item 2

If you want to store more values  in the same session parameter, you can
pass a reference to an array or a hash. This is the most frequently
exercised technique in shopping cart applications, or for storing users'
browsing history. Here is the example where we store the user's
shopping cart as a reference to a hash-table, keys holding the item name,
and their values indicating the number of items in the cart.
( I would go with item id rather than item names, but we choose
item names here to make the things clearer for the reader):

    $session->param(-name=>'cart', -value=>{
                                    "She Bang Hat"    => 1,
                                    "The Came T-shirt"=> 1,
                                    "Perl Mug"        => 2
                                   });

the same assignment could be performed in the following two steps as well:

    my $cart = {
        "She Bang Hat"    => 1,
        "The Came T-shirt"=> 1,
        "Perl Mug"        => 2
    };

    $session->param(-name=>'cart', -value=>$cart);


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

It means, if the search form had a text field with the name "keyword":

    <input type="textfield" name="keyword" />

after calling L<save_param($cgi)|"METHODS">, the value of the text field will be
available via L<$session->param("keyword")|"METHODS">, and you can re-write the above
text field like the following:

    my $keyword = $session->param("keyword");
    print qq<INPUT TYPE="textfield" name="keyword" value="$keyword" />~;

=item 4

Sometimes you don't want to save all the CGI parameters, but want
to pick from the list. L<save_param()|"METHODS"> method optionally accepts an arrayref
as the second argument telling it which L<CGI> parameters it should save
in the session:

    $session->save_param($cgi, ["keyword", "order_by", "order_type", "category"]);

Now only the above listed parameters will be saved in the session for future
access.

Inverse of the L<save_param()|"METHODS"> is L<load_param()|"METHODS">.

=back

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

=item 4

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

    if ( $cgi->param("_cmd") eq "clear-cart" ) {
        $session->clear("cart");
    }

What happens is, it delets the given parameter from the session for good.
If you do not pass any arguments to C<clear()>, then all the parameters
of the session will be deleted. Remember that C<clear()> method DOES NOT
delete the session. Session stays open, only the contents of the session
data will be deleted.

=head2 DELETING THE SESSOIN

If you want to delete the session for good together with all of its contents,
then L<delete()|"METHODS"> method is the way to go. After you call this method,
the C<CGI::Session> will not have access to the perviou session at all,
because it was deleted from the disk for good. So it will have to generate
a new session id instead.

=head2 CLEAR OR DELETE?

So, should we L<delete()|"METHODS"> the session when the user finishes browsing the site
or clicks on the "sign out" link? Or should we C<clear()> it? And I'll answer
the question with another question; bright mind should be able to see me through!
If the user click on the "sign out" link, does it mean he is done browsing
the site? Absolutely not. The user might keep surfing the site even after
he signs out or clears his shopping cart. He might even continue his shopping
after several hours, or several days. So for the comfort of the visitors
of our site, we still should keep their session data at their fingertips,
and only C<clear()> unwanted session parameters, for examle, the user's
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
    my $options = {Lockdirectory=>"/tmp/sessions", Directory=>"/tmp/sessions"};

    while ( my ($file, $info) = each %db ) {

        my ($sid) = $file =~ m/CGI-Session-([^\.]+)\.dat) or next;
        $session = CGI::Session::File->new($sid, $options);

        if ( (time - $session->atime) > YEAR ) {

            $session->delete();

        }
    }

    untie %dir;

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

    use CGI::Session::File;
    my $session = new CGI::Session::File(undef,
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

saves the CGI object parameters into the session object. It's very helpful
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

this is the opposite of the above C<save_param()> method. It loads the
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

As you see, we don't have to retrieve the value of the C<login_name> as we
did in our C<save_param()> example. We just load the session data into the
CGI object with C<load_param()> method, and all the session parameters will
come into existence in our CGI object. Now our
C<$cgi->textfield(-name=>"login_name")> prints the value of the current
C<login_name> parameter of the CGI object. It means, we can also retrieve
the  value of C<login_name> with

    $cgi->param("login_name");

syntax.

=item clear()

this method clears the session data. Do not confuse it with C<delete()>,
which deletes the session data together with the session_id. C<clear()> only
deletes the data stored in the session, but keeps the session open. If you
want to clear/delete certain parameters from the session, you just pass an
arrayref to the method. For example, here is the revised copy of the code I
used in one of my applications that clear the contents of the user's
shopping cart when he/she click on the 'clear the cart' link:

    if ( $cgi->param("_cmd") eq "clear-cart") {

        $session->clear(["SHOPPING_CART"]);
        print $cgi->redirect(-uri=>$ENV{HTTP_REFERER});

    }

I could as well use C<clear()> with no arguments, in which case it would
delete all the data from the session, not only the SHOPPING_CART.

=item expires()

This method is

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

=item ctim()

Returns the time() value of the date when the session was created:

    printf("Session was created on %s\n", localtime($session->ctime));

=item atime()

Returns the time() value of the date when the session was last accessed:

    printf("Session was last accessed on %s\n", localtime($session->atime));

    printf("Session was last accessed %d seconds ago\n", time() - $session->atime);

=item delete()

deletes the session data from the disk permantly

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
persistant storage. These are the issues specific to the storage type
you want to use and that's what the driver is for. So driver is just another
Perl library, which uses C<CGI::Session> as a base class, and provides three
additional methods, C<store()>, C<retrieve()> and C<tear_down()>. As long
as you provide these three methods, C<CGI::Session> will handle all the
other part.

=head2 WHAT ARE THE SPECS?

=over 4

=item *

C<store()> will recieve four arguments, C<$self>, which is the object itself,
C<$sid>, which is the session id, C<$hashref>, which is the session data as
the reference to an annonymous hash, and <$options>, which is another hash
reference that was passed as the second argument to C<new()>. C<store()>'s
task is to store the hashref (which is the session data)in the disk in such
a way so that it could be retrived later. It should return true on success,
undef otherwise, passing the error message to C<$self-E<gt>error()> method.


=item *

C<retrieve()> will recieve three arguments, C<$self>, which is the object
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
stirng which will be used as a session id. Default C<generate_id()> uses
Digest::MD5 library to generate a unique identifier for the session.
If you want to implement your own C<generate_id()> method, you can override
it by including one in your module as the fourth method.

=over 4

=item *

C<generate_id()> recieves only one argument, C<$self>, which is the object
itself. The method is expected to return a string to be used as the session
id for new sessions.

=back

The challenging part might seem to store the C<$hashref> and to be able
to restore it back. But there are already libraries that you can make use of
to do this job very easily. Drivers that come with C<CGI::Session> depend on
L<Data::Dumper||Data::Dumper>, but you can as well go with L<Storable> or L<FreezeThaw>
libraries which allow you to C<freeze()> the Perl data and C<thaw()> it later,
thus you will be able to re-create the the C<$hashref>. The reason we
prefered L<Data::Dumper|Data::Dumper> is, it comes standard with Perl.

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

=head1 AUTHOR

Sherzod B. Ruzmetov <sherzodr@cpan.org>

=head1 SEE ALSO

L<CGI::Session::File>, L<CGI::Session::DB_File>, L<CGI::Session::MySQL>
L<Apache::Session>, L<Data::Dumper>, L<Digest::MD5>, L<FreezeThaw>,
L<Storable>, L<CGI>

=cut
