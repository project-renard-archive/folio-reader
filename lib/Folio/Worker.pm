package Folio::Worker;

use strict;
use warnings;
use Module::Load;
use Folio::Worker::doc_pdf;

sub work_router {
	my ($self, $job_items) = @_;
	my @done;
	for my $work_type (keys %$job_items) {
		my $work_pkg = __PACKAGE__."::$work_type";
		#load($work_pkg) or die "Could not load $work_pkg";
		push @done, $work_pkg->work($job_items->{$work_type});
	}
	@done;
}

1;
