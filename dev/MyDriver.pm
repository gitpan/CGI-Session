package CGI::Session::MyDriver;

# this is a blueprint for you CGI::Session driver. 
use strict;
use vars qw($VERSION);
use base qw(CGI::Session CGI::Session::MD5);

# all other driver specific libraries go below
use Data::Dumper;


$VERSION = "1.0";



# DESTROY() is required so that  AUTOLOAD doesn't keep looking for
# it. Too expensive
sub DESTROY { }


sub store {
	my ($self, $sid, $hashref, $options) = @_;

	# encoding the session data with Data::Dumper
	my $d =  Data::Dumper->new([$hashref], ["data"]);

	# now store the $d->Dump(), or return undef

	return 1;
}



sub retrieve {
	my ($self, $sid, $options) = @_;

	
	# here you retrieve the above stored data.
	# If you used Data::Dumper, and assuming you loaded it into $tmp variable:
	my ($data, $tmp);
	eval $tmp;

	if ( $@ ) {
		$self->error($@), return undef;
	}

	return $data;
}


sub tear_down {
	my ($self, $sid, $options) = @_;

	# delete the session from the disk

	return 1;
}

1;

__END__

=head1 NAME

CGI::Session::MyDriver - Perl extension for  CGI::Session driver

=head1 SYNOPSIS

	use CGI::Session::MyDriver;

	my $session = new CGI::Session::MyDriver( undef, {..} );

	my $sid = $session->id;
	....

=head1 DESCRIPTION

This is a blueprint for your driver code. 

=head1 AUTHOR

Include your Full name <and@email.addr>

=head1 COPYRIGHT

This library is a free software, and can be modified and destributed
under the same terms as Perl itself. 

=head1 SEE ALSO

L<CGI::Session>, L<CGI::Session::File>, L<CGI::Session::DB_File>,
L<CGI::Session::MySQL>, L<Apache::Session>

=cut
