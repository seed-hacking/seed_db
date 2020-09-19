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

my $usage = "usage: load_sets Relation SetName ExternalTable";

my($relation,$set_name,$ext_table);
(($relation = shift @ARGV) &&
 ($set_name = shift @ARGV) &&
 ($ext_table = shift @ARGV)
) || Confess("Invalid parameter. Usage is \"$usage\".");

Trace("Loadsets for relation $relation with set $set_name from file $ext_table.") if T(2);
Trace("Creating genome map.") if T(2);
my %genomes = map { $_ => 1 } $fig->genomes;
my $copyFile = "$FIG_Config::temp/ext_table.$$";
Trace("Copying $ext_table.") if T(2);
Open(\*IN, "<$ext_table");
Open(\*OUT, ">$copyFile");
while ($_ = <IN>)
{
    if ($_ =~ /fig\|(\d+\.\d+)/)
    {
		if ($genomes{$1})
		{
			print OUT $_;
		}
    }
    else
    {
		print OUT $_;
    }
}
close(IN);
close(OUT);

$fig->reload_table('all', $relation,
				   "$set_name INTEGER, id varchar(255)",
				   { "$relation\_$set_name\_ix" => $set_name,
					 "$relation\_id_ix" => "id" },
				   $copyFile);
unlink($copyFile);
