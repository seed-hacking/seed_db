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


use FIG;
use strict;
use Cwd 'abs_path';

my $fig = new FIG;

my $usage = "usage: load_close [-clear] CloseRel";

my $drop_tables = 0;

if ($ARGV[0] eq '-clear')
{
    $drop_tables = 1;
    shift @ARGV;
}

(@ARGV == 1) || die $usage;

my $close_file = shift;

$close_file = abs_path($close_file);

-f $close_file or die "Close relation file $close_file does not exist\n";

use DBrtns;


my $dbf = $fig->db_handle();

my $mediumint;
if ($dbf->{_dbms} eq 'mysql')
{
    $mediumint = "mediumint";
}
else
{
    $mediumint = "integer";
}

if ($drop_tables)
{
    $dbf->drop_table( tbl => "close_pegs" );
    $dbf->create_table( tbl => 'close_pegs',
		       flds => "g1 smallint, p1 $mediumint, g2 smallint, p2 $mediumint"
		       #		    flds => "peg1 varchar(32), peg2 varchar(32)"
		      );
}

#
# Need to check to see if this is a pre-mapped closetab or not.
#

open(C, "<$close_file") or die "Cannot open $close_file: $!\n";
$_ = <C>;

my $load_file;

if (/^fig/)
{
    #
    # Need to map before loading.
    #

    $load_file = "$FIG_Config::temp/load_tmp.$$";

    open(L, ">$load_file") or die "Cannot open $load_file for writing: $!\n";

    while (defined($_))
    {
	chomp;
	my($p1, $p2) = split(/\t/);

	print L join("\t", $fig->map_peg_to_ids($p1), $fig->map_peg_to_ids($p2)), "\n";
	$_ = <C>;
    }
    close(C);
    close(L);
}
else
{
    $load_file = $close_file;
}
    
$dbf->load_table( tbl => "close_pegs",
                  file => $load_file );
if ($drop_tables)
{
    print "Creating index\n";

    $dbf->create_index( idx  => "close_pegs_ix",
		       tbl  => "close_pegs",
		       type => "btree",
		       flds => "g1, p1" );
}

$dbf->vacuum_it("close_pegs");

