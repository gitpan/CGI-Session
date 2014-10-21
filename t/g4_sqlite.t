# $Id: g4_sqlite.t 226 2005-11-17 08:14:53Z markstos $

use strict;
use diagnostics;

use File::Spec;
use Test::More;
use CGI::Session::Test::Default;
use Data::Dumper;

for ( "DBI", "DBD::SQLite" ) {
    eval "require $_";
    if ( $@ ) {
        plan(skip_all=>"$_ is NOT available");
        exit(0);
    }
}

my %dsn = (
    DataSource  => "dbi:SQLite:dbname=" . File::Spec->catfile('t', 'sessiondata', 'sessions.sqlt'),
    TableName   => 'sessions'
);

my $dbh = DBI->connect($dsn{DataSource}, undef, undef, {RaiseError=>1, PrintError=>1});
unless ( $dbh ) {
    plan(skip_all=>"Couldn't establish connection with the SQLite server");
    exit(0);
}

my %tables = map{ s/['"]//g; ($_, 1) } $dbh->tables();
unless ( exists $tables{ $dsn{TableName} } ) {
    unless( $dbh->do(qq|
        CREATE TABLE $dsn{TableName} (
            id CHAR(32) NOT NULL PRIMARY KEY,
            a_session TEXT NULL
        )|) ) {
        plan(skip_all=>"Couldn't create table $dsn{TableName}: " . $dbh->errstr);
        exit(0);
    }
}


my $t = CGI::Session::Test::Default->new(
    dsn => "driver:sqlite",
    args=>{Handle=> sub {$dbh}, TableName=>$dsn{TableName}});

plan tests => $t->number_of_tests;
$t->run();
