use inc::Module::Install;

name     'Graphics-Primitive-Driver-Cairo';
all_from 'lib/Graphics/Primitive/Driver/Cairo.pm';
author   'Cory G Watson <gphat@cpan.org>';

build_requires 'Test::More';

test_requires 'File::Spec';

requires 'Cairo' => '1.060';
requires 'Moose' => '0.57';
requires 'IO::File';
requires 'Geometry::Primitive' => '0.12';
requires 'Graphics::Primitive' => '0.31';
requires 'Math::Complex' => '1.54';
requires 'Text::Flow' => '0.01';

WriteAll;

