package CGI::Session::Example;

# $Id: Example.pm,v 1.1.2.1 2003/03/09 11:20:34 sherzodr Exp $

use strict;
use diagnostics;
use File::Spec;
use base 'CGI::Application';


# look into CGI::Application for the details of setup() method
sub setup {
  my $self = shift;

  $self->mode_param(\&parsePathInfo);  
  $self->run_modes(
    start => \&default,
  );

  # setting up default HTTP header. See the details of query() and
  # header_props() methods in CGI::Application manpage
  my $cgi = $self->query();
  my $session = $self->session();
  my $sid_cookie = $cgi->cookie($session->name(), $session->id());
  $self->header_props(-type=>'text/html', -cookie=>$sid_cookie);
}




# this method simply returns CGI::Session object.
sub session {
  my $self = shift;

  if ( defined $self->param("_SESSION") ) {
    return $self->param("_SESSION");
  }
  require CGI::Session;
  my $dsn = $self->param("_SESSION_DSN") || undef;
  my $options = $self->param("_SESSION_OPTIONS") || {Directory=>File::Spec->tmpdir};
  my $session = CGI::Session->new($dsn, $self->query, $options);  
  unless ( defined $session ) {
    die CGI::Session->error();
  }  
  $self->param(_SESSION => $session);
  return $self->session();
}

# parses PATH_INFO and retrieves a portion which defines a run-mode
# to be executed to display the current page. Refer to CGI::Application
# manpage for details of run-modes and mode_param() method
sub parsePathInfo {
  my $self = shift;

  unless ( defined $ENV{PATH_INFO} ) {
    return;
  }
  my ($cmd) = $ENV{PATH_INFO} =~ m!/cmd/-/([^?]+)!;
  return $cmd;
}


# see CGI::Application manpage
sub teardown {
  my $self = shift;

  my $session = $self->param("_SESSION");
  if ( defined $session ) {
    $session->close();
  }
}





# overriding CGI::Application's load_tmpl() method. It doesn't
# return an HTML object, but the contents of the HTML template
sub load_tmpl {
  my ($self, $filename, $args) = @_;

  # defining a default param set for the templates
  $args ||= {};
  my $cgi     = $self->query();
  my $session = $self->session();
  # making all the %ENV variables available for all the templates
  map { $args->{$_} = $ENV{$_} } keys %ENV;  
  # making session  id available for all the templates
  $args->{ $session->name() } = $session->id;
  # loading the template
  require HTML::Template;
  my $t = new HTML::Template(filename                    => $filename,
                             associate                   => [$session, $cgi],
                             vanguard_compatibility_mode => 1);
  $t->param(%$args);
  return $t->output();
}




sub page {
  my ($self, $body) = @_;

  my %params = (
    body => $body
  );
  return $self->load_tmpl('page.html', \%params);
}




# Application methods
sub default {
  my $self = shift;

  my $session = $self->session();
  my $body =  sprintf("Hello <b>%s</b>", $session->id);
  return $self->page($body);
}







1;

__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Some::Module - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Some::Module;
  blah blah blah

=head1 ABSTRACT

  This should be the abstract for Some::Module.
  The abstract is used when making PPD (Perl Package Description) files.
  If you don't want an ABSTRACT you should also edit Makefile.PL to
  remove the ABSTRACT_FROM option.

=head1 DESCRIPTION

Stub documentation for Some::Module, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

A. U. Thor, E<lt>sherzodr@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
