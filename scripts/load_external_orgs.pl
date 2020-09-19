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
use Tracer;

my $fig = new FIG;

my($temp_dir,$prot,$org);

# usage: load_extaernal_orgs


$temp_dir = $FIG_Config::temp;
my $orgFile = "$temp_dir/tmp$$";
Open(\*TAB, ">$orgFile");
Open(\*SPORG, "<$FIG_Config::global/ext_org.table");
Trace("Copying external organism file.") if T(2);
while (defined($_ = <SPORG>)) {
    chop;
    ($prot,$org) = split(/\t/,$_);
    if (defined($prot) && defined($org) && (length($org) < 64)) {
		print TAB "$prot\t$org\n";
    }
}
close(TAB);
close(SPORG);

$fig->reload_table('all', "external_orgs",
				   "prot varchar(32), org varchar(64)",
				   { external_orgs_ix => "prot" },
				   $orgFile);
unlink($orgFile);
Trace("External organisms loaded.") if T(2);
