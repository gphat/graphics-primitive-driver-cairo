use inc::Module::Install;

name     'Graphics-Primitive-Driver-Cairo';
all_from 'lib/Graphics/Primitive/Driver/Cairo.pm';
author   'Cory G Watson <gphat@cpan.org>';

build_requires 'Test::More';

test_requires 'Pod::Coverage::Moose';

requires 'IO::File';
requires 'Graphics::Primitive' => '0.6';

auto_install;

WriteAll;

