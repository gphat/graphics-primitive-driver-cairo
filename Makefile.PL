use inc::Module::Install;

name     'Graphics-Primitive-Driver-Cairo';
all_from 'lib/Graphics/Primitive/Driver/Cairo.pm';
author   'Cory G Watson <gphat@cpan.org>';

build_requires 'Test::More';

test_requires 'File::Spec';

requires 'Cairo' => '1.061';
requires 'Moose' => '0.76';
requires 'IO::File';
requires 'Geometry::Primitive' => '0.13';
requires 'Graphics::Primitive' => '0.45';
requires 'Math::Complex' => '1.56';
requires 'Text::Flow' => '0.01';

WriteAll;

