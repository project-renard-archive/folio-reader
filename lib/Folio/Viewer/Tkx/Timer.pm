# vim: fdm=marker
package Folio::Viewer::Tkx::Timer;

use strict;
use warnings;

# timer for Tk {{{
# From <http://www.nntp.perl.org/group/perl.tcltk/2009/01/msg221.html>
# used to implement timer functionality in Tkx, will execute subroutine $pMy_sub every $millisecs milliseconds if $pEnabled
# repeat( $millisecs, $pMy_sub, $pEnabled )
sub repeat {
	my ( $ms, $pMy_sub, $pEnabled ) = @_;
	my $repeater; # repeat wrapper
	$repeater = sub {
		Tkx::after($ms, $repeater) if ( $$pEnabled ); #queue next run before running this instance to minimize timing error accrual
		$pMy_sub->(@_);
	};
	Tkx::after($ms, $repeater);
}#}}}

1;
