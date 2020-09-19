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


# usage: load_function_transitions   file of transitions made by
# get_all_annotations.pl  | sort | trail.pl >  trail_file

use strict;
use FIG;
use Tracer;
my $fig = new FIG;
my $dbf = $fig->db_handle;

my $file = shift(@ARGV);
$dbf->drop_table( tbl => "function_trail" );
$dbf->create_table( tbl  => "function_trail",
    flds => qq(prot varchar(64),
	       mod_time timestamp,
	       was_made_by varchar(32),
	       was_assigned_function text,
	       made_by varchar(32),
	       assigned_function text,
	       subsystem text
	       )
    );

$dbf->load_table( tbl => "function_trail",
	      file => "$file" );

$dbf->create_index( idx  => "function_trail_prot_ix",
            tbl  => "function_trail",
            type => "btree",
            flds => "prot" );

$dbf->create_index( idx  => "function_trail_date_ix",
            tbl  => "function_trail",
            type => "btree",
            flds => "mod_time" );

