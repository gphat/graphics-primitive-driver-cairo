package Graphics::Primitive::Driver::Cairo;
use Moose;
use Moose::Util::TypeConstraints;

use Cairo;
use Carp;
use IO::File;

extends 'Graphics::Primitive::Driver';

enum 'Graphics::Primitive::Driver::Cairo::Format' => (
    'PDF', 'PS', 'PNG', 'SVG'
);

has 'cairo' => (
    is => 'rw',
    isa => 'Cairo::Context',
    clearer => 'clear_cairo'
);
has 'format' => (
    is => 'ro',
    isa => 'Graphics::Primitive::Driver::Cairo::Format',
    default => sub { 'PNG' }
);
has 'surface' => (
    is => 'rw',
    clearer => 'clear_surface'
);
has 'surface_data' => (
    metaclass => 'String',
    is => 'rw',
    isa => 'Str',
    default => sub { '' },
    provides => {
        append => 'append_surface_data'
    },
);

our $AUTHORITY = 'cpan:GPHAT';
our $VERSION = '0.01';

sub data {
    my ($self) = @_;

    return $self->surface_data;
}

sub init {
    my ($self, $comp) = @_;

    my $surface;
    if($self->format eq 'PNG') {
        $surface = Cairo::ImageSurface->create(
            'argb32', $comp->width, $comp->height
        );
    } elsif($self->format eq 'PDF') {
        croak('Your Cairo does not have PostScript support!')
            unless Cairo::HAS_PDF_SURFACE;
        $surface = Cairo::PdfSurface->create_for_stream(
            $self->can('append_surface_data'), $self, $comp->width, $comp->height
        );
    } elsif($self->format eq 'PS') {
        croak('Your Cairo does not have PostScript support!')
            unless Cairo::HAS_PS_SURFACE;
        $surface = Cairo::PsSurface->create_for_stream(
            $self->can('append_surface_data'), $self, $comp->width, $comp->height
        );
    } elsif($self->format eq 'SVG') {
        croak('Your Cairo does not have SVG support!')
            unless Cairo::HAS_SVG_SURFACE;
        $surface = Cairo::SvgSurface->create_for_stream(
            $self->can('append_surface_data'), $self, $comp->width, $comp->height
        );
    } else {
        croak("Unknown format '".$self->format."'");
    }
    $self->surface($surface);
    $self->cairo(Cairo::Context->create($self->surface));
}

sub write {
    my ($self, $file) = @_;

    my $cr = $self->cairo;

    if($self->format eq 'PNG') {
        $cr->get_target->write_to_png($file);
        return;
    }

    $cr->show_page;

    $cr = undef;
    $self->clear_cairo;
    $self->clear_surface;

    my $fh = IO::File->new($file, 'w')
        or die("Unable to open '$file' for writing: $!");
    $fh->binmode(1);
    $fh->print($self->surface_data);
    $fh->close;
}

sub _draw_component {
    my ($self, $comp) = @_;

    #TODO Hmmmm...
    if(!defined($self->cairo)) {
        $self->init($comp);
    }

    my $width = $comp->width;
    my $height = $comp->height;

    my $context = $self->cairo;

    if(defined($comp->background_color)) {
        $context->set_source_rgba($comp->background_color->as_array_with_alpha());
        $context->rectangle(0, 0, $width, $height);
        $context->paint();
    }

    my $bwidth = $width;
    my $bheight = $height;

    my $margins = $comp->margins();
    my ($mx, $my, $mw, $mh) = (0, 0, 0, 0);
    if($margins) {
        $mx = $margins->left();
        $my = $margins->top();
        $mw = $margins->right();
        $mh = $margins->bottom();
    }

    if(defined($comp->border())) {
        my $stroke = $comp->border();
        my $bswidth = $stroke->width();
        if(defined($comp->border->color)) {
            $context->set_source_rgba($comp->border->color->as_array_with_alpha());
        }
        $context->set_line_width($bswidth);
        $context->set_line_cap($stroke->line_cap());
        $context->set_line_join($stroke->line_join());
        $context->new_path();
        my $swhalf = $bswidth / 2;
        $context->rectangle(
            $mx + $swhalf, $my + $swhalf,
            $width - $bswidth - $mw - $mx, $height - $bswidth - $mh - $my
        );
        $context->stroke();
    }
}

no Moose;
1;
__END__

=head1 NAME

Graphics::Primitive::Driver::Cairo - The great new Graphics::Primitive::Driver::Cairo!

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Graphics::Primitive::Driver::Cairo;

    my $foo = Graphics::Primitive::Driver::Cairo->new();
    ...

=head1 AUTHOR

Cory Watson, C<< <gphat@cpan.org> >>

Infinity Interactive, L<http://www.iinteractive.com>

=head1 BUGS

Please report any bugs or feature requests to C<bug-geometry-primitive at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Geometry-Primitive>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2008 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.