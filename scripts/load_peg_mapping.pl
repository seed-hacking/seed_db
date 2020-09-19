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
use DBrtns;
use Tracer;

my $fig = new FIG;

my $temp_dir = "$FIG_Config::temp";
my($organisms_dir) = "$FIG_Config::organisms";

my( $peg, $syns, $peg_id, $peg_ln, $syn_id, $syn_ln, $syn, $line );

my $usage = "load_peg_mapping [-table tablename] [-file pegsyn-file]";



my $table = "peg_synonyms";
my $file = "$FIG_Config::global/peg.synonyms";

while ((@ARGV > 0) && ($ARGV[0] =~ /^-/))
{
    my $arg = shift @ARGV;
    if ($arg =~ /^-table/i) 
    { 
	$table = shift(@ARGV);
    }
    elsif ($arg =~ /^-file/i) 
    { 
	$file = shift(@ARGV);
    }
    else
    { 
	die $usage;
    }
}


Trace("Parsing peg synonyms.") if T(2);
Open(\*REL, "| sort $FIG_Config::sort_options -T $temp_dir >$temp_dir/tmpfeat$$");
Open(\*SYN, "<$file");
while (defined($line = <SYN>))
{
    chomp $line;
    ($peg,$syns) = split(/\t/,$line);
    ($peg_id,$peg_ln) = split(/,/,$peg);

    #  Removed this test from inner loop for twice the speed -- GJO
    if ( (! $peg_id) || ($peg_ln !~ /^[123456789]\d*/) )
    {
        Trace("Invalid peg in peg.synonyms: $line") if T(0);
        next;
    }

    foreach $syn ( split( /;/, $syns ) )
    {
        #  Delay split on comma; avoid building intermediate arrays -- GJO
        ( $syn_id, $syn_ln ) = split( /,/, $syn );
        if ( ( ! $syn_id) || ( $syn_ln !~ /^[123456789]\d*/ ) )
        {
            Trace("Invalid synonym in peg.synonyms: $peg => $syn") if T(0);
        }
        else
        {
            print REL join( "\t", $peg_id, $peg_ln, $syn_id, $syn_ln ) . "\n";
        }
    }
}
close(REL);

$fig->reload_table('all', $table,
					"maps_to varchar(64), maps_to_ln INTEGER, syn_id varchar(64), syn_ln INTEGER",
					{ peg_ids_ix => "syn_id", peg_maps_to_ix => "maps_to" },
					"$temp_dir/tmpfeat$$" );
unlink("$temp_dir/tmpfeat$$");
Trace("Peg mappings loaded.") if T(2);
