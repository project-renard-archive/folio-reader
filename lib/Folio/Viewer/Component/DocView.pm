# vim: fdm=marker
package Folio::Viewer::Component::DocView;

# use {{{
use strict;
use warnings;
use Moo;
use MooX::Types::MooseLike::Base qw(:all);
use Tkx;
with qw(Folio::Viewer::Component::Role::Widget);
use Folio::Viewer::Tkx::AutoScroll;
use Folio::Viewer::PageManager::PDF;
use Folio::Viewer::Tkx::Imager;
use Folio::Viewer::Tkx::Canvas;

use Folio::Viewer::Component::DocView::SingleContinuousVerticalScroll;
use Folio::Viewer::Component::DocView::Null;
use Folio::Viewer::Component::DocView::PagePicker;
#}}}

# Attributes {{{
has id => ( is => 'rw' );
has main_window => ( is => 'rw' );
has pool => ( is => 'rw' );
has file => ( is => 'rw' );

has _window => ( is => 'lazy' );

has page_manager => ( is => 'lazy' );
has document => ( is => 'lazy' );

has _image => ( is => 'rw', builder => 1, clearer => '__clear_image' );
has canvas_manager => ( is => 'rw', predicate => 1 );
has scvs_canvas_manager => ( is => 'lazy', builder => 1 );
has pp_canvas_manager => ( is => 'lazy', builder => 1 );

has _canvas => ( is => 'rw', isa => HashRef, builder => 1, clearer => '__clear_canvas' );
#}}}

sub publish {#{{{
	my ($self, $job) = @_;
	if(exists $job->{data}{canvas_manager}) {
		$self->canvas_manager->publish($job);
	}
}#}}}
# Build and cleanup {{{
# Window {{{
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
		$self->canvas_manager->render_pages;
	};

	$self->_widgets->{cv_autoscroll}->widget->configure(-yscrollcommand => [$scroll_control, 'v'],
		-xscrollcommand => [$scroll_control, 'h']);

	my $first_page_icon = $self->page_manager
			->get_document_page_imager($self->file, 0)
			->scale(xpixels => 200, ypixels => 200, type => 'min');
	$self->_image->{title_page} = Folio::Viewer::Tkx::Imager->get_tk_image($first_page_icon);
	$w->g_wm_iconphoto($self->_image->{title_page});

	$w->g_wm_title($self->file);

	$w;
}#}}}

sub setup_canvas_manager {
	my ($self) = @_;
	$self->set_canvas_manager_scvs;
};
sub hide {#{{{
	my ($self) = @_;
	$self->_window->g_wm_withdraw;
}#}}}
sub show {#{{{
	my ($self) = @_;
	$self->_window->g_wm_deiconify;
	$self->setup_canvas_manager;
	$self->add_handlers;
}#}}}
#}}}
sub _build_page_manager {#{{{
	 Folio::Viewer::PageManager::PDF->new();
}#}}}
sub _build_document {#{{{
	my ($self) = @_;
	$self->page_manager->get_document($self->file);
}#}}}

sub DEMOLISH {#{{{
	my ($self) = @_;
	$self->__clear_canvas;
	$self->__clear_image;
}#}}}
before __clear_canvas => sub {#{{{
	my ($self) = @_;
	$self->_widgets->{cv}->delete(values $self->_canvas);
};#}}}
after __clear_canvas => sub { $_[0]->_canvas($_[0]->_build__canvas) };
sub _build__canvas { {} }

before __clear_image => sub {#{{{
	my ($self) = @_;
	Tkx::image_delete(values $self->_image);
};#}}}
after __clear_image => sub { $_[0]->_image($_[0]->_build__image) };
sub _build__image { {} }
#}}}
# Goto page {{{
sub valid_page {
	my ($self, $page) = @_;
	my $num_pages = $self->document->page_count;
	return ($page >= 0 && $page < $num_pages);
}
sub first_page {
	return 0;
}
sub last_page {
	my ($self) = @_;
	my $num_pages = $self->document->page_count;
	$num_pages - 1;
}
#}}}
# Canvas manager {{{
around canvas_manager => sub {
        my $orig = shift;
        my $self = shift;
	$self->canvas_manager->unload if $self->has_canvas_manager and @_;
        my $ret = $orig->($self, @_);
	$self->canvas_manager->load if @_;
	# TODO: debug
	use Scalar::Util qw/blessed/;
	$self->_window->g_wm_title($self->file . " ::: " . blessed($self->canvas_manager) ) if @_;
	# END TODO
	$ret;
};
sub set_canvas_manager_scvs {
	my ($self) = @_;
	$self->canvas_manager($self->scvs_canvas_manager);
}
sub set_canvas_manager_pp {
	my ($self) = @_;
	$self->canvas_manager($self->pp_canvas_manager);
}
sub _build_pp_canvas_manager {
	my ($self) = @_;
	Folio::Viewer::Component::DocView::PagePicker
		->new(docview => $self);
}
sub _build_scvs_canvas_manager {
	my ($self) = @_;
	Folio::Viewer::Component::DocView::SingleContinuousVerticalScroll
		->new(docview => $self);
}
#}}}
# Keybindings {{{
sub add_handlers {#{{{
	my ($self) = @_;
	$self->_window->g_bind('p', [sub {$self->canvas_manager($self->set_canvas_manager_pp)}, 1]);
		# p
	$self->_window->g_bind('<Key-bracketleft>', [sub {$self->canvas_manager(Folio::Viewer::Component::DocView::Null->new(docview => $self))}, 1]);
		# [
	$self->_window->g_bind('<Key-bracketright>', [sub {$self->set_canvas_manager_scvs}, -1]);
		# ]
}#}}}
#}}}


sub canvas_cell_size {
	my ($self) = @_;
	my @canvas_cell = (0, 0);
	#$self->_window->g_grid_bbox( @canvas_cell );
	my @bbox = Tkx::SplitList($self->_window->g_grid_bbox(@canvas_cell));
	[@bbox[2,3]];
}

1;
