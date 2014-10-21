package CGI::Session::Driver::file;

# $Id: /local/cgi-session/trunk/lib/CGI/Session/Driver/file.pm 274 2006-03-02T02:53:47.269550Z mark  $

use strict;

use Carp;
use File::Spec;
use Fcntl qw( :DEFAULT :flock :mode );
use CGI::Session::Driver;
use vars qw( $FileName $NoFlock );

BEGIN {
    # keep historical behavior

    no strict 'refs';
    
    *FileName = \$CGI::Session::File::FileName;
}

@CGI::Session::Driver::file::ISA        = ( "CGI::Session::Driver" );
$CGI::Session::Driver::file::VERSION    = "3.6";
$FileName                               = "cgisess_%s";
$NoFlock                                = 0;

sub init {
    my $self = shift;
    $self->{Directory} ||= File::Spec->tmpdir();

    unless ( -d $self->{Directory} ) {
        require File::Path;
        unless ( File::Path::mkpath($self->{Directory}) ) {
            return $self->set_error( "init(): couldn't create directory path: $!" );
        }
    }
    
    $self->{NoFlock} = $NoFlock unless exists $self->{NoFlock};
    
    return 1;
}

sub retrieve {
    my $self = shift;
    my ($sid) = @_;

    my $directory   = $self->{Directory};
    my $file        = sprintf( $FileName, $sid );
    my $path        = File::Spec->catfile($directory, $file);

    return 0 unless -e $path;

    # make certain our filehandle goes away when we fall out of scope
    local *FH;

    sysopen(FH, $path, O_RDONLY) || return $self->set_error( "retrieve(): couldn't open '$path': $!" );
    $self->{NoFlock} || flock(FH, LOCK_SH) or return $self->set_error( "retrieve(): couldn't lock '$path': $!" );

    my $rv = "";
    while ( <FH> ) {
        $rv .= $_;
    }
    close(FH);
    return $rv;
}



sub store {
    my $self = shift;
    my ($sid, $datastr) = @_;
    
    my $directory = $self->{Directory};
    my $file      = sprintf( $FileName, $sid );
    my $path      = File::Spec->catfile($directory, $file);
    
    # make certain our filehandle goes away when we fall out of scope
    local *FH;
    
    sysopen(FH, $path, O_WRONLY|O_CREAT) or return $self->set_error( "store(): couldn't open '$path': $!" );
    # prevent race condition (RT#17949)
    truncate(FH, 0)  or return $self->set_error( "store(): couldn't truncate '$path': $!" );
    $self->{NoFlock} || flock(FH, LOCK_EX)  or return $self->set_error( "store(): couldn't lock '$path': $!" );

    print FH $datastr;
    close(FH)               or return $self->set_error( "store(): couldn't close '$path': $!" );
    return 1;
}


sub remove {
    my $self = shift;
    my ($sid) = @_;

    my $directory = $self->{Directory};
    my $file      = sprintf( $FileName, $sid );
    my $path      = File::Spec->catfile($directory, $file);
    unlink($path) or return $self->set_error( "remove(): couldn't unlink '$path': $!" );
    return 1;
}


sub traverse {
    my $self = shift;
    my ($coderef) = @_;

    unless ( $coderef && ref($coderef) && (ref $coderef eq 'CODE') ) {
        croak "traverse(): usage error";
    }

    opendir( DIRHANDLE, $self->{Directory} ) 
        or return $self->set_error( "traverse(): couldn't open $self->{Directory}, " . $! );

    my $filename_pattern = $FileName;
    $filename_pattern =~ s/\./\\./g;
    $filename_pattern =~ s/\%s/(\.\+)/g;
    while ( my $filename = readdir(DIRHANDLE) ) {
        next if $filename =~ m/^\.\.?$/;
        my $full_path = File::Spec->catfile($self->{Directory}, $filename);
        my $mode = (stat($full_path))[2] 
            or return $self->set_error( "traverse(): stat failed for $full_path: " . $! );
        next if S_ISDIR($mode);
        if ( $filename =~ /^$filename_pattern$/ ) {
            $coderef->($1);
        }
    }
    closedir( DIRHANDLE );
    return 1;
}


sub DESTROY {
    my $self = shift;
}

1;

__END__;

=pod

=head1 NAME

CGI::Session::Driver::file - Default CGI::Session driver

=head1 SYNOPSIS

    $s = new CGI::Session();
    $s = new CGI::Session("driver:file", $sid);
    $s = new CGI::Session("driver:file", $sid, {Directory=>'/tmp'});


=head1 DESCRIPTION

When CGI::Session object is created without explicitly setting I<driver>, I<file> will be assumed.
I<file> - driver will store session data in plain files, where each session will be stored in a separate
file.

Naming conventions of session files are defined by C<$CGI::Session::Driver::file::FileName> global variable. 
Default value of this variable is I<cgisess_%s>, where %s will be replaced with respective session ID. Should
you wish to set your own FileName template, do so before requesting for session object:

    $CGI::Session::Driver::file::FileName = "%s.dat";
    $s = new CGI::Session();

For backwards compatibility with 3.x, you can also use the variable name
C<$CGI::Session::File::FileName>, which will override the one above. 

=head2 DRIVER ARGUMENTS

The only optional argument for I<file> is B<Directory>, which denotes location of the directory where session ids are
to be kept. If B<Directory> is not set, defaults to whatever File::Spec->tmpdir() returns. So all the three lines
in the SYNOPSIS section of this manual produce the same result on a UNIX machine.

If specified B<Directory> does not exist, all necessary directory hierarchy will be created.

=head1 NOTES

If your OS doesn't support flock, you should understand the risks of going without locking the session files. Since
sessions tend to be used in environments where race conditions may occur due to concurrent access of files by 
different processes, locking tends to be seen as a good and very necessary thing. If you still want to use this 
driver but don't want flock, set C<$CGI::Session::Driver::file::NoFlock> to 1 or pass C<< NoFlock => 1 >> and this 
driver will operate without locks.

=head1 LICENSING

For support and licensing see L<CGI::Session|CGI::Session>

=cut
