#
# Index peg.syns.
#
# This version presorts before inserting into the DB_File; MUCH faster.
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

my $tmp1 = "$FIG_Config::temp/tmp1.$$";
my $tmp2 = "$FIG_Config::temp/tmp2.$$";

open(S1, "| sort -T  $FIG_Config::temp -S 1G > $tmp1") or die "error opening sort pipe 1: $!";
open(S2, "| sort -T  $FIG_Config::temp -S 1G > $tmp2") or die "error opening sort pipe 2: $!";

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
#	    $indext{$to} = "$to_len:$from";
	    print S1 "$to\t$to_len:$from\n";
	    for my $ent (@from)
	    {
		my($fid, $flen) = @$ent;
		#$indexf{$fid} = "$flen:$to";
		print S2 "$fid\t$flen:$to\n";
	    }
#	    map { $index{$_->[0]} = $to } grep { $_->[0] =~ /^fig/ } @from;
	}
    }
}
close(SYNS);

close(S1) or die "Error on close of sort pipe 1: \$!=$! \$?=$?\n";

open(F1, "<$tmp1") or die "cannot open $tmp1: $!";
while (<F1>)
{
    chomp;
    my($x1, $x2) = split(/\t/, $_, 2);
    $indext{$x1} = $x2;
}
close(F1);

close(S2);
open(F2, "<$tmp2") or die "cannot open $tmp2: $!";
while (<F2>)
{
    chomp;
    my($x1, $x2) = split(/\t/, $_, 2);
    $indexf{$x1} = $x2;
}
close(F2);

$indexf_tied->sync();
$indext_tied->sync();
untie %indexf;
untie %indext;
