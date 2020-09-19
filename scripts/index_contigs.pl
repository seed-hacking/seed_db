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
use Carp;
use Tracer;

my $have_md5;
eval {
    require Digest::MD5;
    $have_md5 = 1;
};
if ($@)
{
    warn "WARNING: Digest::MD5 not found\n";
}

#
#  index_contigs
#
#      usage: index_contigs [ G1 G2 G3 ... ]
#
#  Find the nucleotide seeks for the contigs in each genome directory.
#  This version of the code also writes two other files at the top level
#  of each genome directory.
#
#  COUNTS contains a single line with:
#
#      genome_id \t n_contigs \t total_nucleotides \t cksum \n
#
#  The value of cksum is the xor of the Unix cksum value for each of the
#  contigs in the genome directory.  It is based on exactly the same set
#  of charcters included in the total_nucleotides value.  This file can
#  be used by compute_genome_counts.
#
#  VERSION contains a single line with:
#
#      genome_id "." cksum \n
#
#  This is meant to be functionally equivalent to the file by the same
#  name that was previously produced by compute_genome_counts, but it
#  is only sensitive to the sequence data per se, not the file format
#  or sequence order.  ( Note:  Currently the interpretation of residues
#  is case sensitive. )
#

my $fig = new FIG;

my( $genome, $file, $id, %seen );

my $orgroot  =  $FIG_Config::organisms;
my $temp_dir =  $FIG_Config::temp;
my $seekfile = "$temp_dir/tmp1.$$";
my $lenfile  = "$temp_dir/tmp2.$$";
my $md5file  = "$temp_dir/tmp3.$$";

my $index_interval = 10000;

my $dbf = $fig->{_dbf};

#
#  Build a list of the genomes to be indexed.  Defer deleting database
#  entries until we have built the files to load into them.  Among other
#  things, this means that an interupt early in the indexing will be harmless.
#

my ($mode, @genomes) = FIG::parse_genome_args(@ARGV);

#
#  Build the files for loading the database:
#
#  We must decide if we can do this with a faster, external program, or if
#  we must use the perl.  If "index_contig_files" does not exist, the open
#  will fail.  If it succeeds, read the version number (-v option) and
#  make sure that it is 1.00 (after stripping the new line).  If this all
#  works, then we will assume that this program can be called with a list
#  of genomes and files to index, and that it will return records that we
#  understand.
#
#  Version 1.01 requires receiving the md5 checksum from the C program.
#

my ( $v, $contigfilelist );

Trace("Building seek file.") if T(2);

if (      open INDEX_FILES_PIPE, "index_contig_files -v |"
     and  $v = <INDEX_FILES_PIPE>
     and  close INDEX_FILES_PIPE
     and  chomp $v
     and  $v eq "1.01"
   ) {

    #
    #  Write the list of genomes to a file, which will be used by
    #  index_contig_files to figure out what to do:
    #

    my ( $genomedir, $contigfile );

    $contigfilelist = "$temp_dir/contig_file_list.$$";
    open( FILELIST, ">$contigfilelist" ) || die "could not open $contigfilelist";

    foreach $genome ( @genomes ) {
		$genomedir = "$orgroot/$genome";
		Trace("Indexing contigs for $genomedir.") if T(3);
		if ( opendir( GENOMEDIR, "$genomedir" ) )
		{
			foreach $file ( grep { $_ =~ /^contigs\d*$/ } readdir(GENOMEDIR) )
			{
			$contigfile = "$genomedir/$file";
			if ( -s $contigfile )
			{
				my $fileno = $fig->file2N( $contigfile );
				print FILELIST "$genome\t$fileno\t$contigfile\n";
			}
			}
			closedir( GENOMEDIR );
		}
    }

    close( FILELIST );
}

#
#  Okay, here we go with harvesting the contig information.
#

open( SEEKS,   ">$seekfile" ) || die "Could not open $seekfile";
open( LENGTHS, ">$lenfile"  ) || die "Could not open $lenfile";
open( MD5S, ">$md5file"  ) || die "Could not open $md5file";
print STDERR "Writing to $seekfile, $lenfile, and $md5file\n";

my $inputpipe;

#
#  Okay, can we do it with index_contig_files?  (This should never actually
#  fail, but we can still fall back to perl on a failure to open the pipe.)
#

if (     $contigfilelist
     and $inputpipe = "index_contig_files $index_interval < $contigfilelist |"
     and open( INPIPE, $inputpipe )
   ) {
	Trace("Harvesting with index_contig_files.") if T(2);
	print STDERR "Harvesting with index_contig_files.\n";
    my ( $ncontig, $ttlnuc, $cksum, $md5, @contig_md5 );
    my @parts;

    $ncontig = $ttlnuc = $cksum = 0;
    $genome = "";

    while ( defined( $_ = <INPIPE> ) )
    {
	@parts = split /\t/;

	#  Is this the start of a new organism?
	#  If so, report the previous and reintialize.

	if ( $parts[0] ne $genome )
	{
	    if ( ( $ncontig > 0 ) && ( $ttlnuc > 0 ) && $genome )
	    {
		report_counts( $genome, "$orgroot/$genome", $ncontig, $ttlnuc, $cksum, \@contig_md5);
	    }
	    $genome = $parts[0];
	    %seen = ();
	    $ncontig = $ttlnuc = $cksum = 0;
	    @contig_md5 = ();
	}

	#  Process the new data:

	$id = $parts[1];
	if ( $seen{ $id } )
	{
	    if ( @parts == 5 ) {
		print STDERR "WARNING: In $genome, duplicate contig id $id skipped\n"
	    }
	}
	elsif ( @parts == 6 )
	{
	    print SEEKS $_;
	}
	elsif ( @parts == 5 )
	{
	    $_ =~ s/\t[^\t]+\t[^\n\t]+$//;
	    print LENGTHS $_;
	    $ncontig++;
	    $ttlnuc += $parts[2];
	    $cksum  ^= $parts[3];
	    $md5 = $parts[4];
	    chomp $md5;
	    push(@contig_md5, [$id, $parts[2], $md5]);
	    print MD5S "$genome\t$id\t$md5\n";
	    $seen{ $id } = 1;
	}
    }

    #  Report counts on last organism:

    if ( ( $ncontig > 0 ) && ( $ttlnuc > 0 ) && $genome )
    {
	report_counts( $genome, "$orgroot/$genome", $ncontig, $ttlnuc, $cksum, \@contig_md5 );
    }

    close( INPIPE );
    unlink( $contigfilelist );
}

#
#  We could not make index_contig_files work, so let's do it all in perl:
#

else {
	Trace("Harvesting without index_contig_files.") if T(2);
	print STDERR "Harvesting WITHOUT index_contig_files.\n";
    my( $start_lineN, $ln, $seek, $indexpt, $seq_ok );
    my( $ncontig, $ttlnuc, $cksum );

# RAE: We already opened these
#    open( SEEKS,   ">$seekfile" ) || die "Could not open $seekfile";
#    open( LENGTHS, ">$lenfile"  ) || die "Could not open $lenfile";

    foreach $genome ( @genomes )
    {
	my $genomedir = "$orgroot/$genome";
	if ( opendir(GENOMEDIR,"$genomedir") )
	{
	    #
	    #  Process one genome
	    #
		Trace("Processing $genomedir.") if T(3);
	    undef %seen;
	    my @genomefiles = grep { $_ =~ /^contigs\d*$/ } readdir(GENOMEDIR);
	    closedir( GENOMEDIR );

	    $ncontig = $ttlnuc = $cksum = 0;
	    foreach $file ( @genomefiles )
	    {
		#
		#  Process one contigs file
		#
		if ( ( -s "$genomedir/$file" ) && open( FASTA, "<$genomedir/$file" ) )
		{
		    my $fileno = $fig->file2N( "$genomedir/$file" );
		    $_ = <FASTA>;
		    while ( defined( $_ ) && ( $_ =~ /^>(\S+)/ ) )
		    {
			#
			#  Process one contig
			#
			$id = $1;
			$seq_ok = 1;
			$indexpt = 0;
			$start_lineN = 0;
			$seek = tell FASTA;

			while ( defined( $_ = <FASTA> ) && ( $_ !~ /^>/ ) )
			{
			    #  This removes white space, but non-nucleotide characters.

			    $_ =~ s/\s+//g;

			    #  Add a report of illegal characters

			    if ( /([^A-DGHKMNR-WYa-dghkmnr-wy])/ && $seq_ok ) {
				print STDERR "Illegal charcter ($1) in contig $id of genome $genome\n";
				$seq_ok = 0;
			    }

			    $ln = length( $_ );
			    while ( $indexpt < ( $start_lineN + $ln ) )
			    {
				if ( ! $seen{ $id } )
				{
				    print SEEKS join("\t", $genome, $id, $start_lineN, $indexpt, $fileno, $seek), "\n";
				}
				$indexpt += $index_interval;
			    }
			    $start_lineN = $start_lineN + $ln;
			    $seek = tell FASTA;
			}

			#
			#  Report on this contig
			#

			if ( ! $seen{ $id } )
			{
			    print LENGTHS "$genome\t$id\t$start_lineN\n";
			    $ttlnuc += $start_lineN;
			    $ncontig++;
			    $seen{ $id } = 1;
			}
			else
			{
			    print STDERR "WARNING: In $genome, duplicate contig id $id skipped\n"
			}
		    }
		    close( FASTA );
		}
	    }

	    #
	    #  Report on this genome
	    #

	    if ( ( $ncontig > 0 ) && ( $ttlnuc > 0 ) && $genomedir )
	    {
		$cksum = find_cksum( $genomedir, @genomefiles );
		report_counts( $genome, $genomedir, $ncontig, $ttlnuc, $cksum );
	    }
	}
    }
}

close( SEEKS );
close( LENGTHS );
close( MD5S );

#
#  Load the database contig_seeks table: -------------------------------------
#

if ( @ARGV == 0 )
{
    $dbf->drop_table(   tbl  => "contig_seeks" );
    $dbf->create_table( tbl  => "contig_seeks",
			flds => "genome varchar(16), "
			      . "contig varchar(96), "
			      . "startN BIGINT, "
                              . "indexpt BIGINT, "
                              . "fileno INTEGER, "
                              . "seek BIGINT"
			);
}
else
{
    foreach $genome ( @genomes )
    {
	$dbf->SQL("DELETE FROM contig_seeks WHERE ( genome = \'$genome\' )");
    }
}

$dbf->load_table( tbl  => "contig_seeks", file => "$seekfile" );
unlink("$seekfile");

if ( @ARGV == 0 )
{
    $dbf->create_index( idx  => "contig_seeks_ix",
			tbl  => "contig_seeks",
			type => "btree",
			flds => "genome,contig,indexpt" );

    $dbf->vacuum_it( "contig_seeks" );
}

#
#  Load the database contig_lengths table: -----------------------------------
#

if (@ARGV == 0)
{
    $dbf->drop_table(   tbl  => "contig_lengths" );
    $dbf->create_table( tbl  => "contig_lengths",
			flds => "genome varchar(16), "
			      . "contig varchar(96), "
			      . "len INTEGER"
			);
}
else
{
    foreach $genome ( @genomes )
    {
	$dbf->SQL("DELETE FROM contig_lengths WHERE ( genome = \'$genome\' )");
    }
}

$dbf->load_table( tbl  => "contig_lengths", file => "$lenfile" );
unlink( "$lenfile" );

if ( @ARGV == 0 )
{
    $dbf->create_index( idx  => "contig_lengths_ix",
			tbl  => "contig_lengths",
			type => "btree",
			flds => "genome,contig" );

    $dbf->vacuum_it( "contig_lengths" );
}


#
# Load the database contig_md5sums table
#

if (@ARGV == 0)
{
    $dbf->drop_table(   tbl  => "contig_md5sums" );
    $dbf->create_table( tbl  => "contig_md5sums",
			flds => "genome varchar(16), "
		              . "contig varchar(96), "
			      . "md5 varchar(32) "
			);
}
else
{
    foreach $genome ( @genomes )
    {
	eval {$dbf->SQL("DELETE FROM contig_md5sums WHERE ( genome = \'$genome\' )")};
	if ($@) {
	 print STDERR "Trying to delete from contig_md5sums failed. You can ignore this if it is a new genome\n";
	}
    }
}

$dbf->load_table( tbl  => "contig_md5sums", file => "$md5file" );
unlink( "$md5file" );

if ( @ARGV == 0 )
{
    $dbf->create_index( idx  => "contig_md5sums_ix",
			tbl  => "contig_md5sums",
			type => "btree",
			flds => "genome,md5" );

    $dbf->vacuum_it( "contig_md5sums" );
}

Trace("Contig indexing complete.") if T(2);


#  Only subroutines below:----------------------------------------------------

sub find_cksum {
    my $genomedir = shift;
    my $cksum;
    if ( @_ ) {
		my $genomelist = join " ", @_;
#		
#		$cksum = `cd \"$genomedir\"; cat $genomelist | cksum`;
#		
		# BDP: Windows doesn't recognize the semi-colon as a
		# command separator, so we do this in two steps.
		#
		chdir $genomedir;
		$cksum = `cat $genomelist | cksum`;
		$cksum =~ s/\s.*$/\tfile-based/;
    } else {
		$cksum = 0;
    }

    $cksum;
}

sub report_counts {
    my ( $genome, $genomedir, $ncontig, $ttlnuc, $cksum, $contig_md5 ) = @_;

    my $countfile = "$genomedir/COUNTS";
    if ( open( COUNTS, ">$countfile" ) )
    {
	print COUNTS join("\t", $genome, $ncontig, $ttlnuc, $cksum), "\n";
	close( COUNTS );
	# print STDERR join("\t", $genome, $ncontig, $ttlnuc, $cksum), "\n";
    }
    else
    {
	print STDERR "WARNING: Could not open genome count file $countfile\n";
    }

    my $versionfile = "$genomedir/VERSION";
    if ( open( VERSION, ">$versionfile" ) )
    {
	print VERSION "$genome.$cksum\n";
	close( VERSION );
    }
    else
    {
	print STDERR "WARNING: Could not open genome verions file $versionfile\n";
    }

    #
    # Write the signature file  and compute its checksum.
    #

    if (ref($contig_md5) eq "ARRAY")
    {
	my $dig;
	if ($have_md5)
	{
	    $dig = new Digest::MD5;
	}
	
	my $sigfile = "$genomedir/SIGNATURE";
	if (open(SIG, ">$sigfile"))
	{
	    for my $ent (sort { $a->[0] cmp $b->[0] } @$contig_md5)
	    {
		my($id, $len, $md5) = @$ent;
		my $txt = "$id\t$len\t$md5\n";
		$dig->add($txt) if $dig;
		print SIG $txt;
	    }

	    if ($dig)
	    {
		my $hex = $dig->hexdigest;
		
		my $md5file = "$genomedir/MD5SUM";
		if (open(MD5, ">$md5file"))
		{
		    print MD5 "$hex\n";
		    close(MD5);
		}
		else
		{
		    warn "WARNING: could not open MD5 file $md5file: $!\n";
		}
	    }
	}
	else
	{
	    warn "WARNING: could not open genome signature file $sigfile: $!\n";
	}
	    
    }

}


1;
