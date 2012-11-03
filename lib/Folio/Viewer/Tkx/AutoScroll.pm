package Folio::Viewer::Tkx::AutoScroll;

use strict;
use warnings;
use Moo;

has widget => ( is => 'rw' );
has type => ( is => 'rw', default => sub { 'xy' } );
has default_commands => ( is => 'rw', default => sub { 1 } );
has autoscroll => ( is => 'rw', default => sub { 1 } );

has xscroll => ( is => 'rw' );
has yscroll => ( is => 'rw' );

sub BUILD {
	my ($self) = @_;
	my $parent = Tkx::widget->new($self->widget->g_winfo_parent);

	my $x = $self->type =~ 'x';
	my $y = $self->type =~ 'y';
	if($x) {
		$self->xscroll($parent->new_ttk__scrollbar(-orient => 'horizontal',
				-command => [$self->widget, 'xview']));
		$self->xscroll->g___autoscroll__autoscroll if $self->autoscroll;
	}
	if($y) {
		$self->yscroll($parent->new_ttk__scrollbar(-orient => 'vertical',
				-command => [$self->widget, 'yview']));
		$self->yscroll->g___autoscroll__autoscroll if $self->autoscroll;
	}
	if($self->default_commands) {
		$self->widget->configure(-xscrollcommand => [$self->xscroll, 'set']) if $x;
		$self->widget->configure(-yscrollcommand => [$self->yscroll, 'set']) if $y;
	}
}

1;
