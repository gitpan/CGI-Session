package CGI::Session::File;

use 5.006;
use strict;
use warnings::register;
use Carp;

use vars qw($VERSION @ISA);

$VERSION = '0.01';
@ISA = qw(CGI::Session);

use CGI::Session;

eval "require Apache::Session::File";

if ($@) {
    croak "Apache::Session::File, which is a prerequisit could not be loaded. "
         ."You have to have this module installed in the system before "
         ."being able to use CGI::Session.\nError message was: $@";
}


# Usage:
#   CGI::Session::DB_File->new(undef, \%attr);
sub new {
    my ($class, $id, $attr) = @_;
    $class = ref ($class) || $class;

    my %Session;
    eval {
        tie %Session, 'Apache::Session::File', $id, $attr
    };

    if ($@) {
        if (warnings::enabled) {
            carp __PACKAGE__ . " object couldn't be created";
        }
    }

    return bless \%Session => $class;
}




sub DESTROY { untie %{$_[0]} };



1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

CGI::Session::File - Front-end to Apache::Session::File

=head1 SYNOPSIS

  use CGI::Session::File;

  my $Session = new CG::Session::File(undef, 
                {
                    Directory=>'/tmp/sessions', 
                    LockDirectory=>'/var/lock/sessions'
                });


=head1 DESCRIPTION


Refer to the documenation of CGI::Session

=head2 EXPORT


=head1 AUTHOR

Sherzod B. Ruzmetov <sherzodr@cpan.org>

=head1 SEE ALSO


CGI::Session, CGI::Session::DB_File, CGI::Session::File, CGI::Session::DB_File, 
CGI::Session::MySQL, CGI::Session::Oracle, CGI::Session::Sybase, CGI::Session::Postgres,
Apache::Session, Apache::Session::Oracle, Apache::Session::MySQL, Apache::Session::Sybase, Apache::Postgres, Apache::Session::DB_File, Apache::Session::File, CGI, DBI
=cut
