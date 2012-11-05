package Folio::Viewer::PageManager::PDF;

use strict;
use warnings;
use Moo;

use MuPDF::Easy;
use MuPDF::Easy::Transform;
use MuPDF::Easy::Pixmap;
use MuPDF::SWIG;

has _context => ( is => 'lazy' );

has _data => ( is => 'rw' , default => sub { {} }, clearer => '_clear__data' );

sub _build__context {
	MuPDF::Easy->new();
}

sub get_document {
	my ($self, $filename) = @_;
	my $doc = load_document(@_) unless($self->_data->{$filename}->{document});
}

sub get_document_page_imager {
	my ($self, $filename, $page_num, $zoom) = @_;

	my ($page, $transform, $bbox) = @{get_page_param(@_)};
	#use DDP; p ($page, $transform, $bbox);
	#use DDP; p $page;

	my $pixmap = MuPDF::Easy::Pixmap->new(fz_context => $self->_context->fz_context,
		bbox => $bbox,
		type => 'rgb' );
	$page->run_page($pixmap, $transform);
	my $imager = $pixmap->get_imager();
}

sub get_page_param {
	my ($self, $filename, $page_num, $zoom) = @_;
	$zoom //= 100;
	my $doc = $self->get_document($filename);
	my $page = $doc->get_page($self->_context->fz_context, $page_num);
	my $rect = $page->bounds;
	my $identity = MuPDF::Easy::Transform->identity;
	my $zoom_trans = MuPDF::Easy::Transform->percentage_zoom($zoom);
	my $transform = MuPDF::Easy::Transform->concat($zoom_trans, $identity);
	$rect = MuPDF::SWIG::fz_transform_rect($transform, $rect);
	my $bbox = MuPDF::SWIG::fz_round_rect($rect);
	return [$page, $transform, $bbox];
}

sub get_page_bounds {
	my ($self, $filename, $page_num, $zoom) = @_;
	my $bbox = get_page_param(@_)->[2];
	[$bbox->swig_x1_get - $bbox->swig_x0_get, $bbox->swig_y1_get - $bbox->swig_y0_get];
}

sub load_document {
	my ($self, $filename) = @_;
	$self->_data->{$filename}->{document} = $self->_context->get_document($filename);
}

sub DEMOLISH {
	my ($self) = @_;
	$self->_clear__data;
}


1;
