# vim: fdm=marker
package Folio::Viewer::Component::DocView::SingleContinuousVerticalScroll;

use strict;
use warnings;
use Moo;
use MooX::Types::MooseLike::Base qw(:all);
use List::Util qw/first/;
use Set::Scalar;
use File::Basename;
use YAML::XS qw/LoadFile DumpFile/;
use Carp;
use Try::Tiny;
with qw(Folio::Viewer::Component::DocView::PageGeometryRole);

# Attributes {{{
has annotation => ( is => 'rw', default => sub {0} );
has annotation_file => ( is => 'lazy' );
has annotation_data => ( is => 'rw', builder => 'build_annotation_data', lazy => 1, clearer => 1 );
has _in_annotation_mode => ( is => 'rw', default => sub { 0 } );
has _in_annotation_mode_sx => ( is => 'rw', default => sub { 0 } );
has _in_annotation_mode_sy => ( is => 'rw', default => sub { 0 } );

has prev_zoom => ( is => 'rw', default => sub{ 100; } );
has base_font_size => ( is => 'rw', default => sub { 11; }  );

has _canvas_page_y => ( is => 'rw', isa => ArrayRef, default => sub{[]}, clearer => 1 );
has _canvas_page_x => ( is => 'rw', isa => ArrayRef, default => sub{[]}, clearer => 1 );

has _cv_tags => ( is => 'lazy' );
has _image => ( is => 'rw', builder => 1, clearer => '__clear_image' );
has _buffer => ( is => 'rw', isa => ArrayRef, builder => 1, clearer => '__clear_buffer' );
has _bind_keys => ( is => 'rw', default => sub { [] } );
#}}}
# Setup {{{
sub load {
	my ($self) = @_;
	$self->draw_pages;
	$self->docview->_widgets->{cv}->xview(moveto => 0);
	$self->docview->_widgets->{cv}->yview(moveto => 0);

	$self->add_handlers;
}

sub unload {
	my ($self) = @_;
	$self->clear_data;
	# TODO
	$self->remove_handlers;
}
#}}}
sub publish {#{{{
	my ($self, $job) = @_;
	if($job->{data}{action} eq 'render_page_post') {
		$self->render_pages_post_thread($job);
	} elsif($job->{data}{action} eq 'goto_page') {
		$self->goto_page_job($job);
	}
}#}}}
# Page image buffer {{{
after __clear_buffer => sub { $_[0]->_buffer($_[0]->_build__buffer) };
sub _build__buffer {[]}
sub add_buffer {#{{{
	my ($self) = @_;
	my $num = $self->num_buffer;
	my $id = 'buffer'.$num;
	$self->_image->{$id} = Tkx::widget->new(Tkx::image_create_photo());
	push @{$self->_buffer}, { name => $id , page => -1 };
	return $id;
}#}}}
sub num_buffer {#{{{
	my ($self) = @_;
	scalar @{$self->_buffer};
}#}}}
#}}}
# Build and cleanup {{{
sub _build__cv_tags {#{{{
	my ($self) = @_;
	Folio::Viewer::Tkx::Canvas->new(canvas => $self->docview->_widgets->{cv});
}#}}}

sub DEMOLISH {#{{{
	my ($self) = @_;
	$self->__clear_image;
}#}}}
before __clear_image => sub {#{{{
	my ($self) = @_;
	Tkx::image_delete(values $self->_image);
};#}}}
after __clear_image => sub { $_[0]->_image($_[0]->_build__image) };
sub _build__image { {} }

#}}}
# Goto page {{{
sub goto_page {#{{{
	my ($self, $page) = @_;
	return unless $self->docview->valid_page($page);
	my $job = { doc_pdf => { id => $self->docview->id,
			data => { action => 'goto_page',
				canvas_manager => __PACKAGE__,
				page => $page, zoom => $self->zoom } } };
	$self->docview->pool->add_work($job);
}#}}}
sub goto_page_actual {#{{{
	my ($self, $page) = @_;
	my @scroll_region = Tkx::SplitList($self->docview->_widgets->{cv}->cget('-scrollregion'));
	my $xf = ($self->_canvas_page_x->[$page] - $scroll_region[0])/($scroll_region[2]-$scroll_region[0]);
	my $yf = ($self->_canvas_page_y->[$page] - $scroll_region[1])/($scroll_region[3]-$scroll_region[1]);

	$self->docview->_widgets->{cv}->xview(moveto => $xf);
	$self->docview->_widgets->{cv}->yview(moveto => $yf);
}#}}}
sub goto_page_job {#{{{
	my ($self, $job) = @_;
	return unless $job->{data}{zoom} == $self->zoom; # TODO This a problem with how jobs come in without being validated for a given page state.
	my $page = $job->{data}{page};
	$self->goto_page_actual($page);
}#}}}
#}}}
# Annotations {{{
sub build_annotation_data {#{{{
	my ($self) = @_;
	my $h;
	try {
		$h = LoadFile $self->annotation_file;
	} catch {
		carp "Annotation file does not exist: will create";
	};
	use DDP; p $h;
	return {} unless keys ($h // {});
	$h;
}#}}}

sub write_annotation_data {#{{{
	my ($self) = @_;
	DumpFile($self->annotation_file, $self->annotation_data);
}#}}}

sub toggle_annotations {#{{{
	my ($self) = @_;
	if($self->annotation) {
		$self->annotation(0);
		for my $key (grep { /^annotation_/ } keys $self->_canvas) {
			$self->docview->_widgets->{cv}->delete($self->docview->_canvas->{$key});
			delete $self->docview->_canvas->{$key};
		}
		$self->annotation_data({});
		$self->clear_annotation_data;
	} else {
		$self->annotation(1);
		$self->draw_annotations;
	}
}#}}}

sub draw_annotations {#{{{
	my ($self) = @_;
	for my $a (keys $self->annotation_data) {
		my %h = %{$self->annotation_data->{$a}};
		my ($page, $ox, $oy, $w, $h) = @h{qw/page ox oy w h/};
		my $mult = $self->zoom/100.0;
		my $ax = $self->_canvas_page_x->[$page] + $ox*$mult;
		my $ay = $self->_canvas_page_y->[$page] + $oy*$mult;
		$self->docview->_canvas->{"annotation_$a"} = $self->docview->_widgets->{cv}
			->create_rectangle($ax, $ay,
				$ax+$w*$mult, $ay+$h*$mult,
				-outline => 'red',
				-dash => '-',
				-tags => "annotation annotation_no_$a");
		$self->docview->_canvas->{"annotation_text_$a"} = $self->docview->_widgets->{cv}
			->create_text($ax+$w*$mult, $ay+$h*$mult,
				-anchor => 'nw',
				-fill => 'blue',
				-text => $a,
				-font => "Helvetica @{[int($self->base_font_size*$mult)]}",
				-tags => "annotation annotation_text annotation_text_$a annotation_no_$a");
	}
}#}}}

sub _build_annotation_file {#{{{
	my ($self) = @_;
	return join '', (fileparse($self->docview->file,qw/.pdf/),'.ann')[qw/1 0 3/];
}#}}}

sub make_annotation {#{{{
	my ($self, $x, $y) = @_;
	if($self->annotation) {
		if($x eq 'del') {
			$self->_in_annotation_mode(0); # stop
			$self->toggle_annotations; $self->toggle_annotations; # force complete redraw
			return 
		}
		if(not $self->_in_annotation_mode) {
			$self->_in_annotation_mode(1); # start it
			my ($cx, $cy) = ($self->docview->_widgets->{cv}->canvasx($x), $self->docview->_widgets->{cv}->canvasy($y));
			$self->_in_annotation_mode_sx($cx);
			$self->_in_annotation_mode_sy($cy);
			$self->docview->_canvas->{"annotation_cur"} = $self->docview->_widgets->{cv}
				->create_rectangle($cx, $cy, $cx, $cy,
					-dash => ',',
					-tags => "annotation annotation_cur");
		} else {
			$self->_in_annotation_mode(0); # stop it
			my $next_id = (List::Util::max(keys %{$self->annotation_data}) // 0) + 1;
			my $mult = 100 / $self->zoom;
			$self->move_annotation($x, $y);
			my @coords = Tkx::SplitList($self->docview->_widgets->{cv}->coords('annotation_cur'));

			my ($page_tag) = grep { /^page_.*_no_/ } map { Tkx::SplitList($self->docview->_widgets->{cv}->gettags($_)) }
				Tkx::SplitList($self->docview->_widgets->{cv}->find_overlapping($coords[0], $coords[1], $coords[0], $coords[1]));

			my @page_coords = Tkx::SplitList($self->docview->_widgets->{cv}->coords($page_tag));
			$page_tag =~ /page_.*_no_(\d+)/;
			my $page = $1;
			use DDP; p $page;

			$self->annotation_data->{$next_id} = { page => $page,
				ox => ($coords[0] - $page_coords[0])*$mult,
				oy => ($coords[1] - $page_coords[1])*$mult,
			       	w =>  ($coords[2] - $coords[0])*$mult,
				h =>  ($coords[3] - $coords[1])*$mult };
			$self->write_annotation_data;
			$self->toggle_annotations; $self->toggle_annotations; # force complete redraw
		}
	}
}#}}}

sub move_annotation {#{{{
	my ($self, $x, $y) = @_;
	if($self->_in_annotation_mode) {
		my ($cx, $cy) = ($self->docview->_widgets->{cv}->canvasx($x), $self->docview->_widgets->{cv}->canvasy($y));
		$self->docview->_widgets->{cv}->coords('annotation_cur', $self->_in_annotation_mode_sx, $self->_in_annotation_mode_sy, $cx, $cy);
	}
}#}}}
#}}}
# Keybindings {{{
sub add_handlers {#{{{
	my ($self) = @_;
	$self->docview->_window->g_bind('<Button-5>', [sub {$self->docview->_widgets->{cv}->yview( scroll => @_, 'units')}, 1]);
		push @{$self->_bind_keys}, '<Button-5>'; 
	$self->docview->_window->g_bind('<Button-4>', [sub {$self->docview->_widgets->{cv}->yview( scroll => @_, 'units')}, -1]);
		push @{$self->_bind_keys}, '<Button-4>'; 
	$self->docview->_window->g_bind('<space>',    [sub {$self->docview->_widgets->{cv}->yview( scroll => @_, 'units')}, 1]);
		push @{$self->_bind_keys}, '<space>'; 
	$self->docview->_window->g_bind('b',        [sub {$self->docview->_widgets->{cv}->yview( scroll => @_, 'units')}, -1]);
		push @{$self->_bind_keys}, 'b'; 
	$self->docview->_window->g_bind('<Next>',     [sub {$self->docview->_widgets->{cv}->yview( scroll => @_, 'units')}, 1]);
		push @{$self->_bind_keys}, '<Next>'; 
	$self->docview->_window->g_bind('<Prior>',    [sub {$self->docview->_widgets->{cv}->yview( scroll => @_, 'units')}, -1]);
		push @{$self->_bind_keys}, '<Prior>'; 
	$self->docview->_window->g_bind('j',          [sub {$self->docview->_widgets->{cv}->yview( scroll => @_, 'units')}, 1]);
		push @{$self->_bind_keys}, 'j'; 
	$self->docview->_window->g_bind('k',          [sub {$self->docview->_widgets->{cv}->yview( scroll => @_, 'units')}, -1]);
		push @{$self->_bind_keys}, 'k'; 
	$self->docview->_window->g_bind('h',          [sub {$self->docview->_widgets->{cv}->xview( scroll => @_, 'units')}, -1]);
		push @{$self->_bind_keys}, 'h'; 
	$self->docview->_window->g_bind('l',          [sub {$self->docview->_widgets->{cv}->xview( scroll => @_, 'units')}, 1]);
		push @{$self->_bind_keys}, 'l'; 

	$self->docview->_window->g_bind('<Button-1>', [sub {$self->make_annotation(@_) }, Tkx::Ev("%x","%y")]);
		push @{$self->_bind_keys}, '<Button-1>'; 
	$self->docview->_window->g_bind('<Button-3>', [sub {$self->make_annotation('del') }, Tkx::Ev("%x","%y")]);
		push @{$self->_bind_keys}, '<Button-3>'; 
	$self->docview->_window->g_bind('<Motion>',   [sub {$self->move_annotation(@_) }, Tkx::Ev("%x","%y")]);
		push @{$self->_bind_keys}, '<Motion>'; 
	$self->docview->_window->g_bind('a',          [sub {$self->toggle_annotations() }, 0]);
		push @{$self->_bind_keys}, 'a'; 

	$self->docview->_window->g_bind('<Control-Button-5>', [sub {$self->zoom_change(-10)}, 1]);
		push @{$self->_bind_keys}, '<Control-Button-5>'; 
	$self->docview->_window->g_bind('<Control-Button-4>', [sub {$self->zoom_change( 10)}, -1]);
		push @{$self->_bind_keys}, '<Control-Button-4>'; 
	$self->docview->_window->g_bind('<Key-minus>', [sub {$self->zoom_change(-10)}, 1]);
		push @{$self->_bind_keys}, '<Key-minus>'; 
	$self->docview->_window->g_bind('<Key-plus>', [sub {$self->zoom_change( 10)}, -1]);
		push @{$self->_bind_keys}, '<Key-plus>'; 

	for my $number (0..9) {
		$number = "$number";
		$self->docview->_window->g_bind($number, [sub {$self->mark_number_log($number, time)}, -1]);
		push @{$self->_bind_keys}, $number; 
	}
	#$self->docview->_window->g_bind('gg', [sub {$self->goto_page($self->docview->first_page)}, 1]); # TODO
	$self->docview->_window->g_bind( 'g', [sub {
			my $range = $self->get_number_log(time);
			$self->goto_page(defined $range ? $range-1 : $self->docview->first_page);
		}, 1]);
		push @{$self->_bind_keys}, 'g'; 
	$self->docview->_window->g_bind( 'G', [sub {$self->goto_page($self->docview->last_page)}, 1]);
		push @{$self->_bind_keys}, 'G'; 

	#$self->docview->_window->g_bind('q',          [sub {Tkx::exit()}, 0]);
}#}}}
sub remove_handlers {
	my ($self) = @_;
	while(length $self->_bind_keys) {
		my $key = shift @{$self->_bind_keys};
		last unless defined $key;
		$self->docview->_window->g_bind($key, '');
		# unbind
	}
}

has _key_number_log => ( is => 'rw', builder => 1 );
sub _build__key_number_log {
	{ time => [], number => []};
}
sub mark_number_log {
	my ($self, $number, $time) = @_;
	push @{$self->_key_number_log->{number}}, $number;
	push @{$self->_key_number_log->{time}}, $time;
}
use constant NUMBER_LOG_DELAY => 2;
sub get_number_log {
	my ($self, $time) = @_;
	my @numbers = ();
	my $prev_time = $time // time;
	my $last_time = pop $self->_key_number_log->{time} // 0;
	while(@{$self->_key_number_log->{number}}
			and $prev_time-$last_time <= NUMBER_LOG_DELAY) {
		unshift @numbers, pop $self->_key_number_log->{number};
		$prev_time = $last_time;
		$last_time = pop $self->_key_number_log->{time};
	}
	$self->_key_number_log($self->_build__key_number_log);
	return 0+(join "", @numbers) if @numbers;
	undef; # if @numbers is empty
}

#}}}
# Zoom {{{
sub zoom_change {#{{{
	my ($self, $change) = @_;
	$self->prev_zoom($self->zoom);
	$self->zoom( $self->zoom + $change );
	$self->redraw;
}#}}}
#}}}
# Draw pages {{{
sub draw_pages {#{{{
	my ($self) = @_;
	my $pages_pdl = $self->page_geometry;
	my $num_pages = $pages_pdl->dim(1);
	my $inter_page_px = 10;
	my $cv_height = sclr(sumover($pages_pdl->transpose)->slice('1') + ($pages_pdl->dim(1)-1)*$inter_page_px);
	my $max_page_height = max($pages_pdl->slice('1,:'));
	my $max_page_width = max($pages_pdl->slice('0,:'));
	my $cv_width_h = ceil($max_page_width/2.0)->sclr;
	$self->docview->_widgets->{cv}->configure(-scrollregion => qq/-$cv_width_h 0 $cv_width_h $cv_height/);

	$self->_canvas_page_x->[$num_pages-1] = 0;
	$self->_canvas_page_y->[$num_pages-1] = 0;

	my $top_left_y = 0;
	for my $page (0..$pages_pdl->dim(1)-1) {
		my ($page_width, $page_height) = $pages_pdl->slice(":,$page")->list;
		$self->docview->_canvas->{"page_rect_$page"} = $self->docview->_widgets->{cv}
			->create_rectangle(0-$page_width/2, $top_left_y,
				$page_width/2, $top_left_y+$page_height,
				-fill => 'red',
				-tags => "page_rect page_rect_no_$page");
		$self->_canvas_page_x->[$page] = 0-$page_width/2;
		$self->_canvas_page_y->[$page] = $top_left_y;
		$top_left_y += $page_height + $inter_page_px;
	}
	$self->draw_annotations if $self->annotation;
}#}}}
sub clear_data {
	my ($self) = @_;

	$self->docview->__clear_canvas;
	$self->__clear_image;
	$self->__clear_buffer;
}
sub redraw {#{{{
	my ($self) = @_;

	$self->clear_data;

	$self->clear_page_geometry;

	my $mult = $self->zoom / $self->prev_zoom / 100 ;
	my $xv = (Tkx::SplitList($self->docview->_widgets->{cv}->xview))[0];
	my $yv = (Tkx::SplitList($self->docview->_widgets->{cv}->yview))[0];
	$self->draw_pages;
	#$self->docview->_widgets->{cv}->xview(moveto => $xv);
	#$self->docview->_widgets->{cv}->yview(moveto => $yv);
	$self->render_pages;
}#}}}

sub render_pages {#{{{
	my ($self) = @_;
	my $canvas = $self->docview->_widgets->{cv};
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
		unless $max_page_no == $self->docview->document->page_count - 1;
	push @pages_to_render, $min_page_no-1
		unless $min_page_no == 0;
	$self->render_pages_pre_thread(\@pages_to_render);
}#}}}
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
		my $job = { doc_pdf => { id => $self->docview->id,
				data => { action => 'render_page',
					canvas_manager => __PACKAGE__,
					file => $self->docview->file, id => $id,
					page => $page, zoom => $self->zoom } } };
		$self->docview->pool->add_work($job);
	}
	$self->remove_page_photo_canvas_items($pages_to_remove_not_needed->members); # remove pages in render_pages_post_thread?
}#}}}
sub render_pages_post_thread {#{{{
	my ($self, $job) = @_;
	return unless $job->{data}{zoom} == $self->zoom; # TODO This a problem with how jobs come in without being validated for a given page state.
	my $id = $job->{data}{id};
	my $page = $job->{data}{page};
	my $img_data = $job->{data}{image_data};
	my $tk_photo = $self->_image->{$id};
	$tk_photo->configure(-data => $img_data );
	my $b = first { $_->{name} eq $id } @{$self->_buffer};
	$b->{page} = $page;
	my $rect_tag = "page_rect_$page";
	my $photo_id = $self->_image->{(first { $_->{page} == $page } @{$self->_buffer})->{name}};
	my @coords = Tkx::SplitList($self->docview->_widgets->{cv}->coords($self->docview->_canvas->{$rect_tag}));
	$self->docview->_canvas->{"page_photo_$page"} = $self->docview->_widgets->{cv}->create_image(
		$coords[0], $coords[1],
		-image => $photo_id,
		-tags => "page_photo page_photo_no_$page", -anchor => 'nw');

	$self->docview->_widgets->{cv}->lower('page_photo', 'annotation');
}#}}}
sub remove_page_photo_canvas_items {#{{{
	my ($self, @which) = @_;
	return unless @which;
	if($which[0] eq 'all') {
		for my $key (grep { /^page_photo/ } keys $self->_canvas) {
			$self->docview->_widgets->{cv}->delete($self->docview->_canvas->{$key});
			delete $self->docview->_canvas->{$key};
		}
	} else {
		for my $page (@which) {
			my $tag = "page_photo_$page";
			next unless exists $self->docview->_canvas->{$tag};
			$self->docview->_widgets->{cv}->delete($self->docview->_canvas->{$tag});
			delete $self->docview->_canvas->{$tag};
		}
	}
}#}}}
#}}}


1;
