package CGI::Session::ID::MD5;

# $Id: MD5.pm,v 3.0 2002/11/27 01:48:29 sherzodr Exp $

use strict;
use Digest::MD5;
use vars qw($VERSION);

($VERSION) = '$Revision: 3.0 $' =~ m/Revision:\s*(\S+)/;

sub generate_id {
    my $self = shift;

    my $md5 = new Digest::MD5();
    $md5->add($$ , time() , rand(9999) );

    return $md5->hexdigest();
}


1;


