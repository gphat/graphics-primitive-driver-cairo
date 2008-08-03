package Graphics::Primitive::Driver::Cairo;
use Moose;
use Moose::Util::TypeConstraints;

use Cairo;
use Carp;
use Geometry::Primitive::Point;
use Geometry::Primitive::Rectangle;
use IO::File;

with 'Graphics::Primitive::Driver';

our $AUTHORITY = 'cpan:GPHAT';
our $VERSION = '0.04';

enum 'Graphics::Primitive::Driver::Cairo::Format' => (
    'PDF', 'PS', 'PNG', 'SVG'
);

# If we encounter a operation with 'preserve' set to true we'll set this attr
# to the number of primitives in that path.  On each iteration we'll check
# this attribute.  If it's true, we'll skip that many primitives in the
# current path and then reset the value.  This allows us to leverage cairo's
# fill_preserve and stroke_perserve and avoid wasting time redrawing.
has '_preserve_count' => (
    isa => 'Str',
    is  => 'rw',
    default => sub { 0 }
);
has 'cairo' => (
    is => 'rw',
    isa => 'Cairo::Context',
    clearer => 'clear_cairo',
    lazy => 1,
    default => sub {
        my $self = shift;
        return Cairo::Context->create($self->surface);
    }
);
has 'component' => (
    is => 'rw',
    isa => 'Graphics::Primitive::Component'
);
has 'format' => (
    is => 'ro',
    isa => 'Graphics::Primitive::Driver::Cairo::Format',
    default => sub { 'PNG' }
);
has 'surface' => (
    is => 'rw',
    clearer => 'clear_surface',
    lazy => 1,
    default => sub {
        # Lazily create our surface based on the format they are required
        # to've chosen when creating this object
        my $self = shift;

        my $comp = $self->component;
        die('Must have a component') unless $comp;

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
        return $surface;
    }
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

sub data {
    my ($self) = @_;

    return $self->surface_data;
}

around('draw', sub {
    my ($cont, $class, $comp) = @_;

    my $cairo = $class->cairo;

    $cairo->save;

    $cairo->translate($comp->origin->x, $comp->origin->y);
    $cairo->rectangle(0, 0, $comp->width, $comp->height);
    $cairo->clip;

    $cont->($class, $comp);

    $cairo->restore;
});

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

    my $width = $comp->width;
    my $height = $comp->height;

    my $context = $self->cairo;

    if(defined($comp->background_color)) {
        $context->set_source_rgba($comp->background_color->as_array_with_alpha);
        $context->rectangle(0, 0, $width, $height);
        $context->fill;
    }

    my $margins = $comp->margins;
    my ($mx, $my, $mw, $mh) = (
        $margins->left, $margins->top, $margins->right, $margins->bottom
    );

    if(defined($comp->border) && $comp->border->width) {
        my $border = $comp->border;
        my $bswidth = $border->width;
        if(defined($border->color)) {
            $context->set_source_rgba($border->color->as_array_with_alpha);
        }
        $context->set_line_width($bswidth);
        $context->set_line_cap($border->line_cap);
        $context->set_line_join($border->line_join);
        $context->new_path;
        my $swhalf = $bswidth / 2;
        $context->rectangle(
            $mx + $swhalf, $my + $swhalf,
            $width - $bswidth - $mw - $mx, $height - $bswidth - $mh - $my
        );
        $context->stroke;
    }
}

sub _draw_textbox {
    my ($self, $comp) = @_;

    $self->_draw_component($comp);

    my $bbox = $comp->inside_bounding_box;
    my $context = $self->cairo;

    my $font = $comp->font;
    $context->select_font_face(
        $font->face, $font->slant, $font->weight
    );
    $context->set_font_size($font->size);

    my $yaccum = 0;
    foreach my $line (@{ $comp->lines }) {
        my $text = $line->{text};
        my $tbox = $line->{box};

        my $o = $bbox->origin;
        my $th = $tbox->height;

        my $x = $o->x - $o->x + 1;
        my $y = $o->y + $yaccum + $th;

        $context->move_to($x, $y - 1);
        $context->text_path($text);
        $yaccum += $th;
    }
    $context->set_source_rgba($comp->color->as_array_with_alpha);
    $context->fill;
}

sub _draw_arc {
    my ($self, $arc) = @_;

    my $context = $self->cairo;
    my $o = $arc->origin;
    $context->arc(
        $o->x, $o->y, $arc->radius, $arc->angle_start, $arc->angle_end
    );
}

sub _draw_canvas {
    my ($self, $comp) = @_;

    $self->_draw_component($comp);

    foreach (@{ $comp->paths }) {

        $self->_draw_path($_->{path}, $_->{op});
    }
}

sub _draw_path {
    my ($self, $path, $op) = @_;

    my $context = $self->cairo;

    my $pc = $self->_preserve_count;
    if($pc) {
        $self->_preserve_count(0);
    } else {
        $context->new_path;
    }

    # If preserve count is set we've "preserved" a path that's made up 
    # of X primitives.  Set the sentinel to 
    my $pcount = $path->primitive_count;
    for(my $i = $pc; $i < $pcount; $i++) {
        my $prim = $path->get_primitive($i);
        my $hints = $path->get_hint($i);

        if(defined($hints)) {
            unless($hints->{contiguous}) {
                my $ps = $prim->point_start;
                $context->move_to(
                    $ps->x, $ps->y
                );
            }
        }

        # FIXME Check::ISA
        if($prim->isa('Geometry::Primitive::Line')) {
            $self->_draw_line($prim);
        } elsif($prim->isa('Geometry::Primitive::Rectangle')) {
            $self->_draw_rectangle($prim);
        } elsif($prim->isa('Geometry::Primitive::Arc')) {
            $self->_draw_arc($prim);
        }
    }

    if($op->isa('Graphics::Primitive::Operation::Stroke')) {
        $self->_do_stroke($op);
    } elsif($op->isa('Graphics::Primitive::Operation::Fill')) {
        $self->_do_fill($op);
    }

    if($op->preserve) {
        $self->_preserve_count($path->primitive_count);
    }
}

sub _draw_line {
    my ($self, $line) = @_;

    my $context = $self->cairo;
    my $end = $line->end;
    $context->line_to($end->x, $end->y);
}

sub _draw_rectangle {
    my ($self, $rect) = @_;

    my $context = $self->cairo;
    $context->rectangle(
        $rect->origin->x, $rect->origin->y,
        $rect->width, $rect->height
    );
}

sub _do_fill {
    my ($self, $fill) = @_;

    my $context = $self->cairo;
    my $paint = $fill->paint;

    # FIXME Check::ISA?
    if($paint->isa('Graphics::Primitive::Paint::Gradient')) {

        if($paint->style eq 'linear') {
            my $patt = Cairo::LinearGradient->create(
                $paint->line->start->x, $paint->line->start->y,
                # 0, 0,
                $paint->line->end->x, $paint->line->end->y,
            );
            foreach my $stop ($paint->stops) {
                my $color = $paint->get_stop($stop);
                $patt->add_color_stop_rgba(
                    $stop, $color->red, $color->green,
                    $color->blue, $color->alpha
                );
            }
            $context->set_source($patt);
        } elsif($paint->style eq 'radial') {
            # TODO
        } else {
            croak('Unknown gradient type: '.$paint->style);
        }
    } elsif($paint->isa('Graphics::Primitive::Paint::Solid')) {
        $context->set_source_rgba($paint->color->as_array_with_alpha);
    }

    if($fill->preserve) {
        $context->fill_preserve;
    } else {
        $context->fill;
    }
}

sub _do_stroke {
    my ($self, $stroke) = @_;

    my $br = $stroke->brush;

    my $context = $self->cairo;
    $context->set_source_rgba($br->color->as_array_with_alpha);
    $context->set_line_cap($br->line_cap);
    $context->set_line_join($br->line_join);
    $context->set_line_width($br->width);

    if($stroke->preserve) {
        $context->stroke_preserve;
    } else {
        $context->stroke;
    }
}

sub get_text_bounding_box {
    my ($self, $font, $text) = @_;

    my $context = $self->cairo;
    $context->select_font_face(
        $font->face, $font->slant, $font->weight
    );
    $context->set_font_size($font->size);
    my $ext = $context->text_extents($text);

    return Geometry::Primitive::Rectangle->new(
        origin  => Geometry::Primitive::Point->new(
            x => $ext->{x_bearing},
            y => $ext->{y_bearing}
        ),
        width   => $ext->{width} + 2,
        height  => $ext->{height} + 2
    );
}

no Moose;
1;
__END__

=head1 NAME

Graphics::Primitive::Driver::Cairo - Cairo backend for Graphics::Primitive

=head1 SYNOPSIS

    use Graphics::Pritive::Component;
    use Graphics::Pritive::Component;
    use Graphics::Primitive::Driver::Cairo;

    my $driver = Graphics::Primitive::Driver::Cairo->new;
    my $container = Graphics::Primitive::Container->new(
        width => $form->sheet_width,
        height => $form->sheet_height
    );
    $container->border->width(1);
    $container->border->color($black);
    $container->padding(
        Graphics::Primitive::Insets->new(top => 5, bottom => 5, left => 5, right => 5)
    );
    my $comp = Graphics::Primitive::Component->new;
    $comp->background_color($black);
    $container->add_component($comp, 'c');

    my $lm = Layout::Manager::Compass->new;
    $lm->do_layout($container);

    my $driver = Graphics::Primitive::Driver::Cairo->new(
        format => 'PDF'
    );
    $driver->draw($container);
    $driver->write('/Users/gphat/foo.pdf');

=head1 DESCRIPTION

This module draws Graphics::Primitive objects using Cairo.

=head1 METHODS

=head2 Constructor

=over 4

=item I<new>

Creates a new Graphics::Primitive::Driver::Cairo object.  Requires a format.

  my $driver = Graphics::Primitive::Driver::Cairo->new(format => 'PDF');

=back

=head2 Instance Methods

=over 4

=item I<append_surface_data>

Append to the surface data.

=item I<cairo>

This driver's Cairo::Context object

=item I<data>

Get the data in a scalar for this driver.

=item I<draw>

Draws the specified component.  Container's components are drawn recursively.

=item I<format>

Get the format for this driver.

=item I<get_text_bounding_box>

Returns a L<Graphics::Primitive::Rectangle> that encloses the rendered text.
The origin's x and y maybe negative, meaning that the glyphs in the text
extending left of x or above y.

=item I<surface>

Get/Set the surface on which this driver is operating.

=item I<surface_data>

Get the data for this driver's surface.

=item I<write>

Write this driver's data to the specified file.

=back

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