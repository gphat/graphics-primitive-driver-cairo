package Graphics::Primitive::Driver::Cairo::TextLayout;
use Moose;

# ABSTRCAT: Text layout engine

use Graphics::Primitive::TextBox;

with 'Graphics::Primitive::Driver::TextLayout';

use Text::Flow;

=head1 SYNOPSIS

    my $tl = $driver->get_textbox_layout($comp);
    ...

=head1 DESCRIPTION

Implements L<Graphics::Primitive::Driver::TextLayout>.  Please refer to it's
documentation for usage.

=begin :prelude

=head1 IMPLEMENTATION

This text layout engine uses L<Text::Flow> and L<Cairo>'s "toy text" API to
layout text.

=end :prelude

=cut

has 'lines' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] }
);

sub layout {
    my ($self, $driver) = @_;

    my $comp = $self->component;
    my $font = $comp->font;
    my $width = $comp->width ? $comp->width : $comp->minimum_inside_width;
    my $text = $comp->text;

    unless($self->width) {
        $self->width($width);
    }

    unless(defined($text)) {
        $self->height(0);
        return;
    }

    my $size;
    my $flow = Text::Flow->new(
        check_height => sub {
            return 1;
        },
        wrapper => Text::Flow::Wrap->new(
            check_width => sub {
                my $str = shift;
                my $r = $driver->get_text_bounding_box($comp, $str);
                unless($width) {
                    # Catch the "no width" case.
                    return 1;
                }
                if($r->width > $width) {
                    return 0;
                }
                return 1;
            }
        )
    );

    my @text = $flow->flow($text);

    my $p = $text[0];
    my @lines = split(/\n/, $p);

    my $height = 0;
    $width = 0;
    foreach my $l (@lines) {
        my ($cb, $tb) = $driver->get_text_bounding_box($comp);

        push(@{ $self->lines }, {
            text => $l,
            box => $tb,
            cb => $cb
        });
        $height += $cb->height;
        $width += $cb->width;
    }

    $self->height($height);
    if(!defined($self->width) || ($self->width == 0)) {
        $self->width($width);
    }
}

sub slice {
    my ($self, $offset, $size) = @_;

    unless(defined($size)) {
        $size = $self->height;
    }

    my $font = $self->component->font;
    my $lh = $font->size;
    # my $lh = defined($self->line_height)
    #     ? $self->line_height : $self->font->size;

    my @new;
    my $accum = 0;
    my $found = 0;
    for(my $i = 0; $i < scalar(@{ $self->lines }); $i++) {
        my $l = $self->lines->[$i];
        my $llh = $l->{cb}->height;

        # If the 'local' line height is < the overall line height, use the
        # overall one.
        if($llh < $lh) {
            $llh = $lh;
        }

        if($accum < $offset) {
            $accum += $llh;
            next;
        }
        if(($accum + $llh) <= ($offset + $size)) {
            push(@new, $l);
            $accum += $llh;
            $found += $llh;
        }
    }

    return Graphics::Primitive::TextBox->new(
        lines => \@new,
        minimum_width => $self->width,
        minimum_height => $found
    );
}

__PACKAGE__->meta->make_immutable;

no Moose;
1;
