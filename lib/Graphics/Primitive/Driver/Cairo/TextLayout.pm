package Graphics::Primitive::Driver::Cairo::TextLayout;
use Moose;

use Graphics::Primitive::TextBox;

with 'Graphics::Primitive::Driver::TextLayout';

use Text::Flow;

# has 'component' => (
#     is => 'rw',
#     isa => 'Graphics::Primitive::Component')
has 'lines' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] }
);
# has 'text' => (
#     is => 'rw',
#     isa => 'Str',
#     required => 1
# );
# has 'width' => (
#     is => 'rw',
#     isa => 'Num',
#     required => 1
# );

# sub height {
#     my ($self) = @_;
# 
#     my $h = 0;
#     foreach my $l (@{ $self->lines }) {
#         $h += defined($self->line_height)
#             ? $self->line_height : $l->{cb}->height;
#     }
#     return $h;
# }

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
        width => $self->width,
        height => $found
    );

    # my %ret = (
    #     size => $found,
    #     lines => \@new
    # );
    # return \%ret;
}

__PACKAGE__->meta->make_immutable;

no Moose;
1;
__END__
=head1 NAME

Document::Writer::TextLayout - Text layout engine

=head1 SYNOPSIS

    use Document::Writer;

    my $doc = Document::Writer->new(default_color => ...);
    my $p = $doc->next_page($width, $height);
    $p->add_text_to_page($driver, $font, $text);
    ...

=head1 METHODS

=over 4

=item I<font>

Set/Get this text layout's font.

=item I<height>

Get the height of this text layout.  Only useful after C<layout> has been
called.

=item I<layout>

Lay out the text based on the provided attributes.

=item I<lines>

Set/Get this text layout's 'lines'.  This is an arrayref of hashrefs, where
each hashref has the following members:

=over 4

=item B<box>

The bounding box for the text in this line.  This bounding box does not
take rotations into consideration.

=item B<cb>

The bounding box of required for a container that intends to contain the text
in this line.  

=item B<text>

The text in this line.

=back

This data structure is the meat of a TextLayout.  The multi-line, unwrapped
text is broken down into this datastructure based on the C<width> attribute.

=item I<slice ($offset, [$size])>

Given an offset and an optional size, returns C<n> lines from this layout
that come as close to C<$size> without exceeding it.  This method is provided
to allow incremental rendering of text.  For example, if you have a series
of containers 80 units high, you might write code like this:

  for(my $i = 0; $i < 3; $i++) {
      $lines = $layout->slice($i * 80, 80);
      # render the text
  }

=item I<text>

Set/Get the text to be laid out.

=item I<width>

Get/Set the width at which the text in this TextLayout should be wrapped.

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