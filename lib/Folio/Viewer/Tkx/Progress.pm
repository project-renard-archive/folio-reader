package Folio::Viewer::Tkx::Progress;

use strict;
use warnings;
use base qw(Tkx::widget Tkx::MegaConfig);

__PACKAGE__->_Mega('tkx_Progress');

__PACKAGE__->_Config(
    DEFAULT => ['.p'],
    -label  => [[".lab" => "-text"]],
    -done => ["METHOD"],
    -cancel => ["METHOD"],
    -id => ["PASSIVE"],
);

my $cancelled = 0;
my $progressbar;

sub _Populate {
    my($class, $widget, $path, %opt) = @_;

    my $self = $class->new($path)->_parent->new_frame(-name => $path, -class => "Tkx_Progress");
    $self->_class($class);

    $self->new_label(-name => "lab", -text => delete $opt{-label})->g_pack(-side => "left");
    ($progressbar = $self->new_ttk__progressbar(-name => "p",
	    -orient => 'horizontal', -mode => 'determinate', %opt))->_pack_left_fill;

    $self;
}

sub _pack_left_fill {
	my ($widget) = @_;
	$widget->g_pack(-side => "left", -fill => "both", -expand => 1);
}

# readonly, checks if value is at maximum
sub _config_done {
	my ($self) = @_;
	return $self->cget('-value') == $self->cget('-maximum');
}

sub _config_cancel {
	my ($self) = @_;
	shift;
	if(@_) {
		$cancelled = $_[0];
		# disable progressbar
		$self->configure(-state => ($_[0] ? '' : '!').'disabled');
		return;
	}
	return $cancelled;
}

1;
