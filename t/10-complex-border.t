use strict;
use warnings;

use File::Spec::Functions;

use Graphics::Primitive::Component;
use Graphics::Primitive::Driver::Cairo;
use Graphics::Color::RGB;
use Test::More;

eval "use Test::PDF";
plan skip_all => "(DISABLED) Test::PDF required for testing output testing";
# plan tests => 1;

my $path_to_ofile = catdir('t', 'ocomplex-border.pdf');
my $path_to_file = catdir('t', 'images', 'complex-border.pdf');

my $comp = Graphics::Primitive::Component->new(
    background_color => Graphics::Color::RGB->new(red => 1, green => 1, blue => 1, alpha => 1),
    width => 100,
    height => 100
);
my $red = Graphics::Color::RGB->new(red => 1, green => 0, blue => 0, alpha => 1);
my $blue = Graphics::Color::RGB->new(red => 0, green => 1, blue => 0, alpha => 1);
my $green = Graphics::Color::RGB->new(red => 0, green => 0, blue => 1, alpha => 1);
my $black = Graphics::Color::RGB->new(red => 0, green => 0, blue => 0, alpha => 1);

$comp->border->left->color($red);
$comp->border->right->color($blue);
$comp->border->top->color($green);
$comp->border->bottom->color($black);

$comp->border->left->width(4);
$comp->border->right->width(4);
$comp->border->top->width(6);
$comp->border->bottom->width(8);

my $driver = Graphics::Primitive::Driver::Cairo->new(format => 'pdf');
$driver->prepare($comp);
$driver->finalize($comp);
$driver->draw($comp);
$driver->write($path_to_ofile);

cmp_pdf($path_to_ofile, $path_to_file, 'complex border');

unlink($path_to_ofile);

