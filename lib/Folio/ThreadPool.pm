package Folio::ThreadPool;

use strict;
use warnings;
use Moo;
use Folio::Worker;
use Thread::Pool::Simple;

has pool => ( is => 'lazy' );
has work => ( is => 'rw', default => sub { Thread::Queue->new; } );
has done => ( is => 'rw', default => sub { Thread::Queue->new; } );
has id => ( is => 'rw' );

sub add_work {
	my ($self, @work) = @_;
	my $id = $self->pool->add(@work);
}

sub do_handle {
	my ($id, $done_q, $work) = @_;
	$done_q->enqueue(Folio::Worker->work_router($work));
}

sub _build_pool {
	my ($self) = @_;
	Thread::Pool::Simple->new(
		min => 3,           # at least 3 workers
		max => 5,           # at most 5 workers
		load => 10,         # increase worker if on average every worker has 10 jobs waiting
		do => [\&do_handle, $self->done],     # job handler for each worker
		passid => 1,        # whether to pass the job id as the first argument to the &do_handle
		lifespan => 10000,  # total jobs handled by each worker
      );
}

sub start {
	# TODO NOP?
}

sub stop {
	# TODO
}


1;
