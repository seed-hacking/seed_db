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


# usage: index_annotations

use FIG;
use Tracer;

my $fig = new FIG;

my @genomes;
my $reload;
if (@ARGV == 0)
{
    $reload++;
    @genomes = $fig->genomes;
}
else
{
    @genomes = @ARGV;
}

my($offset1,$offset2,$peg,$ln);
Trace("Indexing annotations.") if T(2);
my $relTable = "$FIG_Config::temp/tmp$$.seeks";
Open(\*RELTABLE, ">$relTable");

foreach $genome (@genomes) {
    Trace("Indexing genome $genome.") if T(3);
    my $fileno = $fig->file2N("$FIG_Config::organisms/$genome/annotations");

    if ((-s "$FIG_Config::organisms/$genome/annotations") && 
        open(FILE,"<$FIG_Config::organisms/$genome/annotations")) {
        $/ = "\n//\n";
        $offset1 = tell FILE;
        while (defined($line = <FILE>))
        {
            if ($line =~ /^(fig\|\d+\.\d+\.[a-zA-Z]{2,10}\.\d+)\n(\d+)\n(\S+)\n(.*)/s)
            {
                $peg = $1;
                $date = $2;
                $who  = $3;
                $body = $4;
                $ma   = ($body =~ /^Set master function to/);
                # Modified for Windows compatibility
                $ln = length($line) - 3;
                print RELTABLE "$peg\t$date\t$who\t$ma\t$fileno\t$offset1\t$ln\n";
            }
            $offset1 = tell FILE;
        }
        close(FILE);
        $/ = "\n";
    }
    elsif (-s "$FIG_Config::organisms/$genome/annotations")
    {
        Trace("WARNING: could not open $FIG_Config::organisms/$genome/annotations") if T(1);
    }

}
close(RELTABLE);

if ($reload)
{
    $fig->reload_table('all', "annotation_seeks",
		       "fid varchar(32) NOT NULL, dateof INTEGER, who varchar(64), "
		       . "ma char, fileno INTEGER, seek INTEGER, len INTEGER",
		   { annotations_fig_ix => "fid", annotations_who_ix => "who",
			 annotations_dateof_ix => "dateof" },
		       $relTable);
}
else
{
    my $db = $fig->db_handle();
    my $cond = join(" OR ", map { "fid LIKE 'fig|$_.%'" } @genomes);
    $db->SQL(qq(DELETE FROM annotation_seeks
		WHERE $cond));
    $db->load_table(file => $relTable,
		    tbl => 'annotation_seeks');
}
    
unlink($relTable);

undef $fig;
Trace("Annotations indexed.") if T(2);
