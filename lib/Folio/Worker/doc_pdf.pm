package Folio::Worker::doc_pdf;

use strict;
use warnings;
use Folio::Viewer::PageManager::PDF;
use Folio::Viewer::Tkx::Imager;

my $pm = Folio::Viewer::PageManager::PDF->new();

sub work {
	my ($self, $job) = @_;
	if($job->{data}->{action} eq 'render_page') {
		$job->{data}{action} = 'render_page_post';
		my $file = $job->{data}{file};
		my $page = $job->{data}{page};
		$job->{data}{image_data} = Folio::Viewer::Tkx::Imager->get_tk_image_data(
			$pm->get_document_page_imager($file, $page));
	}
	return $job;
}


1;
