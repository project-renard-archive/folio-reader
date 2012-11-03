package Folio::Viewer::Tkx::TextANSI;

use strict;
use warnings;

sub add_ANSI_tags {
	my ($self, $text_widget) = @_;
	my $colors = [qw/Black DarkRed DarkGreen Yellow4 DarkBlue DarkMagenta
		DarkCyan White/];
	my $bright_colors = [qw/Black Red Green Yellow4 Blue Magenta Cyan
		White/];
	for my $fg (0..@$colors-1) {
		$text_widget->tag_configure("ansi3$fg",
			-background => 'white', -foreground => $colors->[$fg],
			);
		$text_widget->tag_configure("ansi9$fg",
			-background => 'white', -foreground => $bright_colors->[$fg]
			);
	}
}

sub insert_ANSI_text {
	my ($self, $text_widget, $text) = @_;
	my $tag = "";
	my $pos;
	while($text =~ /\G([^\x1b]*)(\x1b\[[0-9]*m)*/gms) {
		my $text = $1;
		my $color = $2 // "";
		$pos = pos();
		$text_widget->insert_end($text, $tag);
		while($color =~ /\G\x1b\[([0-9]*)m/g) {
			my $color_code = $1;
			#print "$color_code\n";
			if($color_code eq 0 or $color_code eq 39 or $color_code eq 99) {
				$tag = "";
			} elsif($color_code =~ /[39][0-7]/) {
				$tag = "ansi$color_code";
			}
		}
		pos($pos);
	}
}

sub add_tags {
	# Set up ANSI tags for text {{{
	Folio::Viewer::Tkx::TextANSI->add_ANSI_tags($mainWindow{retrieval_resultsinfo_text});
	$mainWindow{retrieval_resultsinfo_text}->tag_raise('sel');
	#}}}
}

1;
