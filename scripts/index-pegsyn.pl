#
# Index peg.syns.
#

use DB_File;
use Data::Dumper;

use strict;
use FIG;
use FIG_Config;
use File::Basename;
use Carp 'croak';

@ARGV == 2 or die "Usage: $0 peg.synonyms peg.synonyms.index\n";

my $pegsyn = shift;
my $pegsyn_index = shift;


my %indexf;
my $indexf_tied = tie %indexf, 'DB_File', "$pegsyn_index.f", O_RDWR | O_CREAT, 0666, $DB_BTREE;

$indexf_tied or die("Creation of hash $pegsyn_index.f failed: $!\n");

my %indext;
my $indext_tied = tie %indext, 'DB_File', "$pegsyn_index.t", O_RDWR | O_CREAT, 0666, $DB_BTREE;

$indext_tied or die("Creation of hash $pegsyn_index.t failed: $!\n");

open(SYNS, $pegsyn) or die $!;
my($to, $to_len, $from);
my %peg_mapping;
while (defined($_ = <SYNS>))
{
    if (($to, $to_len, $from) =  /^([^,]+),(\d+)\t(\S+)/)
    {
	my @from = map { [ split(/,/, $_) ] } split(/;/,$from);
	if (@from > 0)
	{
	    $indext{$to} = "$to_len:$from";
	    for my $ent (@from)
	    {
		my($fid, $flen) = @$ent;
		$indexf{$fid} = "$flen:$to";
	    }
#	    map { $index{$_->[0]} = $to } grep { $_->[0] =~ /^fig/ } @from;
	}
    }
}

$indexf_tied->sync();
$indext_tied->sync();
untie %indexf;
untie %indext;
close(SYNS);
