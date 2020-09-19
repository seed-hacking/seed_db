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

use FIG;
use Tracer;
use strict;

my $fig = new FIG;

# usage: load_coupling [G1 G2 ...]

my $pchD   = "$FIG_Config::data/CouplingData/PCHs";
my $scores = "$FIG_Config::data/CouplingData/scores";

use DBrtns;

my @genomes;
if (@ARGV > 0)
{
    for my $g (@ARGV)
    {
	if ($g =~ /^\d+\.\d+$/)
	{
	    push(@genomes, $g);
	}
	else
	{
	    die "Invalid genome '$g' in argument list\n";
	}
    }
}

if (!(-d $pchD)) {
    Trace("Coupling directory $pchD not found.") if T(1);
    exit;
} elsif (!(-s $scores)) {
    Trace("Coupling data file $scores not found.") if T(1);
    exit;
}

my $dbf = $fig->db_handle;

Trace("Re-creating coupling table.") if T(2);

my %genomes = map { $_ => 1 } @genomes;

if (@genomes)
{
    my $tmp = "$FIG_Config::temp/lc_tmp.$$";
    open(TMP, ">$tmp") or die "Cannot open $tmp for writing: $!\n";

    #
    # Extract the scores for our genomes to $tmp.
    #

    open(S, "<$scores") or die "Cannot open $scores: $!\n";
    while (<S>)
    {
	if (/^fig\|(\d+\.\d+)\.peg/ and $genomes{$1})
	{
	    print TMP $_;
	}
    }
    close(TMP);
    close(S);

    #
    # Need to drop any entries with our genome.
    #

    my $cond = join(" or ", map { "peg1 like 'fig|$_.peg%'" } @genomes);
    my $where = "($cond)";
    my $res = $dbf->SQL("delete from fc_pegs where $where");

    #
    # Now insert.
    #

    $dbf->load_table(tbl => 'fc_pegs', file => $tmp);
}
else
{
    $dbf->reload_table('all', 'fc_pegs',
		       "peg1 varchar(32), peg2 varchar(32), score integer",
                   { fc_pegs_ix => "peg1, peg2" },
		       $scores
		      );
}

#
# Now load the PCHs files.
#

if (@genomes == 0)
{
    #
    # Reload all PCHs.
    #
    
    Trace("Estimating size of PCH table.") if T(2);
    
    my @files = grep { (-s $_) } map { "$pchD/$_" }  OpenDir($pchD, 1);
    
    my($row_size, $max_rows) = $dbf->estimate_table_size(\@files);
    
    Trace("Re-creating PCH table with row_size=$row_size max_rows=$max_rows.") if T(2);
    
    $dbf->reload_table('all', "pchs",
		       "peg1 varchar(32), peg2 varchar(32), peg3 varchar(32), peg4 varchar(32),
                       inden13 varchar(6), inden24 varchar(6), para3  integer, para4 integer, rep char(1)",
		   { pchs_ix => "peg1, peg2" }, undef, undef, undef, [$row_size, $max_rows]
		      );
    
    Trace("Reading PCH directory.") if T(2);
    
    foreach my $file (@files) {
	Trace("Loading PCH data from $file.") if T(3);
	$dbf->load_table( tbl => "pchs",
			 file => $file );
    }
    Trace("Finishing PCH load.") if T(2);
    $dbf->finish_load('all', 'pchs');
}
else
{
    #
    # Reload a subset.
    #

    for my $g (@genomes)
    {
	my $pch_file = "$pchD/$g";
	if (! -f $pch_file)
	{
	    die "Cannot open PCH file $pch_file\n";
	}

	$dbf->load_table(tbl => 'pchs', file => $pch_file);
    }
}

Trace("Couplings loaded.") if T(2);

    
