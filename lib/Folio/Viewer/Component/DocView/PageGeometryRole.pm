package Folio::Viewer::Component::DocView::PageGeometryRole;

use strict;
use warnings;
use Moo::Role;
use PDL;
with qw(Folio::Viewer::Component::DocView::CanvasManagerRole);

has zoom => ( is => 'rw', default => sub{ 100; } );
has page_geometry => ( is => 'lazy', clearer => 1 );

sub _build_page_geometry {#{{{
	my ($self) = @_;
	my $doc_bounds = null;
	for my $page_num (0..$self->docview->document->page_count-1) {
		$doc_bounds = $doc_bounds->glue(1,pdl $self->docview->page_manager->get_page_bounds($self->docview->file,
			$page_num, $self->zoom));
	}
	croak("Size mismatch") unless $doc_bounds->dim(1) == $self->docview->document->page_count;
	$doc_bounds;
}#}}}

1;
