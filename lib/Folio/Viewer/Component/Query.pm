package Folio::Viewer::Component::Query;

use strict;
use warnings;
use Moo;

has main_window => ( is => 'rw' );

sub init {
		my ($self) = @_;
}

sub add_query_window {

}
# TODO
sub  addRetrievalWindow {#{{{
	$mainWindow{retrieval} = $mainWindow{mw}->new_toplevel;

	$mainWindow{retrieval}->g_wm_title("Search");


	($mainWindow{retrieval_paned} = $mainWindow{retrieval}->new_ttk__panedwindow(-orient => 'vertical'))
		->g_pack(-expand => 1, -fill => 'both');
	# Search frame {{{
	$mainWindow{retrieval_search} = $mainWindow{retrieval}->new_ttk__frame();

	($mainWindow{retrieval_search_label} = $mainWindow{retrieval_search}->new_ttk__label())->g_pack(-side => 'left');
		$mainWindow{retrieval_search_label}->configure( -text => "Search");
	($mainWindow{retrieval_search_entry} = $mainWindow{retrieval_search}
		->new_tk__text(-height => 1, -wrap => 'word'));
	($mainWindow{retrieval_search_entry_yscroll} = $mainWindow{retrieval_search}
		->new_ttk__scrollbar(-orient => 'vertical',
			-command => [$mainWindow{retrieval_search_entry}, 'yview']));
	$mainWindow{retrieval_search_entry_yscroll}->g_pack(-side => 'right', -fill => 'y');
	$mainWindow{retrieval_search_entry}->g_pack(-side => 'right', -fill => 'both', -expand => 1);
	$mainWindow{retrieval_search_entry}
		->configure(-yscrollcommand => [$mainWindow{retrieval_search_entry_yscroll}, 'set']);
	$mainWindow{retrieval_search_entry_yscroll}->g___autoscroll__autoscroll;
	# }}}
	# Results frame {{{
	$mainWindow{retrieval_resultsframe} = $mainWindow{retrieval}
		->new_ttk__frame(-borderwidth => 2, -relief => "sunken", -width => 100, -height => 100);

	# Listbox {{{
	$mainWindow{retrieval_resultsframe_list} = $mainWindow{retrieval_resultsframe}
		->new_tk__listbox();
	$mainWindow{retrieval_resultsframe_yscroll} = $mainWindow{retrieval_resultsframe}
		->new_ttk__scrollbar(-orient => 'vertical',
			-command => [$mainWindow{retrieval_resultsframe_list}, 'yview']);
	$mainWindow{retrieval_resultsframe_list}
		->configure(-yscrollcommand => [$mainWindow{retrieval_resultsframe_yscroll}, 'set']);
	$mainWindow{retrieval_resultsframe_list}->g_pack(-side => 'left', -fill => 'both', -expand => 1);
	$mainWindow{retrieval_resultsframe_yscroll}->g_pack(-side => 'right', -fill => 'y');
	$mainWindow{retrieval_resultsframe_yscroll}->g___autoscroll__autoscroll;

	# }}}
	# }}}
	# Results info frame {{{
	$mainWindow{retrieval_resultsinfo} = $mainWindow{retrieval}
		->new_ttk__frame(-borderwidth => 2, -relief => "sunken", -width => 100, -height => 100);
	$mainWindow{retrieval_resultsinfo_text} = $mainWindow{retrieval_resultsinfo}
		->new_tk__text(-height => 10, -wrap => 'word');
	$mainWindow{retrieval_resultsinfo_yscroll} = $mainWindow{retrieval_resultsinfo}
		->new_ttk__scrollbar(-orient => 'vertical',
			-command => [$mainWindow{retrieval_resultsinfo_text}, 'yview']);
	$mainWindow{retrieval_resultsinfo_yscroll}->g_pack(-side => 'right', -fill => 'y');
	$mainWindow{retrieval_resultsinfo_text}->g_pack(-side => 'right', -fill => 'both', -expand => 1);
	$mainWindow{retrieval_resultsinfo_text}
		->configure(-yscrollcommand => [$mainWindow{retrieval_resultsinfo_yscroll}, 'set']);
	$mainWindow{retrieval_resultsinfo_yscroll}->g___autoscroll__autoscroll;
	# }}}
	# Paned window  {{{
	$mainWindow{retrieval_paned}->add($mainWindow{retrieval_search});
	$mainWindow{retrieval_paned}->add($mainWindow{retrieval_resultsframe});
	$mainWindow{retrieval_paned}->add($mainWindow{retrieval_resultsinfo});
	# }}}
	# [old] Grid layout {{{

	#$mainWindow{retrieval_search}->g_grid(-column => 0, -row => 0, -sticky => "nesw");
	#$mainWindow{retrieval_resultsframe}
		#->g_grid(-column => 0, -row => 1, -columnspan => 2, -sticky => "nesw");
	#$mainWindow{retrieval_resultsinfo}
		#->g_grid(-column => 0, -row => 2, -columnspan => 2, -sticky => "nesw");
	#$mainWindow{retrieval}->g_grid_columnconfigure(0, -weight => 1);
	#$mainWindow{retrieval}->g_grid_rowconfigure(1, -weight => 1);
	#$mainWindow{retrieval}->g_grid_rowconfigure(2, -weight => 1);

	#}}}

	#$mainWindow{retrieval}->g_wm_geometry("300x400")
}#}}}

sub fetch_results {#{{{
	my $query_text = $mainWindow{retrieval_search_entry}->get("1.0", "end");
	my $query = $fetcher->query('Google::Scholar', $query_text );
	$results = $query->entries; # GLOBAL
	$current_doc = undef;
	$results = [ # TODO only results which have a sciencedirect link
		grep {
			grep { $_ =~ /sciencedirect/ } @{$_->info->{link}}
		} @$results
	];
	my @list = map {join ' ', @{ $_->info->{title}} } @$results;
	$mainWindow{retrieval_resultsframe_list}->delete(0, 'end');
	$mainWindow{retrieval_resultsframe_list}->insert(0, @list);
	my $show_result_info_cb = sub {
		my $select = $mainWindow{retrieval_resultsframe_list}->curselection;
		if($select >= 0) {
			#use DDP; p $mainWindow{retrieval_resultsinfo_text}->tag_names;
			$current_doc = $results->[$select];
			use DDP; my $str = p($current_doc->info, colored => 1);
			$mainWindow{retrieval_resultsinfo_text}->delete('1.0', 'end');
			Folio::Viewer::Tkx::TextANSI->insert_ANSI_text(
				$mainWindow{retrieval_resultsinfo_text},
				$str);
		}
	};
	my $get_pdf = sub {
		my $select = $mainWindow{retrieval_resultsframe_list}->curselection;
		if($select >= 0) {
			fetch_doc($results->[$select]);
		}
	};
	$mainWindow{retrieval_resultsframe_list}->g_bind("<<ListboxSelect>>", $show_result_info_cb);
	$mainWindow{retrieval_resultsframe_list}->g_bind("<Control-g>", $get_pdf);
	$mainWindow{retrieval_resultsinfo_text}->g_bind("<Control-g>", sub {
		fetch_doc($current_doc) if defined $current_doc;
	});
}#}}}

sub fetch_doc {#{{{
	my ($result) = @_;
	my $links = $result->info->{link};
	my $sd_link = [grep { $_ =~ /sciencedirect/ } @$links]->[0];
	use DDP; p $sd_link;
	#my $pdf_response =
	fetch_progress_dialog(
		['ScienceDirect', $sd_link->as_string],
		(join ' ', @{$result->info->{title}}),
	);
}#}}}
sub fetch_progress_dialog {#{{{
	my ($doc_param, $info) = @_;
	my $cur_req = $request_num++;
	#my $done_var :shared;
	#$done_var = "progress_done$cur_req";
	#Tkx::set("$done_var" => 0);
	my $data = {
		action => 'get_doc',
		doc_id => $cur_req,
		doc_param => $doc_param,
		progress_max => 1000,

	};
	# Widgets{{{
	my $dialog = $mainWindow{retrieval}->new_toplevel;
	$dialog->new_ttk__label(-text => $info)->g_pack(-side => 'top');
	my $progressbar = $dialog->new_ttk__progressbar(-orient => 'horizontal', -maximum => $data->{progress_max},
		-length => 200, -mode => 'determinate');
	$progressbar->g_pack(-side => 'bottom');
	#}}}
	#$request_doc{$cur_req} = $doc;
	$data->{progressbar} = $progressbar;
	my $h = shared_clone($data);
	push @request_todo, $h;

	#Tkx::vwait("$done_var");
	##my $data = $requests_done_thr_data{$done_var};
	#return $data;
}#}}}

1;
