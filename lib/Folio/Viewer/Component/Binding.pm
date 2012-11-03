package FIXME;

use strict;
use warnings;
# FIXME
# use Moose;

sub add_bind {
	# Page turn bindings {{{
	$mainWindow{mw}->g_bind('<Button-5>', [sub {update_label() if page_change(@_)}, 1]);
	$mainWindow{mw}->g_bind('<Button-4>', [sub {update_label() if page_change(@_)}, -1]);
	$mainWindow{mw}->g_bind('<space>', [sub {update_label() if page_change(@_)}, 1]);
	$mainWindow{mw}->g_bind('<b>', [sub {update_label() if page_change(@_)}, -1]);
	$mainWindow{mw}->g_bind('<Next>', [sub {update_label() if page_change(@_)}, 1]);
	$mainWindow{mw}->g_bind('<Prior>', [sub {update_label() if page_change(@_)}, -1]);
	$mainWindow{mw}->g_bind('q', [sub {cleanup(); done(); }]);
	#}}}
	# Canvas scroll bindings {{{
	$mainWindow{cw}->g_bind('<Button-5>', [sub {$mainWindow{cw_cv}->yview( scroll => @_, 'units')}, 1]);
	$mainWindow{cw}->g_bind('<Button-4>', [sub {$mainWindow{cw_cv}->yview( scroll => @_, 'units')}, -1]);
	$mainWindow{cw}->g_bind('<space>', [sub {$mainWindow{cw_cv}->yview( scroll => @_, 'units')}, 1]);
	$mainWindow{cw}->g_bind('<b>', [sub {$mainWindow{cw_cv}->yview( scroll => @_, 'units')}, -1]);
	$mainWindow{cw}->g_bind('<Next>', [sub {$mainWindow{cw_cv}->yview( scroll => @_, 'units')}, 1]);
	$mainWindow{cw}->g_bind('<Prior>', [sub {$mainWindow{cw_cv}->yview( scroll => @_, 'units')}, -1]);
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
