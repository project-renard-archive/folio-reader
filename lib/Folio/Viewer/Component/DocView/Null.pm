package Folio::Viewer::Component::DocView::Null;

use strict;
use warnings;
use Moo;

has docview => ( is => 'rw', weak_ref => 1 );
	
sub load {
	my ($self) = @_;
	$self->docview->_widgets->{cv}->configure(
		-scrollregion => qq/0 0 0 0/);
}
sub unload { }

sub publish {}

sub render_pages {}



1;
