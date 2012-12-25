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
has cleanup => ( is => 'rw' );
has components => ( is => 'rw', default => sub { {} } );

has id => ( is => 'rw', default => sub { 'main_component' }  );

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
	$self->register_self;
	for my $file (@$ARGV) {
		$self->create_docview($file)
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

sub register_self {
	my ($self) = @_;
	$self->components->{$self->id} = $self;
	# TODO weak
}

sub register_component {
	my ($self, $comp, $pool) = @_;
	$self->components->{$comp->id} = $comp;
	$comp->pool($self->pool) if $pool;
	$comp->main_window($self->main_window);
}

sub register_docview {
	my ($self, $dv) = @_;
	push @{$self->doc_view}, $dv;
	$self->register_component($dv, 0);
}

sub create_docview {
	my ($self, $file) = @_;

	$self->pool->add_work({ build_render_thread => { id => $self->id,
		data=> { action => 'build_render_thread', file => $file }
	}});
}

sub create_docview_post_thread {
	my ($self, $job) = @_;

	my $id = 'doc_'.scalar @{$self->doc_view};
	my $file = $job->{data}{file};
	my $dv = Folio::Viewer::Component::DocView->new(file => $file, id => $id);
	$self->register_docview($dv);
	#$dv->pool($self->pool);
	$dv->pool($job->{data}{render_thread});
	push @{$self->cleanup->{join}}, $job;
		# TODO store this in a DS to join using threadpool
	$dv->show;
}

sub request_cleanup {#{{{
	my ($self) = @_;
	#print "repeat\n";
	$self->process_done_queue($self->pool->done);
	for(grep { /^doc_/ } keys %{$self->components}) {
		my $queue = $self->components->{$_}->pool->done;
		$self->process_done_queue($queue);
	}
}#}}}

sub process_done_queue {
	my ($self, $queue) = @_;
	while(defined(my $done_job = $queue->dequeue_nb)) {
		return unless ${$self->request_cleanup_repeat};
		next unless exists $done_job->{id};
		next unless exists $self->components->{$done_job->{id}};
		$self->components->{$done_job->{id}}->publish($done_job);
	}
}

sub publish {
	my ($self, $job) = @_;
	if( $job->{data}{action} eq 'build_render_thread_post') {
		$self->create_docview_post_thread($job);
	}
}

sub register_query {

}

sub add_handlers {
	my ($self) = @_;
}

1;
