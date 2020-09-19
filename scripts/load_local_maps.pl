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


# -*- perl -*-

###########################################
use strict;

use FIG;
my $fig = new FIG;

my $usage = "usage: load_local_maps";

use DBrtns;

&load_ec_and_map_data;
undef $fig;

sub load_ec_and_map_data {
    
    my($map);

    my $dbf = $fig->{_dbf};

    #
    # If the proper directory structure is not there,
    # create it as empty.
    #

    my $mapdir = "$FIG_Config::data/MAP_SUPPORT";
    &FIG::verify_dir($mapdir);
    &FIG::verify_dir("$mapdir/Maps");

    if (! -f "$mapdir/INDEX")
    {
	open(my $fh, ">$mapdir/INDEX");
	close($fh);
	chmod 0777, "$mapdir/INDEX";
    }

    $dbf->load_table( tbl => "map_name",
		      file => "$FIG_Config::data/MAP_SUPPORT/INDEX"
		      );
    $dbf->vacuum_it("map_name");

    open(ECMAP,">$FIG_Config::temp/ec_map.table")
	|| die "could not open $FIG_Config::temp/ec_map.table";

    my @maps = `cut -f1 $FIG_Config::data/MAP_SUPPORT/INDEX | sort -u`;
    chop @maps;
	
    foreach $map (@maps)
    {
	foreach $_ (`cut -f1 $FIG_Config::data/MAP_SUPPORT/Maps/$map/role_coords.table | sort -u`)
	{
	    chop;
	    print ECMAP "$_\t$map\n";
	}
    }
    close(ECMAP);

    $dbf->load_table( tbl => "ec_map",
		      file => "$FIG_Config::temp/ec_map.table"
		      );
    
    $dbf->vacuum_it("ec_map");
    #unlink("$FIG_Config::temp/ec_map.table");
}

