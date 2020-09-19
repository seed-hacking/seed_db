# _perl_
#

=pod load_ss_classification.pl

Load the subsystem classifications from a text file. Take the excel file from Sveta, convert it to text, and use this to set the data structures. Note that this will completely overwrite whatever was there before.

There are two versions, just make sure your columns are in the appropriate order for the version that you are using.

=author

Rob Edwards, various versions 2004-2008

=cut

use strict;
use FIG;
my $fig=new FIG;

my $f = shift || die "File of new heirarchy?";
open(IN, $f) || die "Can't open $f";
while (<IN>)
{
	chomp;
	# change the next line depending on your order.
	my ($ss, $class1, $class2)=split /\t/;
	#my ($class1, $class2, $ss)=split /\t/;
	
	my $sub=$fig->get_subsystem($ss);
	#print STDERR "Adding $class1 :: $class2 :: $ss\n";
	$sub->set_classification([$class1, $class2]);
	$sub->write_subsystem();
}
close IN;

