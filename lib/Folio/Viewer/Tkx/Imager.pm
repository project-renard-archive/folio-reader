package Folio::Viewer::Tkx::Imager;

use strict;
use warnings;
use Imager;
use MIME::Base64;
use Tkx;

sub get_tk_image {
	Tkx::image_create_photo(-data => &get_tk_image_data);
}

sub get_tk_image_data {
	my ($self, $imager) = @_;
	my $image_data;
	$imager->write(data =>\$image_data, type=>'png')
		or die "Cannot save image: ", $imager->errstr;
	# supplying binary data didn't work, so we base64 encode it
	$image_data = encode_base64($image_data);
	$image_data;
}

1;
