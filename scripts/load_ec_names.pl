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
use Tracer;

my $fig = new FIG;
Trace("Loading EC names.") if T(2);

Open(\*TMPIN, "<$FIG_Config::data/KEGG/ECtable");
my $tempFile = "$FIG_Config::temp/ec_names.table";
Open(\*TMPOUT, ">$tempFile");

while (defined($_ = <TMPIN>))
{
    if ($_ =~ /^\s*(\d+\.\d+\.\d+\.\d+)\s+(\S[^;\n]+)/)
    {
	print TMPOUT "$1\t$2\n";
    }
    elsif (/^D\s+(\d+\.\d+\.\d+\.\d+)\s+(\S[^;\n]+)/)
    {
	print TMPOUT "$1\t$2\n";
    }
	
}
close(TMPIN);
close(TMPOUT);

$fig->reload_table('all', "ec_names",
				   "ec varchar(12) UNIQUE NOT NULL, name varchar(200), PRIMARY KEY ( ec )",
				   { }, $tempFile);
unlink($tempFile);
undef $fig;
Trace("EC names loaded.") if T(2);
