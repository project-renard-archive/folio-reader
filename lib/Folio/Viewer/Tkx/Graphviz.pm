package Folio::Viewer::Tkx::Graphviz;

use strict;
use warnings;
# FIXME
# use Moose;

sub test {
return <<'EOF'
Graphviz to canvas
    use DDP; p $mainWindow{cw_cv};
    my $g = Tkx::widget->new( Tkx::dotnew( digraph => rankdir => 'LR' ) );
    use DDP; p $g;
    $g->setnodeattribute(style => qw/filled color white/);
    Tkx::widget->new($g->addnode('Hello'))->addedge(Tkx::widget->new($g->addnode('World!')));
    $g->layout;
    use DDP; $g->render;
    Tkx::eval($g->render($mainWindow{cw_cv}));
EOF
;
}

# FIXME
# no Moose;
# __PACKAGE__->meta->make_immutable;
# FIXME
1;
