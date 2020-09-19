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
use Tracer;
my $fig = new FIG;

# usage: load_bbhs [-table tablename] [files]

Trace("Verifying files.") if T(2);

my @files;

my $table = "bbh";

while ((@ARGV > 0) && ($ARGV[0] =~ /^-/))
{
    my $arg = shift @ARGV;
    if ($arg =~ /^-table/) 
    { 
	$table = shift @ARGV;
    }
    else
    {
	die "Invalid argument $arg\n";
    }
}

if (@ARGV)
{
    @files = @ARGV;
}
else
{
    my $dir = "$FIG_Config::global/BBHs";
    @files = map { "$dir/$_" }  grep { $_ =~ /^\d+\.\d+$/ } OpenDir($dir);
}

Trace("Recreating table.") if T(2);
my $dbf = $fig->db_handle;
$dbf->reload_table('all', $table,
                   "peg1 varchar(32), peg2 varchar(32), psc varchar(16), nsc float",  
                   { bbh_peg_ix => "peg1" }
);
Trace("Loading files.") if T(2);
my $file;
foreach $file (@files) {
    Trace("Loading BBHs from $file.") if T(3);
    $dbf->load_table( tbl => $table,
                      file => $file );
}
Trace("Finishing load.") if T(2);
$dbf->finish_load('all', $table);
Trace("BBHs loaded.") if T(2);
