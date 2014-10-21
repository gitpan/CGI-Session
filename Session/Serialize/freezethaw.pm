package CGI::Session::Serialize::freezethaw;

# freezethaw.pm,v 1.4 2005/02/09 08:30:53 sherzodr Exp 

use strict;
#use diagnostics;

use FreezeThaw;

$CGI::Session::Serialize::freezethaw::VERSION = '1.4';

sub freeze {
    my ($self, $data) = @_;
    
    return FreezeThaw::freeze($data);
}



sub thaw {
    my ($self, $string) = @_;

    return (FreezeThaw::thaw($string))[0];
}


1;

__END__;

=pod

=head1 NAME

CGI::Session::Serialize::freezethaw - serializer for CGI::Session

=head1 DESCRIPTION

This library can be used by CGI::Session to serialize session data. Uses L<FreezeThaw|FreezeThaw>.

=head1 METHODS

=over 4

=item freeze($class, \%hash)

Receives two arguments. First is the class name, the second is the data to be serialized.
Should return serialized string on success, undef on failure. Error message should be set using
C<set_error()|CGI::Session::ErrorHandler/"set_error()">

=item thaw($class, $string)

Received two arguments. First is the class name, second is the I<frozen> data string. Should return
thawed data structure on success, undef on failure. Error message should be set 
using C<set_error()|CGI::Session::ErrorHandler/"set_error()">

=back

=head1 LICENSING

For support and licensing see L<CGI::Session|CGI::Session>

=cut
