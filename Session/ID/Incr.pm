package CGI::Session::ID::Incr;

# $Id: Incr.pm,v 3.0 2002/11/27 01:48:29 sherzodr Exp $

use strict;
use File::Spec;
use Carp "croak";
use Fcntl (':DEFAULT', ':flock');

use vars qw($VERSION);

($VERSION) = '$Revision: 3.0 $' =~ m/Revision:\s*(\S+)/;

sub generate_id {
    my ($self, $options) = @_;

    my $IDFile = $options->[1]->{IDFile} or croak "Don't know where to store the id";
    my $IDIncr = $options->[1]->{IDIncr} || 1;
    my $IDInit = $options->[1]->{IDInit} || 0;
    
    unless (sysopen(FH, $IDFile, O_RDWR|O_CREAT, 0644) ) {
        $self->error("Couldn't open IDFile=>$IDFile: $!");
        return undef;
    }
    unless (flock(FH, LOCK_EX) ) {
        $self->error("Couldn't lock IDFile=>$IDFile: $!");
        return undef;
    }
    my $ID = <FH> || $IDInit;
    unless ( seek(FH, 0, 0) ) {
        $self->error("Couldn't seek IDFile=>$IDFile: $!");
        return undef;
    }
    unless ( truncate(FH, 0) ) {
        $self->error("Couldn't trunated IDFile=>$IDFile: $!");
        return undef;
    }
    $ID += $IDIncr;
    print FH $ID;
    unless ( close(FH) ) {
        $self->error("Couldn't close IDFile=>$IDFile: $!");
        return undef;
    }

    return $ID;
} 


1;

=pod

=head1 NAME 

CGI::Session::ID::Incr - CGI::Session ID driver

=head1 DESCRIPTION

CGI::Session::ID::Incr is to generate incremental Session IDs. Compare it with 
CGI::Session::ID::MD5, where session ids are truely random, 32 bit long strings.

CGI::Session::ID::Incr expects the following arguments passed to CGI::Session->new()
as the second argument:

=over 4

=item "IDFile"

Location where auto incremened IDs are stored. This argument is required.

=item "IDInit"

Initial value of the ID if it's the first ID to be generated. For example, if you want
the ID numbers to start with 1000 as opposed to 0, that's where you should set your value.
This attribute is optional. Default is 0.

=item "IDIncr"

How many digits each number should increment to. For example, if you want the first generated id
to start with 1000, and each subsequent id to increment to 10, set 'IDIncr' to '10'. Default is 1.

=back


=head1 COPYRIGHT

Copyright (C) 2002 Sherzod Ruzmetov. All rights reserved.

This library is free software, and can be distributed under the same terms as Perl itself.

=head1 AUTHOR

Sherzod Ruzmetov <sherzodr@cpan.org>

=head1 SEE ALSO

=over 4

=item *

L<CGI::Session|CGI::Session> - CGI::Session manual

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

