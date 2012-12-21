package Folio::App;

use 5.010;
use strict;
use warnings;
use Tkx;
BEGIN {
	Tkx::package_require("Img");
	Tkx::package_require("Tcl");
	Tkx::package_require("autoscroll");
	Tkx::package_require("Tcldot");
	Tkx::package_require("Tablelist");
}
use Scalar::Util qw/looks_like_number/;
use Moo;
use MooX::Types::MooseLike::Base qw(:all);
with qw(Folio::Viewer::Component::Role::Widget);

use Folio::ThreadPool;
use Folio::Viewer::Tkx::Progress;
use Folio::Viewer::Component::ProgressManager;
use Folio::Viewer::Tkx::Icons;
use Folio::Viewer::Tkx::Timer;
use Folio::Viewer::Component::DocView;

has main_window => ( is => 'lazy');
has icons => ( is => 'lazy' );
has progress_manager => ( is => 'lazy' );

has doc_view => ( is => 'rw', isa => ArrayRef, default => sub { [] } );
has pool => ( is => 'rw' );
has components => ( is => 'rw', default => sub { {} } );

has request_cleanup_repeat => ( is => 'rw' , default => sub { \ 1 } );

sub _build_main_window {
	Tkx::widget->new('.');
}

sub _build_progress_manager {
	my ($self) = @_;
	Folio::Viewer::Component::ProgressManager->new(
		main_window => $self->main_window, icons => $self->icons );
}

sub _build_icons {
	Folio::Viewer::Tkx::Icons->new(icons => [qw/actrun22 actstop22/]);
}

sub run {
	my ($self, $ARGV) = @_;
	Tkx::ttk__style_theme_use("clam");
	$self->icons;
	$self->add_buttons();
	$self->main_window->g_wm_geometry(q{+0+0});
	$self->progress_manager->show;
	$self->add_handlers;
	my $prev;
	for my $file (@$ARGV) {
		($prev = $self->create_docview($file))->show;
	}
	Folio::Viewer::Tkx::Timer::repeat(50, sub { $self->request_cleanup }, $self->request_cleanup_repeat);
	Tkx::MainLoop();
	return 0;
}

sub add_buttons {
	my ($self) = @_;
	($self->_widgets()->{button_one} =
		$self->main_window->new_ttk__button(-text => 'one' ))
		->g_pack;
	($self->_widgets()->{button_two} =
		$self->main_window->new_ttk__button(-text => 'two' ))
		->g_pack;
}

sub register_component {
	my ($self, $comp) = @_;
	$self->components->{$comp->id} = $comp;
	$comp->pool($self->pool);
	$comp->main_window($self->main_window);
}

sub register_docview {
	my ($self, $dv) = @_;
	push @{$self->doc_view}, $dv;
	$self->register_component($dv);
}

sub create_docview {
	my ($self, $file) = @_;
	my $id = 'doc_'.scalar @{$self->doc_view};
	my $dv = Folio::Viewer::Component::DocView->new(file => $file, id => $id);
	$self->register_docview($dv);
	$dv->add_handlers;
	$dv;
}

sub request_cleanup {#{{{
	my ($self) = @_;
	#print "repeat\n";
	while(defined(my $done_job = $self->pool->done->dequeue_nb)) {
		return unless ${$self->request_cleanup_repeat};
		next unless exists $done_job->{id};
		next unless exists $self->components->{$done_job->{id}};
		$self->components->{$done_job->{id}}->publish($done_job);
	}
}#}}}

sub register_query {

}

sub add_handlers {
	my ($self) = @_;
}

1;
