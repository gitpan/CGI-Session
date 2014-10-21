package CGI::Session::ErrorHandler;

# $Id: ErrorHandler.pm,v 3.4 2005/02/09 08:30:38 sherzodr Exp $

use strict;
#use diagnostics;

$CGI::Session::ErrorHandler::VERSION = "4.00";

sub set_error {
    my $class = shift;
    $class = ref($class) || $class;
    no strict 'refs';
    ${ "$class\::errstr" } = $_[0] || "";
    return undef;
}


*error = \&errstr;
sub errstr {
    my $class = shift;
    $class = ref( $class ) || $class;

    no strict 'refs';
    return ${ "$class\::errstr" };
}

1;

__END__;

=pod

=head1 NAME

CGI::Session::ErrorHandler - error handling routines for CGI::Session

=head1 SYNOPSIS

    require CGI::Session::ErrorHandler
    @ISA = qw( CGI::Session::ErrorHandler );


    sub some_method {
        my $self = shift;
        unless (  $some_condition ) {
            return $self->set_error("some_method(): \$some_condition isn't met");
        }
    }


=head1 DESCRIPTION

CGI::Session::ErrorHandler provides set_error() and errstr() methods for setting and accessing error messages from within 
CGI::Session's components. This method should be used by driver developers for providing CGI::Session-standard error 
handling routines for their code

=head2 METHODS

=over 4

=item set_error( $message )

Implicitly defines $pkg_name::errstr and sets its value to $message. Return value is B<always> undef.

=item errstr()

Returns whatever value was set by the most recent call to set_error().

=back

=head1 LICENSING

For support and licensing information see L<CGI::Session|CGI::Session>.

=cut
