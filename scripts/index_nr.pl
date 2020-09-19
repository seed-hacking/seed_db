use strict;
use DB_File;

#
# Create a btree indexed version of the given NR.
#

my $usage = "index_nr nr-file  index-nr-file length-nr-index";

@ARGV == 3 or die $usage;

my $nr = shift;
my $inr = shift;
my $lnr = shift;

open(NR, "<$nr") or die "Cannot open NR $nr: $!\n";

my %idx;

my $db = tie %idx, "DB_File", $inr, O_RDWR | O_CREAT, 0666, $DB_BTREE;
$db or die "Cannot create btree $inr: $!\n";

my %lidx;

my $ldb = tie %lidx, "DB_File", $lnr, O_RDWR | O_CREAT, 0666, $DB_BTREE;
$ldb or die "Cannot create btree $lnr: $!\n";


$/ = "\n>";
while (defined($_ = <NR>))
{
    chomp;
    if ($_ =~ /^>?(\S+)[^\n]*\n(.*)/s)
    {
	my $id  =  $1;
	my $seq =  $2;
	$seq =~ s/\s//gs;
	$idx{$id} = $seq;
	$lidx{$id} = length($seq);
    }
    if ($. % 100000 == 0)
    {
	print "$.\n";
    }
}
close(NR);
$db->sync();
untie %idx;
$ldb->sync();
untie %lidx;


