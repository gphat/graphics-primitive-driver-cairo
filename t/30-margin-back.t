use strict;
use warnings;

use File::Spec::Functions;

use Graphics::Primitive::Component;
use Graphics::Primitive::Driver::Cairo;
use Graphics::Color::RGB;
use Test::More;

eval "use Test::PDF";
plan skip_all => "Test::PDF required for testing output testing"
    if $@;

plan tests => 1;

my $path_to_ofile = catdir('t', 'omargin-back.pdf');
my $path_to_file = catdir('t', 'images', 'margin-back.pdf');

my $comp = Graphics::Primitive::Component->new(
    background_color => Graphics::Color::RGB->new(red => 1, green => 1, blue => 1, alpha => 1),
    width => 100,
    height => 100
);
my $black = Graphics::Color::RGB->new(red => 0, green => 0, blue => 0, alpha => 1);

$comp->border->color($black);
$comp->margins->width(4);
$comp->border->width(4);

my $driver = Graphics::Primitive::Driver::Cairo->new(format => 'pdf');
$driver->prepare($comp);
$driver->finalize($comp);
$driver->draw($comp);
$driver->write($path_to_ofile);

cmp_pdf($path_to_ofile, $path_to_file, 'margin w/background');

unlink($path_to_ofile);

