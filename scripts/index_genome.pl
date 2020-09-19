#
# Perform the per-genome indexing for the given genome(s), as if it were being installed
# from scratch.
#

use strict;
use FIG;
use FIG_Config;

@ARGV > 1 or die "Usage: index_genome User genome-id [genome-id ...]\n";

my $user = shift;

my $fig = new FIG;

for my $g (@ARGV)
{
    if (-d $fig->organism_directory($g))
    {
	$fig->index_genome($g, $user);
    }
}
    
