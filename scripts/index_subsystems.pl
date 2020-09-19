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


# usage: index_subsystems [sub1 sub2 ...]

# if there are arguments, then the database is NOT reinitialized, and only the 
# designated new set of subsystms is indexed.

use Subsystem;
use FIG;
my $fig = new FIG;
use Tracer;

my @to_process = ();
my $dbf = $fig->{_dbf};

if (@ARGV == 0)
{
    Trace("Recreating subsystem index table.") if T(2);
    $dbf->drop_table( tbl => "subsystem_index" );
    $dbf->create_table( tbl  => "subsystem_index",
			flds => <<EOFLD);
    protein varchar(32),
    subsystem varchar(255),
    role varchar(255),
    variant varchar(32)
EOFLD

    $dbf->drop_table( tbl => "subsystem_genome_variant" );
    $dbf->create_table( tbl  => "subsystem_genome_variant",
			flds => <<EOFLD);
    subsystem varchar(255),
    genome varchar(255),
    variant varchar(32)
EOFLD

    $dbf->drop_table( tbl => "subsystem_genome_role" );
    $dbf->create_table( tbl  => "subsystem_genome_role",
			flds => <<EOFLD);
    subsystem varchar(255),
    genome varchar(255),
    role varchar(255)
EOFLD
    $dbf->drop_table( tbl => "subsystem_nonaux_role" );
    $dbf->create_table( tbl  => "subsystem_nonaux_role",
			flds => <<EOFLD);
    subsystem varchar(255),
    role varchar(255)
EOFLD

    $dbf->drop_table( tbl => "aux_roles" );
    $dbf->create_table( tbl => "aux_roles", flds => "subsystem varchar(255),role varchar(255)" );

    $dbf->drop_table(tbl => "subsystem_metadata");
    $dbf->create_table(tbl => "subsystem_metadata",
		      flds => qq(subsystem	varchar(255),
				 classification	text,
				 class_1	varchar(255),
				 class_2	varchar(255),
				 curator	varchar(255),
				 creation_date	integer,
				 last_update	integer,
				 version	integer,
				 exchangable	integer
				 ));
				 
}    
	


#
# Determine which subsystems to load.
#


my @subsystems;
my $skip_delete;

if (@ARGV == 0)
{
    #
    # Use the class method to force a directory scan.
    #
    @subsystems = &FIG::all_subsystems();
    $skip_delete = 1;
}
else
{
    @subsystems = @ARGV;
    $skip_delete = 0;
}
Trace("Iterating through subsystems.") if T(2);
for my $subsystem (@subsystems)
{
    Trace("Processing subsystem $subsystem.") if T(3);
    #
    #  Don't use get_subsystem because that caches them all in memory.
    #
    #    my $sub = $fig->get_subsystem($subsystem);
    my $sub = Subsystem->new($subsystem, $fig);

    if (!$sub)
    {
	Trace("Could not find subsystem for $subsystem") if T(1);
	next;
    }

    $sub->db_sync($skip_delete);
}

if (@ARGV == 0) 
{
    Trace("Indexing subsystem table.") if T(2);
    $dbf->create_index( idx  => "subsystems_protein_ix",
		       tbl  => "subsystem_index",
		       type => "btree",
		       flds => "protein");
    
    $dbf->create_index( idx  => "subsystems_role_ix",
		       tbl  => "subsystem_index",
		       type => "btree",
		       flds => "role");
    
    $dbf->create_index( idx  => "subsystems_by_subsystem_ix",
		       tbl  => "subsystem_index",
		       type => "btree",
		       flds => "subsystem");
    
    $dbf->create_index( idx => "aux_roles_ids",
		       tbl => "aux_roles",
		       type => "btree",
		       flds => "subsystem,role");
    $dbf->create_index( idx => "subsystem_nonaux_role_ix",
		       tbl => "subsystem_nonaux_role",
		       flds => "subsystem");
    $dbf->create_index(idx => "subsystem_metadata_ix",
		       tbl => "subsystem_metadata",
		       flds => "subsystem");
    $dbf->create_index(idx => "subsystem_genome_variant_idx",
		       tbl => "subsystem_genome_variant",
		       flds => "subsystem");
    $dbf->create_index(idx => "subsystem_genome_role_idx",
		       tbl => "subsystem_genome_role",
		       flds => "subsystem");
    
}
    $dbf->vacuum_it("subsystem_index");
    $dbf->vacuum_it("subsystem_metadata");
    $dbf->vacuum_it("aux_roles");
#}

undef $fig;
Trace("Subsystems indexed.");
