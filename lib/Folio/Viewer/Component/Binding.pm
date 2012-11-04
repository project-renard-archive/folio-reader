package FIXME;

use strict;
use warnings;
# FIXME
# use Moose;

sub add_bind {
	# Canvas scroll bindings {{{
	$mainWindow{cw}->g_bind('q', [sub {cleanup(); done(); }]);
	# }}}

	#$mainWindow{retrieval_search_entry}->g_bind('<KeyPress>', [ sub { print "Moo\n"; }, 1 ] );
	#$mainWindow{retrieval_search_entry}->g_bind('<Shift-Return>', [ sub { print "Eep\n"; Tkx::continue; }, 1 ] );
	$mainWindow{retrieval_search_entry}->g_bind('<Control-g>', [ sub { fetch_results() }, 1 ] );
	#$mainWindow{retrieval_search_entry}->g_bind(q/<Key>/, [sub { print  "You pressed the key called @_\n"; }, Tkx::Ev('%K', '%s') ]);
}


# FIXME
# no Moose;
# __PACKAGE__->meta->make_immutable;
# FIXME
1;
