package Folio::App;

use 5.010;
use strict;
use warnings;
use Tkx;
BEGIN {
	Tkx::package_require("Img");
	Tkx::package_require("Tcl");
	Tkx::package_require("autoscroll");
	Tkx::package_require("Tcldot");
	Tkx::package_require("Tablelist");
}
use Moo;
use MooX::Types::MooseLike::Base qw(:all);
with qw(Folio::Viewer::Component::Role::Widget);

use Folio::Viewer::Tkx::Progress;
use Folio::Viewer::Component::ProgressManager;
use Folio::Viewer::Tkx::Icons;
use Folio::Viewer::Component::DocView;

has main_window => ( is => 'lazy');
has icons => ( is => 'lazy' );
has progress_manager => ( is => 'lazy' );

has doc_view => ( is => 'rw', isa => ArrayRef, default => sub { [] } );

sub _build_main_window {
	Tkx::widget->new('.');
}

sub _build_progress_manager {
	my ($self) = @_;
	Folio::Viewer::Component::ProgressManager->new(
		main_window => $self->main_window, icons => $self->icons );
}

sub _build_icons {
	Folio::Viewer::Tkx::Icons->new(icons => [qw/actrun22 actstop22/]);
}

sub run {
	my ($self, $ARGV) = @_;
	$self->icons;
	$self->add_buttons();
	$self->main_window->g_wm_geometry(q{+0+0});
	$self->progress_manager->show;
	$self->add_handlers;
	for my $file (@$ARGV) {
		$self->create_docview($file)->show;
	}
	Tkx::MainLoop();
	return 0;
}

sub add_buttons {
	my ($self) = @_;
	($self->_widgets()->{button_one} =
		$self->main_window->new_ttk__button(-text => 'one' ))
		->g_pack;
	($self->_widgets()->{button_two} =
		$self->main_window->new_ttk__button(-text => 'two' ))
		->g_pack;
}

sub register_docview {
	my ($self, $dv) = @_;
	push @{$self->doc_view}, $dv;
}

sub create_docview {
	my ($self, $file) = @_;
	my $id = scalar @{$self->doc_view};
	my $dv = Folio::Viewer::Component::DocView->new( main_window => $self->main_window,
		file => $file, id => $id);
	$self->register_docview($dv);
	$dv;
}

sub register_query {

}

sub add_handlers {
	my ($self) = @_;
}

1;
__END__

#use Memoize;
#memoize('_memo_help');
use List::Util;
use File::Temp qw/ tempfile /;
use File::Basename;
use File::Slurp qw/write_file/;
use PDL;
#use PDL::NiceSlice;

use Carp;

use Folio::Viewer::PageManager::PDF;
use Folio::Viewer::Tkx::TextANSI;
use Folio::Viewer::Tkx::Imager;
use Folio::Viewer::Tkx::Timer;

use threads;
use threads::shared;

use Fetch::Paper;
use Fetch::Paper::Proxy;
#}}}
# Variables {{{
my $file; # filename
my $doc; # MuPDF::Easy::Doc
my $doc_bounds; # PDL

my $manage = Folio::Viewer::PageManager::PDF->new;
my $fetcher = Fetch::Paper->new();
my $proxy = Fetch::Paper::Proxy->new( fetch => $fetcher );

my $results; # arrayref of results
my $current_doc; # current selected document to load from $results

my $thread;
my $thread_run :shared; $thread_run = 1;
my $thread_done :shared; $thread_done = 0;
my $request_num = 0;
my $response_num = 0;
my @request_todo :shared;
my %request_doc :shared;
my @response_done :shared;
my $request_cleanup_repeat = 1;
#my $response_cleanup_repeat = 1;
my $progress_var :shared;

my %mainWindow; # widgets
#}}}
# Create windows {{{
sub addMainWindow {#{{{
    $mainWindow{mw} = Tkx::widget->new('.');
    ($mainWindow{main_page_image} = $mainWindow{mw}->new_ttk__label())->g_pack;
}#}}}

#}}}
# Fetch data {{{
sub request_worker {#{{{
	while($thread_run) {
		while(@request_todo) {
			my $req = shift @request_todo;
			if($req->{action} eq 'get_doc') {
				my %data;
				$data{max} = $req->{progress_max};
				my $fetcher = Fetch::Paper->new();
				my $proxy = Fetch::Paper::Proxy->new( fetch => $fetcher );
				my $doc_param = [$req->{doc_param}->[0], URI->new($req->{doc_param}->[1])];
				use DDP; p $doc_param;
				my $doc = $fetcher->doc(@$doc_param, proxy => $proxy);
				my $response = $doc->get_pdf(':content_cb' => sub {
					my ($chunk, $response, $protocol) = @_;
					$data{bytes} += length $chunk;
					$data{content} .= $chunk;
					if($data{content_length}) {
						$data{progress} = int($data{max}*$data{bytes}/$data{content_length});
						push @response_done, shared_clone({progressbar => $req->{progressbar},
							action => 'update_progress',
							value => $data{progress} });
						$progress_var = $data{progress};
						print $data{progress}, "\n";
					} elsif($response->content_length) {
						$data{content_length} = $response->content_length;
					}
				});
				$response->content($data{content});
				my $h = shared_clone({
					action => 'open_doc',
					response => $response,
					doc_id => $req->{doc_id},
				});
				push @response_done, $h;
			}
		}
		sleep 3;
	}
	$thread_done = 1;
}#}}}
sub request_cleanup {#{{{
	while(@response_done) {
		return unless $request_cleanup_repeat;
		my $resp = shift @response_done;
		if($resp->{action} eq 'update_progress') {
			$resp->{progressbar}->configure(-value => $resp->{value});
			Tkx::update();
		} elsif($resp->{action} eq 'open_doc') {
			write_and_open_response($resp->{response});
			# TODO : do something with $request_doc{$resp->{doc_id}};
		}
	}
}#}}}
#}}}

sub init_main {#{{{
	Tkx::ttk__style_theme_use("clam");
	addMainWindow();
	addRetrievalWindow();
	addCanvasWindow();
}#}}}
sub cleanup {#{{{
	$thread_run = 0;
	while(not $thread_done and @response_done) {
		sleep 1;
	}
	$request_cleanup_repeat = 0;
	Tkx::destroy($mainWindow{mw});
}#}}}
sub done {#{{{
	#exit;
}#}}}
sub main {#{{{
	init_main;
	if(@ARGV) {
		open_file(shift @ARGV)
	} else {
		$mainWindow{mw}->g_wm_title("tk pdf");
		$mainWindow{mw}->g_wm_minsize( 300, 400 ); 
	}
	$thread = threads->new(\&request_worker);
	Folio::Viewer::Tkx::Timer::repeat(50, \&request_cleanup, \$request_cleanup_repeat);
	#Tkx::after( idle => sub {
		#repeat(3000, \&file_opener , \$file_open_repeat);
	#} );
	Tkx::MainLoop();
	$thread->join;

	return 0;
}#}}}

1;
