use strict;
use warnings;

use File::Spec::Functions;

use Graphics::Primitive::Component;
use Graphics::Primitive::Driver::Cairo;
use Graphics::Color::RGB;
use Test::More tests => 1;

eval "use Test::Image::GD";
plan skip_all => "Test::Image::GD required for testing output testing"
    if $@;

my $path_to_ofile = catdir('t', 'osimple-border.png');
my $path_to_file = catdir('t', 'images', 'simple-border.png');

my $comp = Graphics::Primitive::Component->new(
    background_color => Graphics::Color::RGB->new(red => 1, green => 1, blue => 1, alpha => 1),
    width => 100,
    height => 100
);
my $black = Graphics::Color::RGB->new(red => 0, green => 0, blue => 0, alpha => 1);

$comp->border->color($black);
$comp->border->width(4);

my $driver = Graphics::Primitive::Driver::Cairo->new(format => 'PNG');
$driver->prepare($comp);
$driver->pack($comp);
$driver->draw($comp);
$driver->write($path_to_ofile);

cmp_image($path_to_ofile, $path_to_file, 'simple border');

unlink($path_to_ofile);

