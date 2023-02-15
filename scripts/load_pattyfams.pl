# -*- perl -*-
########################################################################
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
########################################################################

use FIG;
use strict;
use Tracer;
use gjoseqlib;
use File::Temp;
use Proc::ParallelLoop;
use Getopt::Long::Descriptive;

my $fig = new FIG;

#my $tmp = File::Temp->new;
my $tmp = "$FIG_Config::temp/patty.$$";
my @genomes;

my $pf_url = $FIG_Config::pattyfam_compute_url;
my $pf_kmers = $FIG_Config::pattyfam_kmer_dir;

# Compute and load pattyfam data for the given seed genome(s).

my($opt, $usage) = describe_options("%c %o [genome genome ...]",
				    ["no-compute|n", "Don't try to compute fams, just load cached data"],
				    ["parallel|p=i", "Number of process to run in parallel",
				 	{ default => 1 }],
				    ["help|h" => "Show this help message"],
				    );
print($usage->text), exit 0 if $opt->help;

if (($pf_url !~ /^http/ || ! -d $pf_kmers) && !$opt->no_compute)
{
    warn "Skipping pattyfam load due to missing compute url or kmers directory\n";
    goto create_table;
}

# usage: load_pattyfams [G1 G2 ...]

#  Build list of the genomes to be processed ---------------------------------------

my $mode;
($mode, @genomes) = FIG::parse_genome_args(@ARGV);

#  Gather the data on each genome --------------------------------------------

print STDERR "genomes: @genomes\n";

my @work;
foreach my $genome ( @genomes ) {
    my $genome_dir = "$FIG_Config::organisms/$genome";
    
    if ((! (-d $genome_dir)) || (-s "$genome_dir/DELETED")) {
	print STDERR "WARNING: $genome has been deleted\n";
	next;
    }

    my $pf_file = "$genome_dir/pattyfams.txt";

    if (!$opt->no_compute && !-s $pf_file)
    {
	my $gs = $fig->genus_species($genome);
	my($genus) = $gs =~ /^(\S+)/;
	push(@work, [$genome, $genome_dir, $pf_file, $gs, $genus]);
    }
}

print STDERR "Process " . scalar(@work) . " genomes\n";

pareach \@work, sub {
    my($item) = @_;
    my($genome, $genome_dir, $pf_file, $gs, $genus) = @$item;

    my @cmd = ("place_proteins_into_pattyfams",
	       "-o", $pf_file,
	       ($genus ne '' ? ("--genus", $genus) : ()),
	       $pf_kmers, $pf_url, "$genome_dir/Features/peg/fasta");
    print "@cmd\n";
    my $rc = system(@cmd);
    $rc == 0 or die "Failed with rc=$rc: @cmd\n";
}, { Max_Workers => $opt->parallel };

#
# Collect results.
#

open(TMP, ">", $tmp) or die "Cannot write $tmp: $!";
foreach my $genome ( @genomes ) {
    my $genome_dir = "$FIG_Config::organisms/$genome";
    
    if ((! (-d $genome_dir)) || (-s "$genome_dir/DELETED")) {
	print STDERR "WARNING: $genome has been deleted\n";
	next;
    }

    my $pf_file = "$genome_dir/pattyfams.txt";

    my %seen;
    if (open(P, "<", $pf_file))
    {
	while (<P>)
	{
	    my($fid, $fam) = split(/\t/);
	    if ($seen{$fid, $fam}++)
	    {
		warn "Dup: $fid $fam\n";
		next;
	    }
	    # next unless $fig->is_real_feature($fid);
	    next unless $fid =~ /^fig\|/;
	    print TMP $_;
	}
	close(P);
    }
    else
    {
	warn "Cannot open $pf_file: $!\n";
    }

}
close(TMP);

create_table:

#  Load the database ---------------------------------------

    $fig->reload_table($mode, "family_membership",
		       "fid varchar(32) NOT NULL, "
		       . "family VARCHAR(32), "
		       . "score INTEGER, "
		       . "family_function TEXT, "
		       . "PRIMARY KEY ( fid, family )",
		       { fam_ix => "family" },
		       "$tmp", \@genomes);
    

unlink($tmp);
1;
