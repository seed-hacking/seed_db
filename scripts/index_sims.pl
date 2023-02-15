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


#
#  Usage: index_sims [--table tablename] [--dir sims-dir] [ File1 File2 ... ]
#
#  If available, it uses the program index_sims_file
#

use strict;
use FIG;
use DBrtns;
use Tracer;
use Getopt::Long;
use File::Path qw(make_path);

my $usage =  "Usage: $0 [--dbname database-name] [--table tablename] [--dir sims-dir] [ File1 File2 ... ]";

my $sims_db;
my $sims_dir;
my $new_sims_dir;
my $seeks_table  = "sim_seeks";
my $help = 0;

my( $sim_file, @sim_files );

my $rc = GetOptions("dir=s" => \$sims_dir,
		    "table=s" => \$seeks_table,
		    "dbname=s" => \$sims_db,
		    "help" => \$help);

$rc or die "$usage\n";

if ($help)
{
    print "$usage\n";
    exit 0;
}

if ($sims_db)
{
    $FIG_Config::db = $sims_db;
}

my $fig = new FIG;
my $dbf = $fig->db_handle;

make_path("/dev/shm/fig");
my $seeks_file   = "/dev/shm/fig/sims_seeks_tmp.$$";
#my $seeks_file   = "$FIG_Config::temp/sims_seeks_tmp.$$";


#
# Traditional usage.
#
if ($sims_dir eq '')
{
    $sims_dir     = "$FIG_Config::data/Sims";
    $new_sims_dir = "$FIG_Config::data/NewSims";
}

print "Indexing sims_dir=$sims_dir new=$new_sims_dir seeks=$seeks_table\n";
print "Files: @ARGV\n";

#
#  Build the list of files to be indexed:
#

if ( @ARGV == 0 ) {
    Trace("Reading sim directory.") if T(2);
    opendir( SIMSDIR, $sims_dir ) || Confess("Could not open sims directory $sims_dir");
    @sim_files = map { "$sims_dir/$_" } grep { $_ !~ /^\./ } readdir( SIMSDIR );
    closedir( SIMSDIR );

    if ( $new_sims_dir and -d $new_sims_dir ) {
	opendir( SIMSDIR, $new_sims_dir ) || Confess("Could not open new sims $new_sims_dir");
	push @sim_files, map { "$new_sims_dir/$_" } grep { $_ !~ /^\./ } readdir( SIMSDIR );
	closedir( SIMSDIR );
    }

    #
    # We always do this so a SEED with no sims files will
    # initialize properly.
    #
    $dbf->drop_table(   tbl  => $seeks_table );
    $dbf->create_table( tbl  => $seeks_table,
		       flds => "id varchar(64), "
		       . "fileN INTEGER, "
		       . "seek INTEGER, "
		       . "len INTEGER"
		      );
} else {
    @sim_files = @ARGV;
}

my ( $v, $contigfilelist );

#
#  See if we can find the C program to do the indexing
#

my $use_prog = 0;
if (      open VERSION_PIPE, "index_sims_file -v |"
     and  $v = <VERSION_PIPE>
     and  close VERSION_PIPE
     and  chomp $v
     and  $v eq "1.00"
   ) {
    $use_prog = 1;
}

my $nfiles = @sim_files;
my $n = 0;

#
#  For each file, find the seeks and load them into the database:
#
foreach $sim_file ( @sim_files ) {
    $n++;
    Trace("   Indexing sims file $sim_file ($n of $nfiles)") if T(2);
    my $fileN;
    if ( $fileN = $fig->file2N( $sim_file ) ) {
		#
		# Check if sims file is zero length, and skip it if so.
		#
		
		if ((-s $sim_file) == 0) {
			#
			# Empty the file.
			#
			open(SEEK_FH, ">$seeks_file");
			close(SEEK_FH);
		} else {
			( $use_prog &&
			 ( system( "index_sims_file  $fileN < $sim_file > $seeks_file" ) == 0 )
			)
			|| index_sims_file( $sim_file, $fileN, $seeks_file )
			|| Confess("ERROR: index_sims failed on sim file $sim_file");
		}
		
		if ( @ARGV > 0 ) {
			$dbf->SQL("DELETE FROM $seeks_table WHERE ( fileN = $fileN )");
		}
		$dbf->load_table( tbl => $seeks_table, file => $seeks_file );
    }
}

unlink( $seeks_file );

#
#  Index the database file:
#

if ( @ARGV == 0 ) {
	Trace("Indexing $seeks_table table.");
    $dbf->create_index( tbl  => $seeks_table,
			idx  => "${seeks_table}_id_ix",
			type => "btree",
			flds => "id"
			);
    $dbf->vacuum_it( $seeks_table );
}
Trace("Sim index processing complete.") if T(2);

#
#  The perl version in case the C version fails:
#

sub index_sims_file {
    my( $file, $fileN, $seeks_file ) = @_;
    my( $line, $offset, $curr, $nxt_offset, $ln );

    open( SIMS,  "<$file" ) || return 0;
    open( SEEKS, ">$seeks_file") || ( close( SIMS ) && return 0 );

    $offset = tell SIMS;
    $line = <SIMS>;
    while ( defined( $line ) && ( $line =~ /^(\S+)/ ) ) {
		$curr = $1;
		while ( $line && ( $line =~ /^(\S+)/ ) && ( $1 eq $curr ) ) {
			$nxt_offset = tell SIMS;
			$line = <SIMS>;
		}
		$ln = $nxt_offset - $offset;
		print SEEKS "$curr\t$fileN\t$offset\t$ln\n";
		$offset = $nxt_offset;
    }

    close( SEEKS );
    close( SIMS );

    return 1;
}

1;
