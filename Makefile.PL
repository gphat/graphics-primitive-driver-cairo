use inc::Module::Install;

name     'Graphics-Primitive-Driver-Cairo';
all_from 'lib/Graphics/Primitive/Driver/Cairo.pm';
author   'Cory G Watson <gphat@cpan.org>';

build_requires 'Test::More';

test_requires 'Pod::Coverage::Moose';

requires 'Cairo' => '1.060';
requires 'Moose' => '0.54';
requires 'IO::File';
requires 'Geometry::Primitive' => '0.08';
requires 'Graphics::Primitive' => '0.13';

auto_install;

WriteAll;

