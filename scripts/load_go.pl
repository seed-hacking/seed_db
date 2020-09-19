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

my $usage = "usage: load_go";

use Tracer;

my $dbf = $fig->db_handle;

$dbf->drop_table( tbl => "go_terms" );
$dbf->create_table( tbl  => "go_terms",
		    flds => "go_id char(10), go_desc varchar(200), go_type char(1), obsolete char(3)"
            );

my $temp_dir = $FIG_Config::temp;

open(TMP,">$temp_dir/go.$$") || die "could not open temporary file";
if (open(GO,"<$FIG_Config::data/Ontologies/GO/GO.terms_ids_obs"))
{
    while (defined($_ = <GO>))
    {
	if ($_ =~ /^GO:\d{7}\t/)
	{
	    print TMP $_;
	}
    }
    close(GO);
}
close(TMP);

$dbf->load_table( tbl => "go_terms",
		  file => "$temp_dir/go.$$" );

unlink("$temp_dir/go.$$");

$dbf->create_index( idx  => "go_id_ix",
		    tbl  => "go_terms",
		    type => "btree",
		    flds => "go_id" );
$dbf->vacuum_it("go_terms");

$dbf->drop_table( tbl => "fr2go" );
$dbf->create_table( tbl  => "fr2go",
		    flds => "role varchar(200), go_id char(10)"
            );
$dbf->load_table( tbl => "fr2go",
		  file => "$FIG_Config::data/Ontologies/GO/fr2go" );
$dbf->create_index( idx  => "fr2go_fr_ix",
		    tbl  => "fr2go",
		    type => "btree",
		    flds => "role" );
$dbf->create_index( idx  => "fr2go_go_ix",
		    tbl  => "fr2go",
		    type => "btree",
		    flds => "go_id" );
$dbf->vacuum_it("fr2go");
