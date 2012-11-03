package Folio::Viewer::Component::ProgressManager;

use strict;
use feature 'state';
use warnings;
use Moo;
use MooX::Types::MooseLike::Base qw(:all);
with qw(Folio::Viewer::Component::Role::Widget);
use Folio::Viewer::Tkx::AutoScroll;

has main_window => ( is => 'rw' );
has _window => ( is => 'lazy' );
has _table_list => ( is => 'lazy' );
has progress_bars => ( is => 'rw', isa => HashRef, default => sub { {} }, );
has icons => ( is => 'rw' );

# TODO delete using splice
has _pb_widgets => ( is => 'rw', isa => ArrayRef, default => sub { [] }, );

has icon_working => ( is => 'lazy' );
has icon_stopped => ( is => 'lazy' );

sub add_progress {
	my ($self, $progress_widget) = @_;
	#$self->progress_bars->{$progress_widget->cget('-id')} = $progress_widget;
}

sub tbl_set_progress {
	my ($self, $row, $value) = @_;
	if(defined $value) {
		$self->_widgets->{tbl}
			->cellconfigure("$row,percent", -text => $value);
	} else {
		$value = $self->_widgets->{tbl}
				->cellcget("$row,percent", '-text');
	}
	$self->_pb_widgets->[$row]->configure(-value => $value) if defined $self->_pb_widgets->[$row];
	state $pb_cb  = sub {
		my ($tbl, $row, $col, $w) = @_;
		my $ww = Tkx::widget->new($w);
		my $t = Tkx::widget->new($tbl);
		my $percent = $t->cellcget("$row,percent", '-text');
		Tkx::ttk__progressbar($w, -maximum => 100, -value => $percent );
		$self->_pb_widgets->[$row] = $ww;
		$ww->g_bindtags(['TablelistBody']);
	};
	#unless($self->_widgets->{tbl}->cellcget("$row,percent", '-window')) {
	$self->_widgets->{tbl}->cellconfigure("$row,percent", -window => $pb_cb, -stretchwindow => 'yes');
	#}
}

sub tbl_set_status {
	my ($self, $row, $value) = @_;
	if(defined $value) {
		$self->_widgets->{tbl}
			->cellconfigure("$row,status", -text => $value);
	} else {
		$value = $self->_widgets->{tbl}
			->cellcget("$row,status", '-text');
	}
	$self->_widgets->{tbl}->cellconfigure("$row,status",
		-image => $self->icons->get_icon($value?'actrun22':'actstop22'));
	#state $lb_cb = sub {
		#my ($tbl, $row, $col, $w) = @_;
		#Tkx::widget->new($w);
		#my $t = Tkx::widget->new($tbl);
		#my $status = $t->cellcget("$row,status", '-text');
		#Tkx::ttk__label($w, -image => $self->icons->get_icon($status?'actrun22':'actstop22'),
			#-background => $t->cget('-background') );
		##$self->icons->get_icon('actrun22')
	#};
	#unless($self->_widgets->{tbl}->cellcget("$row,status", '-window')) {
		#$self->_widgets->{tbl}->cellconfigure("$row,status", -window => $lb_cb);

	#}
}

sub _build__window {
	my ($self) = @_;
	my $w = $self->main_window->new_toplevel(-name => 'pm');
	$self->_widgets->{tbl} = Tkx::widget->new($w.'.tbl');
	Tkx::tablelist__tablelist($self->_widgets->{tbl},
			-columns => [0, "Task",
				0, "Progress",
				0, "Running" ], -stretch => 'all');
	$self->_widgets->{tbl}->g_grid(-column => 0, -row => 0, -sticky => "nesw");

	$self->_widgets->{tbl}->columnconfigure(0, -name => 'task');
	$self->_widgets->{tbl}->columnconfigure(1, -name => 'percent', -stretchable => 'yes', -formatcommand => sub { '' });
	$self->_widgets->{tbl}->columnconfigure(2, -name => 'status', -formatcommand => sub { '' }, -resizable => '0');

	#$self->_widgets->{tbl}->g_bind('<Configure>', sub { $self->update_tbl });
	$self->update_tbl;

	$self->_widgets->{tbl_autoscroll} = Folio::Viewer::Tkx::AutoScroll
		->new(widget => $self->_widgets->{tbl});
	$self->_widgets->{tbl_autoscroll}->xscroll->g_grid(-column => 0, -row => 1, -sticky => "we");
	$self->_widgets->{tbl_autoscroll}->yscroll->g_grid(-column => 1, -row => 0, -sticky => "ns");
	$w->g_grid_columnconfigure(0, -weight => 1);
	$w->g_grid_rowconfigure(0, -weight => 1);

	$w->g_wm_protocol('WM_DELETE_WINDOW' => sub { $w->g_wm_withdraw; });
	$w->g_wm_withdraw;
	$w;
}

sub update_tbl {
	my ($self) = @_;
	for my $row (0..$self->_widgets->{tbl}->size()-1) {
		$self->tbl_set_progress($row);
		$self->tbl_set_status($row);
	}
}

sub send_progress {
	my ($self, $id, $num) = @_;
}

# TODO return $num
sub remove_progress {
	my ($self, $id) = @_;

}

sub hide {
	my ($self) = @_;
	$self->_window->g_wm_withdraw;
}

sub show {
	my ($self) = @_;
	$self->_window->g_wm_deiconify;
}

1;
