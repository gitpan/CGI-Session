package CGI::Session::Postgres;

use 5.006;
use strict;
use warnings::register;
use Carp;

use vars qw($VERSION @ISA);

$VERSION = '0.01';
@ISA = qw(CGI::Session);

use CGI::Session;

eval "require Apache::Session::Postgres";

if ($@) {
    croak "Apache::Session::Postgres, which is a prerequisite could not be loaded. "
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
        tie %Session, 'Apache::Session::Postgres', $id, $attr
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

CGI::Session::Postgres - Font-end to Apache::Session::Postgres

=head1 SYNOPSIS

  use CGI::Session::Postgres;

  my $Session = new CG::Session::Postgres(undef, 
                {
                    Handle=>$dbh, 
                    Commit=>1
                });


=head1 DESCRIPTION


Refere to the documentatin of CGI::Session

=head1 AUTHOR

Sherzod B. Ruzmetov <sherzodr@cpan.org>

=head1 SEE ALSO

CGI::Session, CGI::Session::DB_File, CGI::Session::File, CGI::Session::DB_File, 
CGI::Session::MySQL, CGI::Session::Oracle, CGI::Session::Sybase, CGI::Session::Postgres,
Apache::Session, Apache::Session::Oracle, Apache::Session::MySQL, Apache::Session::Sybase, Apache::Postgres, Apache::Session::DB_File, Apache::Session::File, CGI, DBI

=cut
