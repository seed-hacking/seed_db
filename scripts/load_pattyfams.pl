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

my $pf_url = $FIG_Config::pattyfam_compute_url;
my $pf_kmers = $FIG_Config::pattyfam_kmer_dir;

$pf_url =~ /^http/ or die "Invalid pattyfam compute url '$pf_url'\n";
-d $pf_kmers or die "Invalid pattyfam kmer dir $pf_kmers\n";

# Compute and load pattyfam data for the given seed genome(s).

my($opt, $usage) = describe_options("%c %o [genome genome ...]",
				    ["parallel|p=i", "Number of process to run in parallel",
				 	{ default => 1 }],
				    ["help|h" => "Show this help message"],
				    );
print($usage->text), exit 0 if $opt->help;

# usage: load_pattyfams [G1 G2 ...]

#  Build list of the genomes to be processed ---------------------------------------

my ($mode, @genomes) = FIG::parse_genome_args(@ARGV);

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

    if (!-s $pf_file)
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

my $tmp = File::Temp->new;

foreach my $genome ( @genomes ) {
    my $genome_dir = "$FIG_Config::organisms/$genome";
    
    if ((! (-d $genome_dir)) || (-s "$genome_dir/DELETED")) {
	print STDERR "WARNING: $genome has been deleted\n";
	next;
    }

    my $pf_file = "$genome_dir/pattyfams.txt";

    open(P, "<", $pf_file) or die "Cannot open $pf_file: $!";
    while (<P>)
    {
	my($fid) = /^(\S+)/;
	# next unless $fig->is_real_feature($fid);
	print $tmp $_;
    }
    close(P);
}
close($tmp);

#  Load the database ---------------------------------------
if (-s "$tmp") {
    $fig->reload_table($mode, "family_membership",
		       "fid varchar(32) NOT NULL, "
		       . "family VARCHAR(32), "
		       . "score INTEGER, "
		       . "function TEXT, "
		       . "PRIMARY KEY ( fid, family )",
		       { fam_ix => "family" },
		       "$tmp", \@genomes);
    
}
else {
    print STDERR "WARNING: No genome data to update\n";
}

1;
