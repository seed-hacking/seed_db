#
# 
# Create btree index of assigned_functions and annotations for use with FIGV.
#
# This does not currently use the multiple assigned_function files as RAST generates;
# it is currently intended for large metagenome directories.
#

use FIG;
use FIG_Config;
use strict;
use DB_File;
use Data::Dumper;

@ARGV == 1 or die "Usage: $0 orgdir\n";

my $dir = shift;

-d $dir or die "Given directory $dir is not a directory\n";

my $assigns = "$dir/assigned_functions";
my $annos = "$dir/annotations";

open(ASSIGN, "<", $assigns) or die "Cannot open $assigns: $!";
open(ANNO, "<", $annos) or die "Cannot open $annos: $!";

my $assign_btree = "$assigns.btree";
my $anno_btree = "$annos.btree";

my(%anno, %assign, $anno_tie, $assign_tie);

if (-f $anno_btree)
{
    unlink($anno_btree);
}

if (-f $assign_btree)
{
    unlink($assign_btree);
}

my $anno_tie = tie %anno, 'DB_File', $anno_btree, O_RDWR | O_CREAT, 0666, $DB_BTREE;
$anno_tie or die "Cannot tie $anno_btree: $!";

my $assign_tie = tie %assign, 'DB_File', $assign_btree, O_RDWR | O_CREAT, 0666, $DB_BTREE;
$assign_tie or die "Cannot tie $assign_btree: $!";

while (<ASSIGN>)
{
    chomp;
    my($fid, $assign) = split(/\t/);
    $assign{$fid} = $assign;
}
close(ASSIGN);

$/ = "//\n";

while (<ANNO>)
{
    chomp;
    if (/^(fig\S+)/)
    {
	$anno{$1} = $_;
    }
}

untie $anno_tie;
untie $assign_tie;
