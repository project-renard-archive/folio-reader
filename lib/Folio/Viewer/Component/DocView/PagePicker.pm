package Folio::Viewer::Component::DocView::PagePicker;

use strict;
use warnings;
use Moo;
use MooX::Types::MooseLike::Base qw(:all);
with qw(Folio::Viewer::Component::DocView::PageGeometryRole);
use List::Util;

has _canvas_page_y => ( is => 'rw', isa => ArrayRef, default => sub{[]}, clearer => 1 );
has _canvas_page_x => ( is => 'rw', isa => ArrayRef, default => sub{[]}, clearer => 1 );

use constant INTER_COLUMN_PX => 10;
use constant INTER_ROW_PX => 10;
use constant BORDER => 15;
has page_columns => ( is => 'rw', default => sub {3} );

has _bind_keys => ( is => 'rw', default => sub { [] } );

sub load {
	my ($self) = @_;
	$self->docview->_window->g_bind('<Configure>',
		[sub { $self->draw_pages; }, -1]);
	$self->draw_pages;
	$self->docview->_widgets->{cv}->xview(moveto => 0);
	$self->docview->_widgets->{cv}->yview(moveto => 0);

	$self->add_handlers;
}

sub unload {
	my ($self) = @_;
	$self->clear_data;
	$self->remove_handlers;
}

around page_columns => sub {
        my $orig = shift;
        my $self = shift;
	return if(@_ and $_[0]<=1);
        my $ret = $orig->($self, @_);
	$self->draw_pages if @_;
	$ret;
};

sub page_column_width {
	my ($self) = @_;
	my $cv_width = $self->available_canvas_width;
	# page_columns * ( column_width + INTER_COLUMN_PX )
	# 	- INTER_COLUMN_PX = canvas_width
	($cv_width + INTER_COLUMN_PX)  / ($self->page_columns) - INTER_COLUMN_PX;
}

sub available_canvas_width {
	my ($self) = @_;
	$self->docview->canvas_cell_size->[0] - BORDER;
}

sub page_size {
	my ($self, $x, $y, $page_column_width) = @_;
	[$page_column_width, $y * $page_column_width/$x ];
}
sub page_size_int {
	my ($self, $x, $y, $page_column_width) = @_;
	[map {int($_)} @{&page_size}];
}

sub draw_pages {#{{{
	my ($self) = @_;
	$self->docview->__clear_canvas;
	my $pages_pdl = $self->page_geometry;
	my $num_pages = $pages_pdl->dim(1);
	my $num_cols = $self->page_columns;
	my $page_column_width = $self->page_column_width;

	$self->_canvas_page_x->[$num_pages-1] = 0;
	$self->_canvas_page_y->[$num_pages-1] = 0;

	my $top_left_y = 0;
	my $page = 0;
	my $right_x = $self->available_canvas_width;
	my $bottom_y = 0;
	while($page < $num_pages) {
		my $max_page_height = 0;
		my $top_left_x = 0;
		my $column = 0;
		while($column < $num_cols && $page < $num_pages ) {
			$self->_canvas_page_x->[$page] = $top_left_x;
			$self->_canvas_page_y->[$page] = $top_left_y;
			my ($page_width, $page_height) = $pages_pdl->slice(":,$page")->list;
			my $size = $self->page_size_int( $page_width, $page_height,
				$page_column_width);
			$self->docview->_canvas->{"page_rect_$page"} = $self->docview->
				_widgets->{cv}
				->create_rectangle($top_left_x, $top_left_y,
					$top_left_x+$size->[0], $top_left_y+$size->[1],
					-fill => 'red',
					-tags => "page_rect page_rect_no_$page");
			$top_left_x += $size->[0] + INTER_COLUMN_PX;
			$max_page_height = List::Util::max($max_page_height, $size->[1]);
			$page++;
			$column++;
			$bottom_y = List::Util::max($bottom_y, $top_left_y+$size->[1]);
		}
		$top_left_y += $max_page_height + INTER_ROW_PX;
	}
	$bottom_y += INTER_ROW_PX;
	$self->docview->_widgets->{cv}->configure(
		-scrollregion => qq/0 0 $right_x $bottom_y/);
}#}}}

sub clear_data {
	my ($self) = @_;

	$self->docview->__clear_canvas;
}

sub _build__cv_tags {#{{{
	my ($self) = @_;
	Folio::Viewer::Tkx::Canvas->new(canvas => $self->docview->_widgets->{cv});
}#}}}

sub add_handlers {
	my ($self) = @_;
	$self->docview->_window->g_bind('<Key-minus>', [sub {$self->page_columns($self->page_columns-1)}, 1]);
		push @{$self->_bind_keys}, '<Key-minus>';
	$self->docview->_window->g_bind('<Key-plus>', [sub {$self->page_columns($self->page_columns+1)}, -1]);
		push @{$self->_bind_keys}, '<Key-plus>';
}

sub remove_handlers {
	my ($self) = @_;
	while(length $self->_bind_keys) {
		my $key = shift @{$self->_bind_keys};
		last unless defined $key;
		$self->docview->_window->g_bind($key, '');
		# unbind
	}
}

1;
