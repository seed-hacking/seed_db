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


###########################################
use strict;

use FIG;
my $fig = new FIG;

# usage: load_patric_map patric-mapfile

#
# Load a file of patric/seed mappings. It is of the form
#
#   seed-id <tab> patric-id
#
#

@ARGV == 1 or die "Usage: load_patric_map patric-mapfile\n";
my $mapfile = shift;

my $dbf = $fig->{_dbf};

$dbf->reload_table('all', 'patric_map',
		   "patric varchar(32), fid varchar(64)",
	           { patric_map_fwd_ix => 'fid', patric_map_rev_ix => 'patric'},
		   $mapfile);
$dbf->finish_load('all', 'patric_map');
