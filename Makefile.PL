# $Id: Makefile.PL,v 3.3.2.4 2002/11/28 17:15:21 sherzodr Exp $

use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'CGI::Session',
    VERSION_FROM    => 'Session.pm',
    PREREQ_PM       => {
                    'Digest::MD5' => undef,
    },
    ABSTRACT        => 'Persistent session in CGI applications',
    AUTHOR          => 'Sherzod Ruzmetov <sherzodr@cpan.org>',
);


