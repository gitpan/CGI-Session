package CGI::Session::MD5;

use strict;
use Carp;
use vars qw($VERSION);

eval "require Digest::MD5";
if ( $@ ) {
    croak "Dependency detected: Digest::MD5 module needs to be installed in the system";
}

srand( time ^ ($$ + ($$ << 15)) );

sub generate_id {
	my $self = shift;

	my $digest = new Digest::MD5;
	$digest->add(rand(9999), time(), $$);

    my $id = $digest->b64digest();

	$id =~ s/\W/-/g;

	return $id;
}

1;


=pod

=head1 NAME

CGI::Session::MD5 - provides default C<generate_id()> method for CGI::Session

=head1 SYNOPSIS

	my $session_id = $self->generate_id()

=head1 DESCRIPTION
	
You normaly do not have to use it. It will be called by L<CGI::Session|CGI::Session>
whenever a new session identifier is required. But if you want, you can 
override the default C<generate_id()>. ( see L<developer section|CGI::Session/DEVELOPER SECTION>
of the L<CGI::Session manual|CGI::Session>)

=head1 AUTHOR

	Sherzod B. Ruzmetov <sherzodr@cpan.org>

=head1 COPYRIGHT

	This library is a free software. You can modify and/or redistribute it
	under the same terms as Perl itself

=head1 SEE ALSO

L<CGI::Session>, L<CGI::Session::File>, L<CGI::Sessino::DB_File>,
L<CGI::Session::MySQL>

=cut

