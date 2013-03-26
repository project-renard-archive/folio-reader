package Folio::Viewer::Component::DocView::Null;

use strict;
use warnings;
use Moo;
with qw(Folio::Viewer::Component::DocView::CanvasManagerRole);

sub load {
	my ($self) = @_;
	$self->docview->_widgets->{cv}->configure(
		-scrollregion => qq/0 0 0 0/);
}

1;
