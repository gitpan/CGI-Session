package CGI::Session::MySQL;

use strict;

@CGI::Session::MySQL::ISA = ("CGI::Session", "CGI::Session::MD5");

foreach my $mod ( @CGI::Session::MySQL::ISA ) {
    eval "require $mod";
}

use Data::Dumper;
use Carp 'croak';
use DBI;
use Safe;


###########################################################################
######## CGI::Session::MySQL - for storing session data in MySQL tables####
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



# Globla variables
$CGI::Session::MySQL::VERSION    = "2.6";
$CGI::Session::MySQL::TABLE_NAME = 'sessions';

# Configuring Data::Dumper for our needs
$Data::Dumper::Indent   = 0;
$Data::Dumper::Purity   = 0;
$Data::Dumper::Useqq    = 1;
$Data::Dumper::Deepcopy = 0;



# MYSQL_db(): utility function. Returns database and lock handles
sub MYSQL_dbh {
    my ($self) = @_;

    # if we already have database handles, return them
    if ( $self->{_mysql_dbh} && $self->{_mysql_lckh} ) {
        return ( $self->{_mysql_dbh}, $self->{_mysql_lckh} );

    }

    # getting the options passed to the constructor
    my $option  = $self->options;

    my $dbh     = $option->{Handle};
    my $lckh    = $option->{LockHandle}     || $dbh;
    my $dsn     = $option->{DataSource};
    my $username= $option->{UserName};
    my $psswd   = $option->{Password};
    my $lcksn   = $option->{LockDataSource} || $dsn;
    my $lckuser = $option->{LockUserName}   || $username;
    my $lckpsswd= $option->{LockPassword}   || $psswd;

    # If we recieved already created handlers save and return them
    if ( $dbh && $lckh ) {
        $self->{_mysql_dbh}     = $dbh;
        $self->{_mysql_lckh}    = $lckh;
        return ($dbh, $lckh);

    }

    ($dsn && $username && $psswd) or croak "Refer to the CGI::Session::MySQL manual for the usage";

    # If we came this far, we're asked to create handlers

    $self->{_mysql_dbh}  = DBI->connect($dsn, $username, $psswd, {RaiseError=>0, PrintError=>0})
        or $self->error($DBI::errstr), return;

    $self->{_mysql_lckh} = DBI->connect($lcksn, $lckuser, $lckpsswd, {RaiseError=>0, PrintError=>0})
        or $self->error($DBI::errstr), return;

    # Let's set a flag that indicates that we need to disconnect
    # after we're done
    $self->{_mysql_disconnect} = 1;

    return ( $self->{_mysql_dbh}, $self->{_mysql_lckh} );
}





# So that CGI::Session's AUTOLOAD doesn't bother looking for it.
# Too expensive
sub DESTROY {
    my $self = shift;
    my $options = $self->options;

}




sub retrieve {
    my ($self, $sid) = @_;


    my ($dbh, $lckh) = $self->MYSQL_dbh() or return;

    # I wish row locking were possible in MySQL :-(
    $lckh->do("LOCK TABLES $CGI::Session::MySQL::TABLE_NAME READ");
    my ($tmp) = $dbh->selectrow_array("SELECT a_session FROM $CGI::Session::MySQL::TABLE_NAME WHERE id=?", undef, $sid);
    $lckh->do("UNLOCK TABLES");


    # Following line is to keep -T line happy. In fact it is an evil code,
    # that's why we'll be compiling $tmp under the restricted eval() later
    # to ensure it's indeed safe. If you have a better solution, please
    # take this burden of guilt off my conscious.
    ($tmp) = $tmp =~ m/^(.+)$/s;

    my $cpt = Safe->new("CGI::Session::MySQL::CPT");
    $cpt->reval($tmp);

    if ( $@ ) {
        $self->error("Couldn't eval() the data, $!"), return undef;
    }

    return $CGI::Session::MySQL::CPT::data;
}










sub store {
    my ($self, $sid) = @_;


    my ($dbh, $lckh) = $self->MYSQL_dbh();
    my $hashref = $self->raw_data();

    my $d = Data::Dumper->new([$hashref], ["data"]);
    my $exists = $dbh->selectrow_array("SELECT a_session FROM $CGI::Session::MySQL::TABLE_NAME WHERE id=?", undef, $sid);

    $lckh->do("LOCK TABLES $CGI::Session::MySQL::TABLE_NAME WRITE");

    if ( $exists ) {
        my $rv = $dbh->do("UPDATE $CGI::Session::MySQL::TABLE_NAME SET a_session=? WHERE id=?", undef, $d->Dump(), $sid);
        $lckh->do("UNLOCK TABLES");
        return $rv;
    }

    my $rv =  $dbh->do("INSERT INTO $CGI::Session::MySQL::TABLE_NAME SET id=?, a_session=?", undef, $sid, $d->Dump());
    $lckh->do("UNLOCK TABLES");
    return $rv;
}








sub tear_down {
    my ($self) = @_;

    my $sid = $self->id();
    my ($dbh, $lckh) = $self->MYSQL_dbh();
    my $option = $self->options();


    $lckh->do("LOCK TABLES $CGI::Session::MySQL::TABLE_NAME WRITE");
    my $rv =  $dbh->do("DELETE FROM $CGI::Session::MySQL::TABLE_NAME WHERE id=?", undef, $sid);
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
            LockHandle      => $dbh,
            Handle          => $dbh
        });


    # For examples see CGI::Session manual

=head1 DESCRIPTION

C<CGI::Session::MySQL> is the driver for the L<CGI::Session> class to store
and retrieve the session data in and from the MySQL database.

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
table. If it is not set should default to C<Handle>

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
you want to use a different name, just update $CGI::Session::MySQL::TABLE_NAME
variable before creating the object:

    use CGI::Session::MySQL;
    my DBI;

    $CGI::Session::MySQL::TABLE_NAME = 'my_sessions';
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
