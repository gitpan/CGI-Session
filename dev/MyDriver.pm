package CGI::Session::MyDriver;

# this is a blueprint for you CGI::Session driver. 
use strict;
use vars qw($VERSION);
use base qw(CGI::Session CGI::Session::MD5);

# all other driver specific libraries go below
use Data::Dumper;


$VERSION = "1.1";


# DESTROY(): called by Perl each time an object is destroyed.
# You can do some driver specific cleanup here if you wish.
# But make sure this method is here so that AUTOLOAD doesn't bother
# looking for it. Too expensive!
sub DESTROY { 
	my ($self) = @_;

	my $sid = $self->id();
	
}



# store(): should store the hashref in the disk so it could
# be retrieved later via retrieve().
sub store {
	my ($self, $sid) = @_;

	my $options = $self->options();
	my $data = $self->raw_data();

	# encoding the session data with Data::Dumper
	my $d =  Data::Dumper->new([$data], ["data"]);

	# now store the $d->Dump(), or return undef

	return 1;
}



# retrieve(): should return a hashref that was previously saved 
# in the disk via store()
sub retrieve {
	my ($self, $sid) = @_;

	my $options = $self->options();	
	
	
	return $data;
}


# tear_down(): called when the session is needed to be deleted
# from the disk
sub tear_down {
	my ($self, $sid) = @_;

	# delete the session from the disk

	return 1;
}



1;



=pod

=head1 NAME

CGI::Session::MyDriver - Blueprint for CGI::Session driver

=head1 SYNOPSIS

	use CGI::Session::MyDriver;

	my $session = new CGI::Session::MyDriver( undef, {..} );

	my $sid = $session->id;
	....

=head1 DESCRIPTION

This is a blueprint for your driver code.

To be able to write your own drivers for L<CGI::Session>, please consult 
L<developer section|CGI::Session/DEVELOPER SECTION> of L<CGI::Session manual|CGI::Session>.

=head1 AUTHOR

Include your Full name <and@email.addr>

=head1 COPYRIGHT

This library is a free software. You and can modify and destribute
it under the same terms as Perl itself.

=head1 SEE ALSO

L<CGI::Session>, L<CGI::Session::File>, L<CGI::Session::DB_File>,
L<CGI::Session::MySQL>, L<Apache::Session>

=cut
