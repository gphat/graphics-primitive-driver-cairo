#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Graphics::Primitive::Driver::Cairo' );
}

diag( "Testing Graphics::Primitive::Driver::Cairo $Graphics::Primitive::Driver::Cairo::VERSION, Perl $], $^X" );
