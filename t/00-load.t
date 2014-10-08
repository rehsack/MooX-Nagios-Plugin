#!perl

use Test::More tests => 2;
use lib 't/lib';

BEGIN {
    use_ok( 'mxNagLdr' ) || BAIL_OUT "Couldn't load mxNagLdr";
    use_ok( 'Types::Tiny::Thresholds' ) || BAIL_OUT "Couldn't load Types::Tiny::Thresholds";
}

diag( "Testing MooX::Nagios::Plugin $MooX::Nagios::Plugin::VERSION, Perl $], $^X" );
diag( "Testing Types::Tiny::Thresholds $Types::Tiny::Thresholds::VERSION, Perl $], $^X" );
