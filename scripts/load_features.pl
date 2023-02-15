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

use Tracer;
if ($ENV{'VERBOSE'}) { TSetup("3 FIG DBKernel","TEXT") }

Trace("Preparing to load features.") if T(2);
my ($mode, @genomes) = FIG::parse_genome_args(@ARGV);
my $temp_dir = "$FIG_Config::temp";
my $organisms_dir = "$FIG_Config::organisms";

my($genome,@types,$type,$id,$loc,@aliases,$aliases,$contig);

# usage: load_features [G1 G2 G3 ... ]

Open(\*REL, ">$temp_dir/tmpfeat$$");
Open(\*ALIAS, "| sort -T $temp_dir -u > $temp_dir/tmpalias$$");
Open(\*DELFIDS,"| sort -u > $temp_dir/tmpdel$$");
Open(\*REPFIDS,"| sort -u > $temp_dir/tmprel$$");

if ($mode eq 'all') {

    # Process any remaining deleted.features or replaced.features in Global
    if (open(GLOBDEL,"<$FIG_Config::global/deleted.features"))
    {
	while (defined($_ = <GLOBDEL>) && ($_ =~ /^fig\|(\d+\.\d+)/))
	{
	    print DELFIDS "$1\t$_";
	}
    }
    close(GLOBDEL);

    if (open(GLOBREP,"<$FIG_Config::global/replaced.features"))
    {
	while (defined($_ = <GLOBREP>) && ($_ =~ /^fig\|(\d+\.\d+)/))
	{
	    print REPFIDS "$1\t$_";
	}
    }
    close(GLOBREP);



    # Here we extract external aliases from the peg.synonyms table, when they can be inferred
    # accurately.
	Trace("Extracting external aliases from the peg.synonyms table.") if T(2);
    Open(\*SYN, "<$FIG_Config::global/peg.synonyms");
    while (defined($_ = <SYN>))
    {
		chop;
		my($x,$y) = split(/\t/,$_);
		my @ids = map { $_ =~ /^([^,]+),(\d+)/; [$1,$2] } ($x,split(/;/,$y));
		my @fig = ();
		my(@nonfig) = ();
		foreach $_ (@ids)
		{
			if ($_->[0] =~ /^fig\|/)
			{
				push(@fig,$_);
			}
			else
			{
				push(@nonfig,$_);
			}
		}
	
		foreach $x (@fig)
		{
			my($peg,$peg_ln) = @$x;
			my $genome = &FIG::genome_of($peg);
			foreach $_ (@nonfig)
			{
				if ((@fig == 1) || ($peg_ln == $_->[1]))
				{
					print ALIAS "$peg\t$_->[0]\t$genome\n";
					Trace("Alias record $peg, $_->[0] for $genome.") if T(4);
				}
			}
		}
    }
    close(SYN);
}

foreach $genome (@genomes)
{
	Trace("Processing $genome.") if T(3);
    opendir(FEAT,"$organisms_dir/$genome/Features") 
		|| die "could not open $genome/Features";
    @types = grep { $_ =~ /^[a-zA-Z]+$/ } readdir(FEAT);
    closedir(FEAT);

    foreach $type (@types)
    {
	if ((-s "$organisms_dir/$genome/Features/$type/deleted.features") &&
	    open(TMP,"<$organisms_dir/$genome/Features/$type/deleted.features"))
	{
	    while (defined($_ = <TMP>) && ($_ =~ /^fig\|(\d+\.\d+)/))
	    {
		print DELFIDS "$1\t$_";
	    }
	    close(TMP);
	}

	if ((-s "$organisms_dir/$genome/Features/$type/replaced.features") &&
	    open(TMP,"<$organisms_dir/$genome/Features/$type/replaced.features"))
	{
	    while (defined($_ = <TMP>) && ($_ =~ /^fig\|(\d+\.\d+)/))
	    {
		print REPFIDS "$1\t$_";
	    }
	    close(TMP);
	}

	if ((-s "$organisms_dir/$genome/Features/$type/tbl") &&
	    open(TBL,"<$organisms_dir/$genome/Features/$type/tbl"))
	{
	    Trace("Loading $genome/Features/$type/tbl") if T(4);
	    my @tbl = <TBL>;
	    close(TBL);
	    my %seen;

	    while ($_ = pop @tbl)
	    {
		chop;
		($id,$loc,@aliases) = split(/\t/,$_);
		
		if ($id && (! $seen{$id}))
		{
		    $seen{$id} = 1;
		    my($minloc,$maxloc);
		    if ($loc)
		    {
			$loc =~ s/\s+$//;
			($contig,$minloc,$maxloc) = $fig->boundaries_of($loc);
			if ($minloc && $maxloc)
			{
			    ($minloc < $maxloc) || (($minloc,$maxloc) = ($maxloc,$minloc));
			}
		    }
		
		    if (! $contig)
		    { 
			$loc = $contig = $minloc = $maxloc = ""; 
		    }
		
		    if (@aliases > 0)
		    {
			$aliases = join(",",grep(/\S/,@aliases));
			my $alias;
			foreach $alias (@aliases)
			{
			    if ($alias =~ /^([NXYZA]P_|gi\||sp\|\tr\||kegg\||uni\|)/)
			    {
				
				print ALIAS "$id\t$alias\t$genome\tOVERRIDE\n";
				Trace("$id override alias $alias for $genome") if T(4);
			    }
			}
		    }
		    else
		    {
			$aliases = "";
		    }
		    $minloc = (! $minloc) ? 0 : $minloc;
		    $maxloc = (! $maxloc) ? 0 : $maxloc;
		    if ((length($loc) < 5000) && (length($contig) < 96) && (length($id) < 32) && ($id =~ /(\d+)$/))
		    {
			print REL "$id\t$1\t$type\t$genome\t$loc\t$contig\t$minloc\t$maxloc\t$aliases\n";
		    }
		}
	    }
	}
    }
}
close(REPFIDS);
close(DELFIDS);
close(REL);
close(ALIAS);
Open(\*ALIASIN, "<$temp_dir/tmpalias$$");
Open(\*ALIASOUT, ">$temp_dir/tmpalias$$.1");
Trace("Parsing alias file.") if T(2);
$_ = <ALIASIN>;
while ($_ && ($_ =~ /^(\S+)/))
{
    my @aliases = ();
    my $curr = $1;
    while ($_ && ($_ =~ /^(\S+)\t(\S+)(\t(\S+))?/) && ($1 eq $curr))
    {
		push(@aliases,[$2,$3 ? 1 : 0]);
		$_ = <ALIASIN>;
    }
    my $x;
    my $genome = &FIG::genome_of($curr);
    foreach $x (@aliases)
    {
	if ($x->[1])
	{
	    print ALIASOUT "$curr\t$x->[0]\t$genome\n";
	}
	else
	{
	    my $i;
	    for ($i=0; ($i < @aliases) && ((! $aliases[$i]->[1]) || (! &same_class($x->[0],$aliases[$i]->[0]))); $i++) {}
	    if ($i == @aliases)
	    {
		print ALIASOUT "$curr\t$x->[0]\t$genome\n";
	    }
	}
    }
}
close(ALIASIN);
close(ALIASOUT);
unlink("$temp_dir/tmpalias$$");

$fig->reload_table($mode, 'deleted_fids',"genome varchar(16), fid varchar(32)", 
		                         { deleted_fids_fid_ix => 'fid', deleted_fids_genome_ix => 'genome' },
		                         "$temp_dir/tmpdel$$",\@genomes);

unlink("$temp_dir/tmpdel$$");

$fig->reload_table($mode, 'replaced_fids',"genome varchar(16), from_fid varchar(32), to_fid varchar(32)", 
		                         { replaced_fids_from_ix => 'from_fid', 
                                           replaced_fids_to_ix => 'to_fid', 
                                           replaced_fids_genome_ix => 'genome' 
                                         },
		                         "$temp_dir/tmprel$$",\@genomes);

unlink("$temp_dir/tmprel$$");

$fig->reload_table($mode, 'features',
				   "id varchar(32), idN INTEGER, type varchar(16),genome varchar(16),"  .
			            "location TEXT,"  .
			            "contig varchar(96), minloc INTEGER, maxloc INTEGER,"  .
			            "aliases TEXT",
					{ features_id_ix => "id", features_org_ix => "genome",
					  features_type_ix => "type", features_beg_ix => "genome, contig, minloc" },
					"$temp_dir/tmpfeat$$", \@genomes);
unlink("$temp_dir/tmpfeat$$");

$fig->reload_table($mode, 'ext_alias',
					"id varchar(32), alias varchar(64), genome varchar(16)",
					{ ext_alias_alias_ix => "alias", ext_alias_genome_ix => "genome",
					  ext_alias_ix_id => "id" },
					"$temp_dir/tmpalias$$.1", \@genomes );

unlink("$temp_dir/tmpalias$$.1");
Trace("Features loaded.") if T(2);

sub same_class {
    my($x,$y) = @_;

    my $class1 = &classA($x);
    my $class2 = &classA($y);
    return ($class1 && ($class1 eq $class2));
}

sub classA {
    my($alias) = @_;

    if ($alias =~ /^([^\|]+)\|/)
    {
		return $1;
    }
    elsif ($alias =~ /^[NXYZA]P_[0-9\.]+$/)
    {
		return "refseq";
    }
    else
    {
		return "";
    }
}
