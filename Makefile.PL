use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'CGI::Session',
    'VERSION_FROM'	=> 'Session.pm',
    'PREREQ_PM'		=> {
			"Digest::MD5" => undef, 
			"Data::Dumper" => undef
	},
	($] >= 5.005 ?
	(ABSTRACT => 'Perl extension for persistent session management in CGI applications',
    AUTHOR     => 'Sherzod B. Ruzmetov <sherzodr@cpan.org>') : ()),
);
