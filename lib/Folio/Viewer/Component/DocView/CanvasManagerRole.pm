package Folio::Viewer::Component::DocView::CanvasManagerRole;

use strict;
use warnings;
use Moo::Role;

has docview => ( is => 'rw', weak_ref => 1 );

sub load {}
sub unload {}

sub publish {}

sub render_pages {}


1;
