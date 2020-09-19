# -*- perl -*-
#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
# 
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License. 
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#


use strict;
use FIG;
my $fig = new FIG;

use Tracer;

# usage: load_distances

my $temp_dir = $FIG_Config::temp;
Trace("Loading distances.") if T(2);
open(REL,">$temp_dir/tmp$$") || die "could not open $temp_dir/tmp$$";

my @genomes = sort { $a <=> $b } $fig->genomes("complete");
Trace("Complete genomes selected.") if T(2);

my($i,$j,$dist);
my $genomeCount = $#genomes;
for ($i=0; ($i < $genomeCount); $i++)
{
	Trace("Computing distances for genome $i of $genomeCount.") if T(3);
    for ($j=$i+1; ($j < @genomes); $j++)
    {
		# Use the estimator that does NOT rely on the database.
		$dist = $fig->crude_estimate_of_distance1($genomes[$i],$genomes[$j]);
		print REL "$genomes[$i]\t$genomes[$j]\t$dist\n";
    }
}
close(REL);
$fig->reload_table('all', "distances",
				   "genome1 varchar(16), genome2 varchar(16), dist float",
				   { distances_ix => "genome1, genome2" },
					"$temp_dir/tmp$$");
unlink("$temp_dir/tmp$$");
Trace("Distances loaded.") if T(2);
