#
# Normalize the given feature directory per blastall rules and index with formatdb.
#
# Create btree index of the tbl data as well.
#

use FIG;
use FIG_Config;
use strict;
use DB_File;
use Data::Dumper;

@ARGV == 1 or die "Usage: $0 feature-directory\n";

my $dir = shift;

-d $dir or die "Given directory $dir is not a directory\n";

my $fasta = "$dir/fasta";
my $tbl = "$dir/tbl";

open(IN, "<", $fasta) or die "Cannot open $fasta: $!";
open(TBL, "<", $tbl) or die "Cannot open $tbl: $!";

#
# Normalize & create blast db.
#

my $norm = "$fasta.norm";
open(OUT, ">", $norm) or die "Cannot open $norm for writing: $!";

while (<IN>)
{
    s/^>fig\|/>gnl|fig|/;
    print OUT;
}
close(IN);
close(OUT);

my @cmd = ("$FIG_Config::ext_bin/formatdb", "-o", "T", "-i", $norm);
my $rc = system(@cmd);
if ($rc != 0)
{
    die "Error $rc running formatdb: @cmd\n";
}

#
# Create btree index of tbl file.
#
# $idx{$fid} = join($;, contig, loc, index, aliases)
# $idx{$contig} = join($;, index-start, index-stop)
#
# The second entry records the beginning and ending indices
# of the given contig in the recno list of pegs in contig order.
#
# We also create a recno keyed on index as above, in order to
# accelerate genes_in_region.
#
# $list[order] = join($;, $fid, $contig, $beg, $end, $strand)
#

my $btree = "$tbl.btree";
my $recno = "$tbl.recno";
my %idx;
my @list;

if (-f $btree)
{
    unlink($btree);
}

if (-f $recno)
{
    unlink($recno);
}

my $t = tie %idx, 'DB_File', $btree, O_RDWR | O_CREAT, 0666, $DB_BTREE;
$t or die "Cannot tie $btree: $!";

my $r = tie @list, 'DB_File', $recno, O_RDWR | O_CREAT, 0666, $DB_RECNO;
$r or die "Cannot tie $recno: $!";

my @tmp;
while (<TBL>)
{
    chomp;
    my($id, $loc, @aliases) = split(/\t/);
    
    my($contig, $beg, $end, $strand) = &FIG::boundaries_of($loc);
    push(@tmp, [$id, $contig, $beg, $end, $strand, $loc, \@aliases]);
}

my $idx = 0;
my $last_contig;
my $last_contig_start;
for my $ent (sort { $a->[1] cmp $b->[1] or $a->[2] <=> $b->[2] } @tmp)
{
    my($id, $contig, $beg, $end, $strand, $loc, $alist) = @$ent;

    if ($contig ne $last_contig)
    {
	if (defined($last_contig))
	{
	    $idx{$last_contig} = join($;, $last_contig_start, $idx - 1);
	}
	$last_contig = $contig;
	$last_contig_start = $idx;
    }
    $list[$idx] = join($;, $id, $contig, $beg, $end, $strand);
    $idx{$id} = join($;, $loc, $idx, @$alist);
    $idx++;
}
if (defined($last_contig))
{
    $idx{$last_contig} = join($;, $last_contig_start, $idx - 1);
}

untie $r;
untie $t;
