########################################################################
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
my $fig = new FIG;

my $file = "$FIG_Config::data/ACHresolution/raw.diffs";

my $dbf = $fig->db_handle;

$dbf->drop_table( tbl => "ACHres" );
$dbf->create_table( tbl  => "ACHres",
		    flds => "peg varchar(32),
                             expert varchar(100), 
                             expertF varchar(500), 
                             ourF varchar(500),
                             expert_id varchar(300)"
		  );
$dbf->load_table( tbl => "ACHres",file => $file);
$dbf->create_index( idx  => "ACHres_peg_ix",
		    tbl  => "ACHres",
		    type => "btree",
		    flds => "peg" );
$dbf->create_index( idx  => "ACHres_expert_ix",
		    tbl  => "ACHres",
		    type => "btree",
		    flds => "expert_id" );
$dbf->create_index( idx  => "ACHres_expertF_ix",
		    tbl  => "ACHres",
		    type => "btree",
		    flds => "expertF" );
$dbf->create_index( idx  => "ACHres_expertF_ix",
		    tbl  => "ACHres",
		    type => "btree",
		    flds => "ourF" );

$dbf->drop_table( tbl => "ACHres_diffs" );

$dbf->create_table( tbl  => "ACHres_diffs",
		    flds => "expertF varchar(500), 
                             ourF varchar(500),
                             status char(1)"
		  );

if (-s "$FIG_Config::data/ACHresolution/diffs")
{
    $dbf->load_table( tbl => "ACHres_diffs",file => "$FIG_Config::data/ACHresolution/diffs") ;
}

$dbf->create_index( idx  => "ACHres_diffs_ex_ix",
		    tbl  => "ACHres_diffs",
		    type => "btree",
		    flds => "expertF" );
$dbf->create_index( idx  => "ACHres_diffs_our_ix",
		    tbl  => "ACHres_diffs",
		    type => "btree",
		    flds => "ourF" );

$dbf->drop_table( tbl => "ACHres_comments" );
$dbf->create_table( tbl  => "ACHres_comments",
		    flds => "peg varchar(32),
                             func varchar(500), 
                             who varchar(100),
                             comment varchar(5000)"
		  );

if (open(COMMENTS,"<$FIG_Config::data/ACHresolution/comments"))
{
    $/ = "//\n";
    while (defined($_ = <COMMENTS>))
    {
	chomp;
	if ($_ =~ /^(\S+)\t([^\t]+)\t([^\n]+)\n(.*)/s)
	{
	    my($peg,$func,$who,$comment) = ($1,$2,$3,$4);
	    my $commentQ = quotemeta $comment;
	    my $funcQ    = quotemeta $func;
	    $dbf->SQL("INSERT INTO ACHres_comments (peg,func,who,comment) VALUES (\'$peg\',\'$funcQ\',\'$who\',\'$commentQ\')");
	}
    }
    $/ = "\n";
    close(COMMENT);
}

$dbf->create_index( idx  => "ACHres_comment_peg_ix",
		    tbl  => "ACHres_comments",
		    type => "btree",
		    flds => "peg" );
$dbf->create_index( idx  => "ACHres_comment_func_ix",
		    tbl  => "ACHres_comments",
		    type => "btree",
		    flds => "func" );
$dbf->create_index( idx  => "ACHres_comment_who_ix",
		    tbl  => "ACHres_comments",
		    type => "btree",
		    flds => "who" );

