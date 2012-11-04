# vim: fdm=marker
package Folio::Viewer::Component::DocView;

use strict;
use warnings;
use Moo;
use MooX::Types::MooseLike::Base qw(:all);
use PDL;
use Tkx;
with qw(Folio::Viewer::Component::Role::Widget);
use Folio::Viewer::Tkx::AutoScroll;
use Folio::Viewer::PageManager::PDF;
use Folio::Viewer::Tkx::Imager;
use Folio::Viewer::Tkx::Canvas;
use List::Util qw/first/;
use Set::Scalar;

has id => ( is => 'rw' );
has main_window => ( is => 'rw' );
has pool => ( is => 'rw' );
has file => ( is => 'rw' );

has _window => ( is => 'lazy' );

has page_manager => ( is => 'lazy' );
has page_geometry => ( is => 'lazy', isa => InstanceOf['PDL'] );
has document => ( is => 'lazy' );

has _cv_tags => ( is => 'lazy' );
has _canvas => ( is => 'rw', isa => HashRef, default => sub { {} }, clearer => '__clear_canvas' );
has _image => ( is => 'rw', default => sub { {} }, clearer => '__clear_image' );
has _buffer => ( is => 'rw', isa => ArrayRef, default => sub {[]} );


sub _build__window {#{{{
	my ($self) = @_;
	my $w = $self->main_window->new_toplevel(-name => ".docview_@{[$self->id]}");

	$self->_widgets->{cv} = $w->new_tk__canvas();
	$self->_widgets->{cv_autoscroll} = Folio::Viewer::Tkx::AutoScroll
		->new(widget => $self->_widgets->{cv});

	($self->_widgets->{sz_grip} = $w->new_ttk__sizegrip())
		->g_grid(-column => 1, -row => 1, -sticky => "se");

	$self->_widgets->{cv}->g_grid(-column => 0, -row => 0, -sticky => "nwes");
	$self->_widgets->{cv_autoscroll}->xscroll->g_grid(-column => 0, -row => 1, -sticky => "we");
	$self->_widgets->{cv_autoscroll}->yscroll->g_grid(-column => 1, -row => 0, -sticky => "ns");
	$w->g_grid_columnconfigure(0, -weight => 1);
	$w->g_grid_rowconfigure(0, -weight => 1);

	my $scroll_control = sub {
		my $dir = pop;
		if($dir eq "v" ) {
			$self->_widgets->{cv_autoscroll}->yscroll->set(@_);
		} elsif($dir eq "h") {
			$self->_widgets->{cv_autoscroll}->xscroll->set(@_);
		}
		my $canvas = $self->_widgets->{cv};
		my $pages_visible = $self->_cv_tags->canvas_visible_tags();
		my $max_page_no = -1;
		my $min_page_no = '+Inf';
		my @pages_to_render;
		for my $page (@$pages_visible) {
			next unless $page =~ /page_rect_no_(\d+)/;
			my $page_no = $1;
			$max_page_no = List::Util::max($max_page_no, $page_no);
			$min_page_no = List::Util::min($min_page_no, $page_no);
			push @pages_to_render, $page_no;
		}
		push @pages_to_render, $max_page_no+1
			unless $max_page_no == $self->document->page_count - 1;
		push @pages_to_render, $min_page_no-1
			unless $min_page_no == 0;
		$self->render_pages_pre_thread(\@pages_to_render);
	};

	$self->_widgets->{cv_autoscroll}->widget->configure(-yscrollcommand => [$scroll_control, 'v'],
		-xscrollcommand => [$scroll_control, 'h']);

	my $first_page_icon = $self->page_manager
			->get_document_page_imager($self->file, 0)
			->scale(xpixels => 200, ypixels => 200, type => 'min');
	$self->_image->{title_page} = Folio::Viewer::Tkx::Imager->get_tk_image($first_page_icon);
	$w->g_wm_iconphoto($self->_image->{title_page});

	$w->g_wm_title($self->file);

	$self->draw_pages;
	$self->_widgets->{cv}->xview(moveto => 0);
	$self->_widgets->{cv}->yview(moveto => 0);

	$w;
}#}}}

sub hide {#{{{
	my ($self) = @_;
	$self->_window->g_wm_withdraw;
}#}}}

sub show {#{{{
	my ($self) = @_;
	$self->_window->g_wm_deiconify;
}#}}}

sub DEMOLISH {#{{{
	my ($self) = @_;
	$self->__clear_canvas_item;
	$self->__clear_image;
}#}}}
sub __clear_canvas {#{{{
	my ($self) = @_;
	Tkx::canvas_delete(keys $self->_canvas);
}#}}}
sub __clear_image {#{{{
	my ($self) = @_;
	Tkx::image_delete(keys $self->_image);
}#}}}

sub add_buffer {#{{{
	my ($self) = @_;
	my $num = $self->num_buffer;
	my $id = 'buffer'.$num;
	$self->_image->{$id} = Tkx::widget->new(Tkx::image_create_photo());
	push @{$self->_buffer}, { name => $id , page => -1 };
}#}}}
sub num_buffer {#{{{
	my ($self) = @_;
	scalar @{$self->_buffer};
}#}}}

sub _build_page_manager {#{{{
	 Folio::Viewer::PageManager::PDF->new();
}#}}}
sub _build_document {#{{{
	my ($self) = @_;
	$self->page_manager->get_document($self->file);
}#}}}
sub _build_page_geometry {#{{{
	my ($self) = @_;
	my $doc_bounds = null;
	for my $page_num (0..$self->document->page_count-1) {
		$doc_bounds = $doc_bounds->glue(1,pdl $self->page_manager->get_page_bounds($self->file,
			$page_num));
	}
	croak("Size mismatch") unless $doc_bounds->dim(1) == $self->document->page_count;
	$doc_bounds;
}#}}}
sub _build__cv_tags {#{{{
	my ($self) = @_;
	Folio::Viewer::Tkx::Canvas->new(canvas => $self->_widgets->{cv});
}#}}}

sub publish {
	my ($self, $job) = @_;
	if($job->{data}{action} eq 'render_page_post') {
		$self->render_pages_post_thread($job);
	}
}

sub render_pages_pre_thread {#{{{
	my ($self, $pages) = @_;

	my $pages_in_buffer = Set::Scalar->new(map { $_->{page} } @{$self->_buffer});
	my $pages_needed = Set::Scalar->new(@$pages);

	my $pages_to_render_done = $pages_needed->intersection($pages_in_buffer);
	my $pages_to_render_will = $pages_needed-$pages_to_render_done;
	my $pages_to_remove_not_needed = $pages_in_buffer-$pages_to_render_done;
	my $buffers_needed = $pages_to_render_will->size - $pages_to_remove_not_needed->size;
	$self->add_buffer() for(0..$buffers_needed-1);

	my $id_to_use = Set::Scalar->new(map { $_->{name} }
		grep { $pages_to_remove_not_needed->has($_->{page}) or $_->{page} == -1 }
		@{$self->_buffer});

	while (defined(my $id = $id_to_use->each) && defined(my $page = $pages_to_render_will->each)) {
		my $job = { doc_pdf => { id => $self->id,
				data => { action => 'render_page',
					file => $self->file, id => $id,
					page => $page } } };
		$self->pool->add_work($job);
	}
	$self->remove_page_photo_canvas_items($pages_to_remove_not_needed->members); # remove pages in render_pages_post_thread?
}#}}}

sub render_pages_post_thread {#{{{
	my ($self, $job) = @_;
	my $id = $job->{data}{id};
	my $page = $job->{data}{page};
	my $img_data = $job->{data}{image_data};
	my $tk_photo = $self->_image->{$id};
	$tk_photo->configure(-data => $img_data );
	my $b = first { $_->{name} eq $id } @{$self->_buffer};
	$b->{page} = $page;
	my $rect_tag = "page_rect_$page";
	my $photo_id = $self->_image->{(first { $_->{page} == $page } @{$self->_buffer})->{name}};
	my @coords = Tkx::SplitList($self->_widgets->{cv}->coords($self->_canvas->{$rect_tag}));
	$self->_canvas->{"page_photo_$page"} = $self->_widgets->{cv}->create_image(
		$coords[0], $coords[1],
		-image => $photo_id,
		-tags => "page_photo page_photo_no_$page", -anchor => 'nw');
}

sub remove_page_photo_canvas_items {
	my ($self, @which) = @_;
	return unless @which;
	if($which[0] eq 'all') {
		for my $key (grep { /^page_photo/ } keys $self->_canvas) {
			$self->_widgets->{cv}->delete($self->_canvas->{$key});
			delete $self->_canvas->{$key};
		}
	} else {
		for my $page (@which) {
			my $tag = "page_photo_$page";
			next unless exists $self->_canvas->{$tag};
			$self->_widgets->{cv}->delete($self->_canvas->{$tag});
			delete $self->_canvas->{$tag};
		}
	}
}

sub draw_pages {#{{{
	my ($self) = @_;
	my $pages_pdl = $self->page_geometry;
	my $inter_page_px = 10;
	my $cv_height = sclr(sumover($pages_pdl->transpose)->slice('1') + ($pages_pdl->dim(1)-1)*$inter_page_px);
	my $max_page_height = max($pages_pdl->slice('1,:'));
	my $max_page_width = max($pages_pdl->slice('0,:'));
	my $cv_width_h = ceil($max_page_width/2.0)->sclr;
	$self->_widgets->{cv}->configure(-scrollregion => qq/-$cv_width_h 0 $cv_width_h $cv_height/);

	my $top_left_y = 0;
	for my $page (0..$pages_pdl->dim(1)-1) {
		my ($page_width, $page_height) = $pages_pdl->slice(":,$page")->list;
		$self->_canvas->{"page_rect_$page"} = $self->_widgets->{cv}
			->create_rectangle(0-$page_width/2, $top_left_y,
				$page_width/2, $top_left_y+$page_height,
				-fill => 'red',
				-tags => "page_rect page_rect_no_$page");
		$top_left_y += $page_height + 10;
	}
}#}}}

sub add_handlers {
	my ($self) = @_;
	$self->_window->g_bind('<Button-5>', [sub {$self->_widgets->{cv}->yview( scroll => @_, 'units')}, 1]);
	$self->_window->g_bind('<Button-4>', [sub {$self->_widgets->{cv}->yview( scroll => @_, 'units')}, -1]);
	$self->_window->g_bind('<space>',    [sub {$self->_widgets->{cv}->yview( scroll => @_, 'units')}, 1]);
	$self->_window->g_bind('<b>',        [sub {$self->_widgets->{cv}->yview( scroll => @_, 'units')}, -1]);
	$self->_window->g_bind('<Next>',     [sub {$self->_widgets->{cv}->yview( scroll => @_, 'units')}, 1]);
	$self->_window->g_bind('<Prior>',    [sub {$self->_widgets->{cv}->yview( scroll => @_, 'units')}, -1]);
	$self->_window->g_bind('j',          [sub {$self->_widgets->{cv}->yview( scroll => @_, 'units')}, 1]);
	$self->_window->g_bind('k',          [sub {$self->_widgets->{cv}->yview( scroll => @_, 'units')}, -1]);
}

1;
__END__

sub draw_page_tag {#{{{
	my $tag = shift;
	$tag =~ /page_no_(\d+)/;
	my $page_no = $1;
	my $photo = Folio::Viewer::Tkx::Imager->get_tk_image(_memo_help($self->file, $page_no));
	my @coords = Tkx::SplitList($self->_widgets->{cv}->coords($tag));
	$self->_widgets->{cv}->create_image($coords[0], $coords[1],
		-image => $photo, -tags => "photo_no_$page_no", -anchor => 'nw');
}#}}}

sub _memo_help {#{{{
	my ($file, $page_num) = @_;
	$self->page_manager->get_document_page_imager($file, $page_num);
}#}}}

1;
__END__

sub open_file {#{{{
	my ($filename) = @_;

	$file = $filename;
	$doc = $manage->get_document($file);
	print "Pages: @{[$doc->page_count]}\n";

	$mainWindow{page_num} = 0;
	$mainWindow{mw}->g_wm_title($file);
	update_label();

	# TODO : set as just the first page (or in the future, detect title-like page)


	draw_pages($doc_bounds);

	0;
}#}}}
# Page change {{{
sub page_change {#{{{
	my ($delta) = @_;
	my $target = $mainWindow{page_num} + $delta;
	return 0 if $target < 0 or $target >= $doc->page_count;
	$mainWindow{page_num} = $target;
	return 1;
}#}}}
sub update_label {#{{{
	my $photo = Folio::Viewer::Tkx::Imager->get_tk_image(get_current_page_imager());
	$mainWindow{main_page_image}->configure(-image => $photo);
	my ($height, $width) = (Tkx::image_height $photo, Tkx::image_width $photo);
	$mainWindow{mw}->g_wm_minsize( $width, $height ); 
		# force a size if needed.  Helps with some pack layouts
}#}}}
sub get_current_page_imager {#{{{
	# TODO uses global $file
	_memo_help($file, $mainWindow{page_num});
}#}}}
#}}}
