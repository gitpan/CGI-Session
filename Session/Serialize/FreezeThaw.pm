package CGI::Session::Serialize::FreezeThaw;

# $Id: FreezeThaw.pm,v 1.3.2.1 2002/11/28 03:42:14 sherzodr Exp $ 
use strict;
use FreezeThaw;

use vars qw($VERSION);

($VERSION) = '$Revision: 1.3.2.1 $' =~ m/Revision:\s*(\S+)/;


sub freeze {
    my ($self, $data) = @_;
    
    return FreezeThaw::freeze($data);
}



sub thaw {
    my ($self, $string) = @_;

    return (FreezeThaw::thaw($string))[0];
}


1;

=pod

=head1 NAME

CGI::Session::Serialize::FreezeThaw - serializer for CGI::Session

=head1 SYNOPSIS

	use CGI::Session qw/-api3/;
	$session = new CGI::Session("serializer:FreezeThaw", undef, \%attrs);

=head1 DESCRIPTION

This library is used by CGI::Session driver to serialize session data before storing it in disk. Uses FreezeThaw.

=head1 COPYRIGHT

Copyright (C) 2002 Sherzod Ruzmetov. All rights reserved.

This library is free software. It can be distributed under the same terms as Perl itself. 

=head1 AUTHOR

Sherzod Ruzmetov <sherzodr@cpan.org>

All bug reports should be directed to Sherzod Ruzmetov <sherzodr@cpan.org>. 

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

