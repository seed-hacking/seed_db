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

# usage: load_protein_families

use Tracer;

my $dbf = $fig->{_dbf};

if (! -s "$FIG_Config::global/ProteinFamilies/localfam_function") { exit }

$dbf->drop_table( tbl => "localfam_function" );
$dbf->create_table( tbl => 'localfam_function',
		    flds => "family varchar(32), function varchar(256)"
		  );
print STDERR "Loading localfam_function\n";
$dbf->load_table( tbl => "localfam_function",
                  file => "$FIG_Config::global/ProteinFamilies/localfam_function" );
$dbf->create_index( idx  => "localfam_function_ix",
		    tbl  => "localfam_function",
		    type => "btree",
		    flds => "family, function" );

$dbf->vacuum_it("localfam_function");
print STDERR "Loaded localfam_function\n";

print STDERR "Loading localfam_cid\n";
$dbf->drop_table( tbl => "localfam_cid" );
$dbf->create_table( tbl => 'localfam_cid',
		    flds => "family varchar(32), cid integer"
		  );
$dbf->load_table( tbl => "localfam_cid",
                  file => "$FIG_Config::global/ProteinFamilies/localfam_cid" );

$dbf->create_index( idx  => "localfam_cid_fam_ix",
		    tbl  => "localfam_cid",
		    type => "btree",
		    flds => "family" );

$dbf->create_index( idx  => "localfam_cid_cid_ix",
		    tbl  => "localfam_cid",
		    type => "btree",
		    flds => "cid" );

$dbf->vacuum_it("localfam_cid");
print STDERR "Loaded localfam_cid\n";

print STDERR "Loading localid_cid\n";
$dbf->drop_table( tbl => "localid_cid" );
$dbf->create_table( tbl => 'localid_cid',
		    flds => "localid varchar(32), cid integer"
		  );
$dbf->load_table( tbl => "localid_cid",
                  file => "$FIG_Config::global/ProteinFamilies/localid_cid" );

$dbf->create_index( idx  => "localid_cid_localid_ix",
		    tbl  => "localid_cid",
		    type => "btree",
		    flds => "localid" );

$dbf->create_index( idx  => "localid_cid_cid_ix",
		    tbl  => "localid_cid",
		    type => "btree",
		    flds => "cid" );

$dbf->vacuum_it("localid_cid");
print STDERR "Loaded localid_cid\n";

# putting a conditional here because I am adding it later
if (-e "$FIG_Config::global/ProteinFamilies/id.map") 
{
 print STDERR "Loading id.map\n";
 $dbf->drop_table( tbl => "localid_map" );
 $dbf->create_table( tbl => 'localid_map',
                    flds => "family varchar(32), localid varchar(32)"
		   );
 $dbf->load_table( tbl => "localid_map",
 		   file => "$FIG_Config::global/ProteinFamilies/id.map" );

 $dbf->create_index( idx  => "localid_map_localid_ix",
		    tbl  => "localid_map",
		    type => "btree",
		    flds => "localid" );

 $dbf->create_index( idx  => "localid_map_fam_ix",
		    tbl  => "localid_map",
		    type => "btree",
		    flds => "family" );

 $dbf->vacuum_it("localid_map");
 print STDERR "Loaded localid_map\n";
}
 



Trace("Protein families loaded.") if T(2);
