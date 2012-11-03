package Folio::Viewer::Tkx::Canvas;

use strict;
use warnings;
use Moo;

has canvas => ( is => 'rw' );

# From <http://wiki.tcl.tk/1415>
## Tcl code {{{
###  MAK - Finding Visible or Partly Visible Items
###
###  This function will return all of the tags for items that are currently visible (either entirely visible if partial is 0 or partly off-screen if partial is 1) within the canvas, provided you've got your scroll region set correctly.
###
###   proc canvasVisibleTags { hWnd {partial 1} } {
###      foreach { xmin ymin xmax ymax } [$hWnd cget -scrollregion] break
###      foreach { y1 y2 } [$hWnd yview] break
###      foreach { x1 x2 } [$hWnd xview] break
###
###      set top   [expr {($ymax - $ymin) * $y1 + $ymin}]
###      set bot   [expr {($ymax - $ymin) * $y2 + $ymin}]
###      set left  [expr {($xmax - $xmin) * $x1 + $xmin}]
###      set right [expr {($xmax - $xmin) * $x2 + $xmin}]
###
###      if {$partial} {
###          return [$hWnd find overlapping $left $top $right $bot]
###      } else {
###          return [$hWnd find enclosed $left $top $right $bot]
###      }
###   }
## }}}
sub canvas_visible_tags {#{{{
	my ($self, $partial) = @_;
	my $canvas = $self->canvas;
	$partial //= 1;
	my ($xmin, $ymin, $xmax, $ymax) =  Tkx::SplitList($canvas->cget('-scrollregion'));
	my ($y1, $y2) = Tkx::SplitList($canvas->yview);
	my ($x1, $x2) = Tkx::SplitList($canvas->xview);

	my $top   = ($ymax - $ymin) * $y1 + $ymin;
	my $bot   = ($ymax - $ymin) * $y2 + $ymin;
	my $left  = ($xmax - $xmin) * $x1 + $xmin;
	my $right = ($xmax - $xmin) * $x2 + $xmin;

	my @list;
	if($partial) {
		@list = Tkx::SplitList($canvas->find_overlapping($left, $top, $right, $bot));
	} else {
		@list = Tkx::SplitList($canvas->find_enclosed($left, $top, $right, $bot));
	}
	#print "@list\n";
	return [map { Tkx::SplitList($canvas->gettags($_)) } @list];
}#}}}

sub canvas_withtag {#{{{
	my ($self, $tag) = @_;
	my $canvas = $self->canvas;
	return Tkx::SplitList($canvas->find_withtag($tag));
}#}}}


1;
