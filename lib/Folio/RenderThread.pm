package Folio::RenderThread;

use strict;
use warnings;
use Moo;
use Thread::Queue;
use Folio::Viewer::PageManager::PDF;
use Folio::Viewer::Tkx::Imager;

has work => ( is => 'rw', default => sub { Thread::Queue->new; } );
has done => ( is => 'rw', default => sub { Thread::Queue->new; } );

has file => ( is => 'rw' );
has page_manager => ( is => 'lazy' );
has document => ( is => 'lazy' );

sub _build_page_manager {#{{{
	 Folio::Viewer::PageManager::PDF->new();
}#}}}

sub add_work {
	my ($self, @work) = @_;
	my $id = $self->work->enqueue(@work);
}

sub run {
	my ($self) = @_;
	while(defined(my $work = $self->work->dequeue)) {
		my $job = $work->{doc_pdf};
		if($job->{data}->{action} eq 'render_page') {
			$job->{data}{action} = 'render_page_post';
			my $file = $job->{data}{file};
			my $page = $job->{data}{page};
			my $zoom = $job->{data}{zoom};
			$job->{data}{image_data} = Folio::Viewer::Tkx::Imager->get_tk_image_data(
				$self->page_manager->get_document_page_imager($file, $page, $zoom ));
			$self->done->enqueue($job);
		}
	}
}

sub stop {
	my ($self) = @_;
	$self->add_work(undef); # TODO: perhaps replace with actual message
}

1;
