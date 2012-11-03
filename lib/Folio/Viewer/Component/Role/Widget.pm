package Folio::Viewer::Component::Role::Widget;

use strict;
use warnings;
use Moo::Role;
use MooX::Types::MooseLike::Base qw(:all);
# idea from <https://metacpan.org/module/Tk::Role::HasWidgets>

has _widgets => (
	is => 'rw',
	isa => HashRef,
	default => sub { {} },
);

1;
