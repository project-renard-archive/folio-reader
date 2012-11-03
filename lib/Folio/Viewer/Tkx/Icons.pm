package Folio::Viewer::Tkx::Icons;

use strict;
use warnings;
use Moo;
use Tkx;
use File::Spec;
use List::Util qw/first/;
BEGIN {
	Tkx::package_require("icons");
	Tkx::namespace_import(q/icons::icons/);
}

has file => ( is => 'lazy' );
has icons => ( is => 'rw', trigger => 1);

sub _build_file {
	File::Spec->catfile((first { m,icons/?$, } split ' ', $ENV{TCLLIBPATH}),
		'tkIcons');
}

sub _trigger_icons {
	my ($self) = @_;
	Tkx::icons_create(-file => $self->file, $self->icons);
};

sub get_icon {
	return "::icon::"."$_[1]";
}

1;
