# -*- perl -*-
#
# Copyright (c) 2003-2008 University of Chicago and Fellowship
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

#
# usage: load_dlits
#
#  Uses files (only the first is essential):
#
#     $FIG_Config::data/Dlits/dlits
#     dlits
#     flds => "status char(1), md5_hash varchar(32), pubmed varchar(16), curator varchar(30), go_code varchar(15)"
#
#     $FIG_Config::data/Dlits/titles
#     pubmed_titles
#     flds => "pubmed varchar(16), title varchar(1000)"
#
#     $FIG_Config::data/Dlits/hash_role
#     hash_role
#     flds => "md5_hash char(32), role varchar(1000)"
#
#     $FIG_Config::data/Dlits/curr_role
#     curr_role
#     flds => "curator varchar(30), role varchar(1000)"
#
#     $FIG_Config::data/Dlits/genome_hash
#     genome_hash
#     flds => "genome varchar(32), md5_hash char(32)"
#

use strict;
use FIG;
my $fig = new FIG;
use DBrtns;
my $dbf = $fig->db_handle;
use Tracer;

my($org);

Trace("Recreating dlits table.") if T(2);
$dbf->drop_table( tbl => "dlits" );
$dbf->create_table( tbl  => "dlits",
		    flds => "status char(1), md5_hash varchar(32), pubmed varchar(16), curator varchar(30), go_code varchar(15)"
		  );

&FIG::verify_dir("$FIG_Config::data/Dlits");
if (-s "$FIG_Config::data/Dlits/dlits")
{
    $dbf->load_table( tbl => "dlits", 
		      file => "$FIG_Config::data/Dlits/dlits"
		    );
}

Trace("Building indexes.") if T(2);
$dbf->create_index( idx  => "status_ix",
		    tbl  => "dlits",
		    type => "btree",
		    flds => "status" );

$dbf->create_index( idx  => "md5_ix",
		    tbl  => "dlits",
		    type => "btree",
		    flds => "md5_hash" );

$dbf->create_index( idx  => "pubmed_in_dlits_ix",  # Not sure why this was not done before
		    tbl  => "dlits",
		    type => "btree",
		    flds => "pubmed" );

$dbf->create_index( idx  => "curator_ix",
		    tbl  => "dlits",
		    type => "btree",
		    flds => "curator" );

$dbf->vacuum_it("dlits");

$dbf->drop_table( tbl => "pubmed_titles" );
$dbf->create_table( tbl  => "pubmed_titles",
		    flds => "pubmed varchar(16), title varchar(1000)"
		  );
if (-s "$FIG_Config::data/Dlits/titles")
{
    $dbf->load_table( tbl => "pubmed_titles", 
		      file => "$FIG_Config::data/Dlits/titles"
		    );
}

Trace("Building indexes.") if T(2);
$dbf->create_index( idx  => "pubmed_ix",
		    tbl  => "pubmed_titles",
		    type => "btree",
		    flds => "pubmed" );

$dbf->vacuum_it("pubmed_titles");

$dbf->drop_table( tbl => "hash_role" );
$dbf->create_table( tbl  => "hash_role",
		    flds => "md5_hash char(32), role varchar(1000)"
		  );
if (-s "$FIG_Config::data/Dlits/hash_role")
{
    $dbf->load_table( tbl => "hash_role", 
		      file => "$FIG_Config::data/Dlits/hash_role"
		    );
}

Trace("Building indexes.") if T(2);
$dbf->create_index( idx  => "role_ix",
		    tbl  => "hash_role",
		    type => "btree",
		    flds => "role" );

$dbf->create_index( idx  => "hash_ix",
		    tbl  => "hash_role",
		    type => "btree",
		    flds => "md5_hash" );

$dbf->drop_table( tbl => "curr_role" );
$dbf->create_table( tbl  => "curr_role",
		    flds => "curator varchar(30), role varchar(1000)"
		  );
if (-s "$FIG_Config::data/Dlits/curr_role")
{
    $dbf->load_table( tbl => "curr_role", 
		      file => "$FIG_Config::data/Dlits/curr_role"
		    );
}

Trace("Building indexes.") if T(2);
$dbf->create_index( idx  => "role_ix",
		    tbl  => "curr_role",
		    type => "btree",
		    flds => "role" );

$dbf->create_index( idx  => "curr_ix",
		    tbl  => "curr_role",
		    type => "btree",
		    flds => "curator" );

$dbf->vacuum_it("curr_role");

$dbf->drop_table( tbl => "genome_hash" );
$dbf->create_table( tbl  => "genome_hash",
		    flds => "genome varchar(32), md5_hash char(32)"
		  );
if (-s "$FIG_Config::data/Dlits/genome_hash")
{
    $dbf->load_table( tbl => "genome_hash", 
		      file => "$FIG_Config::data/Dlits/genome_hash"
		    );
}

Trace("Building indexes.") if T(2);
$dbf->create_index( idx  => "genome_ix",
		    tbl  => "genome_hash",
		    type => "btree",
		    flds => "genome" );

$dbf->create_index( idx  => "hash_ix",
		    tbl  => "genome_hash",
		    type => "btree",
		    flds => "md5_hash" );

$dbf->vacuum_it("genome_hash");

Trace("Links loaded.") if T(2);

