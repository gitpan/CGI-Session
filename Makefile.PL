use ExtUtils::MakeMaker;
# $Id: Makefile.PL,v 2.94 2002/08/26 08:07:22 sherzodr Exp $
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'CGI::Session',
    'VERSION_FROM'  => "Session.pm",
    'PREREQ_PM'     => {
            "Digest::MD5" => undef,
            "Data::Dumper" => undef
    },
    ($] >= 5.005 ?
    (ABSTRACT => 'Persistent storage of complex data in CGI',
    AUTHOR     => 'Sherzod B. Ruzmetov <sherzodr@cpan.org>') : ()),
);

