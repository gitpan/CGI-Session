package CGI::Session;

use 5.006;
use strict;
use Carp;

$CGI::Session::VERSION = '0.01';


# Usage:
#   $Session->param('f_name');
#   $Session->param(-name=>'f_name');
#   $Session->param(-name=>'f_name', -value=>'Sherzod'); # assignment
sub param {
    my $self = shift;

    unless ( $_[0] ) {
        my @params;
        map { /^[^_]/ && push @params, $_} keys %{$self};
        return @params;
    }

    my %args = (
        '-name' => '',
        '-value'=> '',
        @_,
    );

    if ($args{'-name'} && $args{'-value'}) {

        $self->{$args{'-name'}} = $args{'-value'};

    } elsif ( $args{'-name'} ) {

        return $self->{$args{'-name'}};

    } else {

        return $self->{$_[0]};
    }
}




# Usage:
#   $Session->id;
sub id {
    my $self = shift;

    return $self->{_session_id};
}



# Usage:
#   $Session->load_param($cgi)
sub load_param {
    my ($self, $cgi) = @_;

    unless (ref $cgi) {

        croak <<'END_OF_USAGE';
    Usage:
        $Session->load_param(\$cgi)

        $Session - CGI::Session object
        $cgi     - CGI object
END_OF_USAGE
    }

    for ( $self->param() ) {
        $cgi->param(-name=>$_, -value=>$self->param($_));
    }

    return $cgi->param();
}



# Usage:
#   $Session->save_param($cgi);
sub save_param {
    my ($self, $cgi) = @_;

    for ($cgi->param()) {

        $self->{$_} = $cgi->param($_);

    }

    return $self->param();
}




# Usage:
#   $Session->delete;
#   $Session->delete('f_name');
sub delete {
    my $self = shift;

    $_[0] ? (delete $self->{$_[0]}) : tied (%{$self})->delete;

}



# Usage:
#   $Session->close;
sub close { untie %{$_[0]} }







1;
__END__

=head1 NAME

CGI::Session - Font-end to Apache::Session

=head1 SYNOPSIS

  use CGI::Session::DB_File;

  my $Session = new CG::Session::DB_File(undef, {File=>'somedb.db', LockDir=>'/var/temp/sessions'});

  $Session->param(-name=>'f_name', -value=>"Sherzod");
  $Session->param(-name=>'age', -value=>21);

  my $sid = $Session->id();

  $Session->close();

  # Some time later...

  my $Session->new CGI::Session::DB_File($sid, {File=>'some.db', LockDir=>'/var/temp/sessions'});

  print "Hi, your name is ", $Session->param('f_name'), "\n";
  print "And you are ", $Session->param('age'), "\n";

  print "Bye";

  $Session->delete();

=head1 MODULES

=over 1

=item CGI::Session

=item CGI::Session::DB_File

=item CGI::Session ::File

=item CGI::Session::MySQL

=item CGI::Session::Oracle

=item CGI::Session::Postgres

=item CGI::Session::Sybase

=back

=head1 DESCRIPTION


Front end utility for Apache::Session by Jeffrey Baker and set of modules it comes with.
The interface is pretty similar to that of CGI.pm with some additional methods.
So it shouldn't take users long to get used to it.

=head1 METHODS

=over 4

=item *

C<new([$sid] {%attr})> - constructor method. Constructs and returns CGI::Session object.
To initialize the object with new session id, just pass 'undef' for the $sid. To restore
the existing session id you need to pass that id as the first argument to the constructor.

=item *

C<param([$key|%attr])> - this method serves two main objectives depending on the context it is
used. First objective is retrieving the paramteres from the session object. If you pass param()
a key, it will return the value associated with it. Example:

    print "Your age is ", $Session->param('age');

If you wanted to be more explicit, you could write the above in the following way as well:

    print "Your age is ", $Session->param(-name=>'age');

The second objective is assigning new paramteres to the session object. Before assigning any
paramters you need to realize that each parameter is in key=>value pair format. Suppose the
visitor to your website gave his/her name and you wanted to save it so that later (may be
after several days?) you will be able to present him/her a personalized message. Example:

    $Session->param(-name=>'name', -value=>"Dr. Watson");

Now we can just say

    print "Hellow dear ", $Session->param('name'), "!";

Neat, isn't it?

=item *

C<load_param($cgi)> - loads the session parameters to the CGI environment, and you'll be able to
access them with CGI.pm's, param() method now. A lot of times you want to initilize the form
with some information in the session. This feature allows you do just that. Remember to pass CGI
object as the first and the only argument. Example:

    $Session->load_param($cgi);

where $cgi is the CGI.pm object

=item *

C<save_param($cgi)> - this method is the opposite of load_param(). It saves all the parameters
in your CGI environment to your Session's parameters. Forexample, you might want all  the
information that user supplied in a form in your website to be saved into the session object.
Again, remember to pass CGI object as the first and the only argument. Example:

    $Session->save_param($cgi);

=item *

C<delete([$key])> - deletes the sessions permanantly. If you pass it a key, it will attempt do
dealete a paramter off the session. If you do not pass any arguments. It will delete the session
itself permanantly both from the object and from the database. So please, use with caution.

=item *

C<close()> - closes the session temporarily. It's actually a destructor, so most of the time you
won't have to use it because Perl calls it automaticly. But if you do, you'll be able to reopent
the same session by passing the session id number to the new() - constructor method.

=back


=head1 EXAMPLES

Following are some ways that CGI::Session could be used. If you have some other unique examples,
I'd be happy to include them in this section and give the source a full credit. Examples should 
also be available in the eg/ in your distribution directory. 

=head2 Example 1

=head3 Description

Following example demonstrates how you could say a user
I<Hi, well come back. Your last visit was on some date> or I<Welcome. I hope you'll enjoy the site>
I might be using DB_File, but you're wellcome to use any subclasses such as MySQL, File etc.


=head3 Code

    #!/usr/bin/perl -w

    use strict;
    use CGI;
    use CGI::Session::DB_File;

    my ($cgi, $Session, $sid);

    $cgi = new CGI;

    # Assume we prevously saved the session_id in the user's computer as a cookie.
    # Let's see if it's still there. If not, just assign $sid an undef.
    $sid = $cgi->cookie('TESTER_SID') || undef;

    # If the $sid could be found in the cookie, than the object will be
    # initialized with all the previous information saved in the session.
    $Session = new CGI::Session::DB_File($sid, {FileName=>'sessions.db', LockDirectory=>'.'});

    # If session_id couldn't be retrieved from the cookie, new id was supposed to be
    # created, right? So let's find out what id that is
    $sid ||=$Session->id;

    # Now we need to construct a cookie, and save it into the user's
    # computer so that we can access it next time the user logs in
    my $cookie = $cgi->cookie(-name=>'TESTER_SID', -value=>$sid, -expires=>"+3d");

    # Now we're sending the cookie back to the user's computer.
    print $cgi->header(-cookie=>$cookie),
        $cgi->start_html("CGI::Session");

    print $cgi->a({-href=>$cgi->script_name()."?_cmd=delete"}, "Delete the session");


    if ($Session->param('last_visited_time') ) {

        print $cgi->h2("Hi, your last visit was on " .
                        localtime($Session->param('last_visited_time')));

    } else {

        print $cgi->h2("Welcome to my site, I hope you'll enjoy it");

    }


    # Now update the session.

    $Session->param(-name=>'last_visited_time', -value=>time());

    $Session->close();

    print $cgi->end_html;



=head3 Notes

Your first visit will be welcommed. And if you refresh, it will tell you
your "last visit". Now close the browser, and reopen the page again, you'll see
that it recognizes you. Even though you visit the page next day, it will tell you
exact time you visited the site. How is it accomplished? Well, suppose it's your first
visit. CGI::Session will create an idea for you and CGI will help to store that idea
in your computer. Than we record the time you visited in as the Session's parameter.
The nex time you visit the page, we try to get the cookie from your computer and
initialize the object with the id. Remember, if you pass session id to the constructor (new())
it will re-initialize the previously created session. So you'll have all the previously
stored information in your object.

I hope this example demonstrates the basic use of CGI::Session (and Apache::Session, of course)


=head2 Example 2


=head3 Description

Here is the example that shows how to store the information in the form, and some powerfull
features of my load_param() and save_param() methods.


=head3 Code

    #!/usr/bin/perl -w

    use strict;
    use CGI;
    use CGI::Session::DB_File;

    my ($cgi, $Session, $sid);

    $cgi = new CGI;

    $sid = $cgi->cookie("Example2_SID");

    $Session = new CGI::Session::DB_File($sid, {FileName=>'sessions.db', LockDirectory=>'.'});

    if ($sid) {
        $Session->load_param($cgi);

    }

    my $cookie = $cgi->cookie(-name=>'Example2_SID', -value=>$Session->id, -expires=>"+1d");

    print $cgi->header(-cookie=>$cookie),
        $cgi->start_html("CGI::Session / Example 2"),
        $cgi->h2("Example 2");


    if ($cgi->param('_cmd') eq 'save') {

        $Session->save_param($cgi);
        print $cgi->div("Thanks, for your registration. Just hope that we're not one of those bastards who keep sending you all kinds of spam.");

        # now you could do smt more with that email, but we won't.

    } else {

        $Session->param('name') and
            print $cgi->div("Wellcome back" . $Session->param('name') );

        print $cgi->h2("Please, subscribe to our magazine");
        print $cgi->start_form,
            $cgi->hidden(-name=>'_cmd', -value=>'save'),
            $cgi->div("Your name:"),
            $cgi->textfield(-name=>'name', -size=>40),
            $cgi->div("Your email address:"),
            $cgi->textfield(-name=>'email', -size=>40),$cgi->br,
            $cgi->submit(-value=>'Subscribe'),
            $cgi->end_form;

    }


    print $cgi->end_html;


=head3 Notes

After submitting your name and email to the above form, just close your
browser, and re-visit the same page after a while. It will solute you with your name
you provided, and it will have the forms already filled for you.

I hope this explains some of the trick that some e-commerce web-sites do to you :-).

I will be working on some more complicated and mostly used examples as I have time.
But this should be enough to get you started with CGI::Session. Also, please consult
Apache::Session manual by Jeffrey Baker.




=head1 TODO

There're several features that I am contemplating to add. They are the following. If you have
any other features in mind, please let me know. We can work them out together if you wish.

=over 4

=item *

To be able to set expiration period to the sessions and the ability to expire them

=back


=head1 AUTHOR

Sherzod B. Ruzmetov <sherzodr@cpan.org>

=head1 COPYRIGHT

This library is a free software. You can redistribute and modify it under the
same conditions as Perl itself.

=head1 SEE ALSO

CGI::Session::DB_File, CGI::Session::File, CGI::Session::DB_File,
CGI::Session::MySQL, CGI::Session::Oracle, CGI::Session::Sybase, CGI::Session::Postgres,
Apache::Session, Apache::Session::Oracle, Apache::Session::MySQL, Apache::Session::Sybase, Apache::Postgres, Apache::Session::DB_File, Apache::Session::File, CGI, DBI
=cut
