package CGI::Session::DB_File;

use 5.006;
use strict;
use warnings::register;
use Carp;

use vars qw($VERSION @ISA);

$VERSION = '0.01';
@ISA = qw(CGI::Session);

use CGI::Session;

eval "require Apache::Session::DB_File";

if ($@) {
    croak "Apache::Session::DB_File, which is a prerequisite could not be loaded. "
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
        tie %Session, 'Apache::Session::DB_File', $id, $attr
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

CGI::Session::DB_File - Font-end to Apache::Session::DB_File

=head1 SYNOPSIS

  use CGI::Session::DB_File;

  my $Session = new CG::Session::DB_File(File=>'somedb.db', LockDir=>'some.db');


=head1 DESCRIPTION


For more information, please read the documentation of CGI::Session

=head1 AUTHOR

Sherzod B. Ruzmetov <sherzodr@cpan.org>

=head1 SEE ALSO


CGI::Session, CGI::Session::DB_File, CGI::Session::File, CGI::Session::DB_File, 
CGI::Session::MySQL, CGI::Session::Oracle, CGI::Session::Sybase, CGI::Session::Postgres,
Apache::Session, Apache::Session::Oracle, Apache::Session::MySQL, Apache::Session::Sybase, Apache::Postgres, Apache::Session::DB_File, Apache::Session::File, CGI, DBI
=cut
