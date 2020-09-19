# -*- perl -*-
#
# Copyright (c) 2003-2008 University of Chicago and Fellowship
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
#  usage: index_translations               # index genomes and NR proteins
#         index_translations -n            # as above, but include Global/nr
#         index_translations G1 G2 G3 ...  # index specified genomes, external
#                                          #    databases (e.g., KEGG), or nr
#                                          #    (for SEED Global/nr).
#
#  If there are arguments, then the database is NOT reinitialized, and only the
#  designated new set of organisnms is indexed.

use FIG;
use Tracer;

my $fig = new FIG;

my $dbf = $fig->db_handle;

my $fig_nr_dir  = "$FIG_Config::data/NR";
my $fig_nr_file = "$FIG_Config::global/nr";
my $fig_org_dir = "$FIG_Config::organisms";
my $fig_tmp_dir = "$FIG_Config::temp";
my $seeks_file  = "$fig_tmp_dir/translations_seeks.$$";

my $nr_flag = ( @ARGV && $ARGV[0] eq '-n' ) ? shift : '';

my $mode = (@ARGV == 0 ? 'all' : 'some');

#
#  Build list of files to be processed
#

my @to_process = ();

if ( @ARGV == 0 ) {
    Trace("Reading non-redundancy directory.") if T(2);
    opendir( NR, $fig_nr_dir ) || Confess("Could not open directory $fig_nr_dir.");
    my @dirs = map { "$fig_nr_dir/$_" } grep { $_ !~ /^\./ } readdir( NR );
    closedir( NR );

    my $dir;
    foreach $dir ( @dirs ) {
        opendir( SUBDIR, $dir) || Confess("Could not open $dir");
        my @files = grep { $_ !~ /^\./ } readdir( SUBDIR );
        closedir( SUBDIR );
        Trace("Examining $dir.") if T(3);
        if ( @files == 1 )  {
            push( @to_process, "$dir/$files[0]" );
        } elsif ( ( my @tmp = grep { $_ =~ /fasta/ } @files ) == 1 ) {
            push( @to_process, "$dir/$tmp[0]" );
        } else {
            push(@to_process, map { "$dir/$_" } grep { $_ =~ /fasta$/ && $_ ne 'md5.fasta' } @files);
        }
    }

    my $fasta;
    push @to_process, map { $fasta = "$fig_org_dir/$_/Features/peg/fasta";
                            -s $fasta ? $fasta : ()
                          } $fig->genomes;

    # push @to_process, $fig_nr_file if -r $fig_nr_file;
} else {
    #  Expand the idea of special cases from organisms to external files in
    #  the NR directory, and even the SEED nr database, Global/nr:
    my $fasta;
    @to_process = map { -s "$fig_org_dir/$_/Features/peg/fasta" ? "$fig_org_dir/$_/Features/peg/fasta"
                      : -s "$fig_nr_dir/$_/fasta"               ? "$fig_nr_dir/$_/fasta"
                      : ( $_ eq 'nr' ) && -s $fig_nr_file       ? $fig_nr_file
                      :                                           ()
                      } @ARGV;
}

#
#  The Bulk of the Work:  Index all the protein sequence files
#
#  We must decide if we can do this with a faster, external program, or if
#  we must do it in perl.  If "index_translation_files" does not exist, the
#  open will fail.  If it succeeds, read the version number (-v option) and
#  make sure that it is 2.00 (after stripping the new line).  If this all
#  works, then we will assume that this program can be called and given a
#  list of protein sequence files to index.
#
Trace("Checking translation method.") if T(2);

my ( $v, $protfilelist );
if (      open  VERSION_PIPE, "$FIG_Config::bin/index_translation_files -v |"
     and  $v = <VERSION_PIPE>
     and  close VERSION_PIPE
     and  chomp $v
     and  $v >= 2 and $v < 3
   ) {
    #
    #  Write the list of files to be indexed
    #

    $protfilelist = "$fig_tmp_dir/translations_file_list.$$";
    Open(\*FILELIST, ">$protfilelist");

    my ( $file, $fileno );
    foreach $file ( @to_process ) {
        if ( $fileno = $fig->file2N( $file ) ) { print FILELIST "$fileno\t$file\n" }
    }
    close( FILELIST );
}

#
#  It is now time to try to do the indexing.  If that works, then we stick
#  with this route.  Otherwise we can still fall back to doing it in perl.
#
#  Find the protein seeks, saving them in $seeks_file.
#
#    index_translation_files max_ids  max_id_len [cksum_suffix_len (D=64)] < file_list > seek_size_and_cksum_info
#
Trace("Indexing files.") if T(2);

my $max_id_per_file  = 50_000_000;  # Allocates id memory & hash slots
my $max_id_len       =      64;  # Truncates and continues with log to STDERR
my $cksum_suffix_len =      64;  # Locate same protein suffix

if (   $protfilelist
   and system( "$FIG_Config::bin/index_translation_files $max_id_per_file $max_id_len $cksum_suffix_len < $protfilelist > $seeks_file" ) == 0
   )
{
    unlink( $protfilelist );
}
else
{
    #
    #  If that failed, do it with perl subroutine (without checksums)
    #
    if ( $protfilelist && -e $protfilelist ) { unlink( $protfilelist ) }

    index_translation_files( $fig, $seeks_file, @to_process );
}

#
#  Remove old translation seeks from database
#
my @fileNumbers = ();
if ($mode eq 'some')
{
    push @fileNumbers, map { $fig->file2N($_) } @to_process;
}

# $table, $flds, $xflds, $fileName, $genomes

$fig->reload_table( $mode, "protein_sequence_seeks",
                    "id varchar(64), fileno INTEGER, seek INTEGER, len INTEGER, "
                        . "slen INTEGER, cksum INTEGER, sufcksum INTEGER",
	       {     trans_id_ix => "id",
		     trans_cksum_ix => "cksum",
		     trans_fileno_ix => 'fileno',
		     trans_sufcksum_ix => "sufcksum" },
                        $seeks_file, \@fileNumbers, 'fileno');
unlink( $seeks_file );

undef $fig;
Trace("Translation indexing complete.") if T(2);

#  Add MD5 index for each indexed genome

system( "index_translations_MD5" . ( @ARGV ? join( ' ', '', @ARGV ) : '' ) );

exit;


#=============================================================================
#  This is the perl and unix utilities version.  For now, it does not do
#  sequence cksums due to the cost in perl.
#=============================================================================

sub index_translation_files {
    my $fig        = shift;
    my $seeks_file = shift;

    #
    # Test for solaris or linux and tac, since tail -r doesn't work there.
    #

    my $rev_cmd = "tail -r";
    my $osname = `uname -o`;
    chomp $osname;
    if ($FIG_Config::arch =~ /^linux/ or $FIG_Config::arch =~ /^solaris/ or
	$osname =~ /linux/i)
    {
	for my $try (qw(/usr/bin/tac /bin/tac)) {
	    if (-x $try) {
		$rev_cmd = $try;
		last;
	    }
	}
    } elsif ($FIG_Config::arch =~ /^win/) {
	$rev_cmd = "tac - ";
    }

    my ( $file, $fileno, $seek1, $seek2, $id, $last_id, $start_seek, $ln, $slen );
    foreach $file ( @_ ) {
        Trace("Indexing $file.") if T(3);
        #
        #  Reverse each index (tail -r) and use sort -su to keep last version
        #  This requires opening a separate pipe for each input file (so that
        #  sort does not need to handle the concatenation of all the input).
        #
        if ( open( TRANS, "<$file" ) ) {
            open( SEEKS, "| $rev_cmd | sort -su -k 1,1 >> $seeks_file" ) || die "aborted";
            $fileno = $fig->file2N( $file );
            $seek1 = tell TRANS;
            while ( defined( $_ = <TRANS> ) ) {
                $seek2 = tell TRANS;
                if ( $_ =~ /^>(\S+)/ ) {
                    $id = $1;
                    $id =~ s/^([^|]+\|[^|]+)\|.*$/$1/;
                    if ( $last_id ) {
                        $ln = $seek1 - $start_seek;
                        if ( ( $ln > 10 ) && ( $slen > 10 ) ) {
                            print SEEKS "$last_id\t$fileno\t$start_seek\t$ln\t$slen\t0\t0\n";
                        }
                        # else
                        # {
                        #     print STDERR "$last_id not loaded: ln=$ln slen=$slen\n";
                        # }
                    }
                    $last_id = $id;
                    $start_seek = $seek2;
                    $slen = 0;
                } else {
                    $_ =~ s/\s+//g;
                    $slen += length( $_ );
                }
                $seek1 = $seek2;
            }
    
            if ( $last_id ) {
                $ln = $seek1 - $start_seek;
                if ( ( $ln > 10 ) && ( $slen > 10 ) ) {
                    print SEEKS "$last_id\t$fileno\t$start_seek\t$ln\t$slen\t0\t0\n";
                }
                # else
                # {
                #     print STDERR "$last_id not loaded: ln=$ln slen=$slen\n";
                # }
            }
    
            close( SEEKS );
            close( TRANS );
        } else {
            print STDERR "*** could not open $file - ignoring its translations\n";
        }
    }
}


1;
