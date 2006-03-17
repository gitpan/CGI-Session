package CGI::Session::Query;

# $Id$

use strict;

#sub AUTOLOAD {
#    my $self = shift;
#    my ($pkg_name, $method_name) = $CGI::Session::Query::AUTOLOAD =~ m/^(.+)::([^:]+)$/;
#    if ( defined(my $query = $self->{query}) && ($self->can($method_name)) ) {
#        return $query->$method_name(@_);
#    }
#}


sub new {
    my $class = shift;
    $class = ref( $class ) || $class;

    my %self = (
        mod_perl    => $ENV{MOD_PERL} || 0,
        query       => undef,
    );

    if ( $self{mod_perl} ) {
        require Apache;
        require Apache::Request;
        $self{query} = Apache::Request->instance( Apache->request );
    }
    else {
        require CGI;
        $self{query} = CGI->new();
    }
    return bless (\%self, $class);
}


#
# This one is the easiest, because Apache::Request::param() is somewhat 
# compatible with CGI::param()
#
sub param {
    my $self = shift;
    return $self->{query}->param(@_);
}

#
# Merger of CGI::Cookie and Apache::Cookie
#
sub cookie {
    my $self = shift;

    unless ( $self->{mod_perl} ) {
        return $self->{query}->cookie( @_ );
    }

    # 
    # If we reach this far, we're running under mod_perl
    #
    require Apache::Cookie;
    if ( @_ == 1 ) {
        my $cookies = Apache::Cookie->new( Apache->request )->parse();
        if ( my $cookie = $cookies->{ $_[0] } ) {
            return $cookie->value();
        }
        return undef;
    }
    return Apache::Cookie->new( Apache->request, @_);
}



#
# Merger of CGI::header() and Apache::send_http_header() methods
#
sub header {
    my $self = shift;

    unless ( $self->{mod_perl} ) {
        return $self->{query}->header(@_);
    }

    #
    # If we reach this far, we're running under mod_perl
    #
    my %args = (
        '-type'     => 'text/html',
        '-cookie'   => undef,
        @_
    );

    if ( defined(my $cookie = $args{'-cookie'}) ) {
        $cookie->bake;
    }

    $self->{query}->send_http_header( $args{'-type'} );
}





1;
