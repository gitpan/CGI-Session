#!/usr/bin/perl

# purge.pl,v 1.2 2005/02/11 08:13:32 sherzodr Exp

#
# This script can be installed as a cron-job to run at specific intervals
# to remove all expired session data from disk
#
use constant DSN        => 'driver:file';
use constant DSN_ARGS   => {};

use CGI::Session;

CGI::Session->find( DSN, sub {}, DSN_ARGS ) or die CGI::Session->errstr;
