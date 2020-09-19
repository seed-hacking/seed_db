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

my($ln,$seek1,$seek2,$role);

# usage: index_neighborhoods


my $fig = new FIG;
my $temp_dir = "$FIG_Config::temp";
my $seekFile = "$temp_dir/tmp$$.seeks";
Open(\*SEEKS, ">$seekFile");
Open(\*NEIGH, "<$FIG_Config::global/role.neighborhoods");
Trace("Parsing neighborhood file.") if T(2);
$/ = "\n//\n";
$seek1 = tell NEIGH;
while (defined($_ = <NEIGH>))
{
    $seek2 = tell NEIGH;
    $ln = $seek2 - $seek1;
    if ($_ =~ /^(\S[^\n]*\S)/)
    {
		$role = $1;
		print SEEKS "$role\t$seek1\t$ln\n";
    }
    else
    {
		Trace("Invalid neighborhood role \"$_\".") if T(0);
    }
    $seek1 = $seek2;
}
close(NEIGH);
close(SEEKS);    
$/ = "n";

$fig->reload_table('all', 'neigh_seeks',
				   "role varchar(255) NOT NULL, seek INTEGER, len INTEGER, PRIMARY KEY ( role )",
				   { },
				   $seekFile);
unlink("$seekFile");
Trace("Neighborhoods indexed.") if T(2);
