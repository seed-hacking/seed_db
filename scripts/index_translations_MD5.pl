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


#  usage: index_translations_MD5 [G1 G2 G3 ...]

#  If there are arguments, then the database is NOT reinitialized, and only the
#  designated new set of organisnms is indexed.

use FIG;
use Tracer;

my $fig = new FIG;

my $dbf = $fig->db_handle;

my $fig_org_dir = "$FIG_Config::organisms";
my $fig_tmp_dir = "$FIG_Config::temp";
my $MD5_file    = "$fig_tmp_dir/translations_MD5.$$";

my $mode = (@ARGV == 0 ? 'all' : 'some');

#
#  Build list of files to be processed
#

my @to_process = ();  #  [genome,file] pairs

if ( @ARGV == 0 ) {
    my $fasta;
    push @to_process, map { $fasta = "$fig_org_dir/$_/Features/peg/fasta";
                            -s $fasta ? [ $_, $fasta ] : ()
                          } $fig->genomes;
} else {
    my $fasta;
    @to_process = map { $fasta = "$fig_org_dir/$_/Features/peg/fasta";
                        -s $fasta ? [ $_, $fasta ] : ()
                      } @ARGV;
}

#
#  The Bulk of the Work:  Compute MD5 on all the protein sequence files
#
#  We must decide if we can do this with a faster, external program, or if
#  we must do it in perl.  If "compute_translation_MD5" does not exist, the
#  open will fail.  If it succeeds, read the version number (-v option) and
#  make sure that it is 1.00 (after stripping the new line).  If this all
#  works, then we will assume that this program can be called and given a
#  list of protein sequence files to index.
#
Trace("Checking method.") if T(2);

my ( $v, $protfilelist );
if (      open  VERSION_PIPE, "compute_translation_MD5 -v |"
     and  $v = <VERSION_PIPE>
     and  close VERSION_PIPE
     and  chomp $v
     and  $v >= 1
   ) {
    #
    #  Write the list of files to be indexed
    #

    $protfilelist = "$fig_tmp_dir/translations_file_list.$$";
    Open( \*FILELIST, ">$protfilelist" );

    my ( $gid_file_pair );
    foreach $gid_file_pair ( @to_process )
    {
        print FILELIST "$gid_file_pair->[0]\t$gid_file_pair->[1]\n";
    }
    close( FILELIST );
}

#
#  It is now time to try to do the indexing.  If that works, then we stick
#  with this route.  Otherwise we can still fall back to doing it in perl.
#
#  Find the protein seeks, saving them in $MD5_file.
#
#    compute_translation_MD5  max_ids  max_id_len  < file_list > id_and_MD5_info
#
Trace("Indexing files.") if T(2);

my $max_id_per_file = 9000000;  # Allocates id memory & hash slots
my $max_id_len      =      64;  # Truncates and continues with log to STDERR

if (   $protfilelist
   and system( "compute_translation_MD5 $max_id_per_file $max_id_len < $protfilelist > $MD5_file" ) == 0
   )
{
    unlink( $protfilelist );
}
else
{
    #
    #  If that failed, do it in perl
    #
    if ( $protfilelist && -e $protfilelist ) { unlink( $protfilelist ) }

    MD5_translation_files( $fig, $MD5_file, @to_process );
}

#
#  Remove old data from database; hmm, this will take some thinking
#

my @gids = ();
if ( $mode eq 'some' )
{
    @gids = map { $_->[0] } @to_process;
}

# $table, $flds, $xflds, $fileName, $genomes

$fig->reload_table( $mode,
                    'protein_sequence_MD5',
                    'id varchar(32), gid varchar(16), md5 char(32)',
                    { trans_md5_id_ix  => 'id',
                      trans_md5_gid_ix => 'gid',
                      trans_md5_ix     => 'md5'
                    },
                    $MD5_file,      # file to load
                    \@gids, 'gid'   # items to delete
                  );
unlink( $MD5_file );

undef $fig;
Trace("Translation MD5 computation complete.") if T(2);

exit;


#=============================================================================
#  This is the perl MD5 calculation version.
#=============================================================================

sub MD5_translation_files {
    my $fig = shift;

    my $MD5_file = shift;
    Open( \*MD5, ">$MD5_file" )
        or print STDERR "Could not open $MD5_file for writing.\n"
        and return 0;

    require Digest::MD5;
    require gjoseqlib;

    my ( $gid_file_pair, $gid, $file, @entry, %MD5_value );
    foreach $gid_file_pair ( @_ )
    {
        ( $gid, $file ) = @$gid_file_pair;
        Trace("Indexing $file.") if T(3);
        my $nfound = 0;
        #  read_next_fasta_seq takes() care of openning, closing, etc.
        while ( ( @entry = gjoseqlib::read_next_fasta_seq( $file ) ) && $entry[0] )
        {
            next if length( $entry[2] ) < 5;
            $MD5_value{ $entry[0] } = Digest::MD5::md5_hex( uc $entry[2] );
            $nfound++;
        }
        if ( $nfound < 1 )
        {
            print STDERR "*** Warning: no valid sequences found in $file\n";
        }
    }

    my $total;
    foreach ( sort keys %MD5_value )
    {
        print MD5 "$_\t$gid\t$MD5_value{$_}\n";
        $total++;
    }
    close MD5;

    return $total;
}
