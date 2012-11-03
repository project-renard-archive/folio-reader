package Folio::Data::HTTPResponse;

use strict;
use warnings;
use Moo;
# TODO
sub write_and_open_response {#{{{
	my ($pdf_response) = @_;
	return unless $pdf_response->code == 200;
	my $pdf_filename = $pdf_response->filename;
	my ($name,undef,$suffix) = fileparse($pdf_filename,qw/pdf/);
	my ($fh, $filename) = tempfile( $name . 'XXXX' , SUFFIX => ".$suffix");
	write_file($filename, $pdf_response->decoded_content);
	close $fh;
	open_file($filename);
}#}}}


1;
