package Folio::Worker::build_render_thread;

use strict;
use warnings;
use Folio::RenderThread;
use forks;

sub work {
	my ($self, $job) = @_;
	if($job->{data}->{action} eq 'build_render_thread') {
		$job->{data}{action} = 'build_render_thread_post';
		$job->{data}{render_thread} = Folio::RenderThread->new();
		$job->{data}{tid} = threads->create( sub {
			$job->{data}{render_thread}->run
		});
	}
	return $job;
}


1;
