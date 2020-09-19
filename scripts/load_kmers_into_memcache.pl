use strict;
use Data::Dumper;
use IO::Compress::Gzip;

use Cache::Memcached::Fast;

our @doctypes = qw(peg
		   rna
		   atn
		   att
		   bs
		   opr
		   pbs
		   pi
		   pp
		   prm
		   pseudo
		   rsw
		   sRNA
		   trm
		   box
		   );

$| = 1;

our %tmap;
for my $i (0..$#doctypes)
{
    $tmap{$doctypes[$i]} = $i;
    $tmap{$i} = $doctypes[$i];
}

my $cache = new Cache::Memcached::Fast({
    servers => [ { address => 'elm.mcs.anl.gov:11211' } ],
    compress_threshold => 10_000,
    compress_ratio => 0.9,
    compress_methods => [ \&IO::Compress::Gzip::gzip,
			 \&IO::Uncompress::Gunzip::gunzip ],
    max_failures => 3,
    failure_timeout => 2,
});


my $kmer_data = "/vol/ross/GeneralKmerCompareRegions/by.kmer.peg";
open(IN, "<", $kmer_data) or die "Cannot open kmer data $kmer_data: $!";

my @out;
my $batch_size = 100_000;

my $last = <IN>;
while ($last && ($last =~ /^(\S+)/))
{
    my $kmer = $1;
    my @pegs = ();
    while ($last && ($last =~ /^(\S+)\t(\S+)/) && ($1 == $kmer))
    {
	my $peg = $2;
	my $encoded_peg = fid_to_docid($peg);
	push(@pegs,$encoded_peg);
	$last = <IN>;
    }
    push(@out, [$kmer, join(",",sort { $a <=> $b} @pegs)]);
    if (@out > $batch_size)
    {
	my $out = $cache->set_multi(@out);
	print ".";
	@out = ();
    }
}
if (@out)
{
    $cache->set_multi(@out);
}

sub fid_to_docid
{
    my($fid) = @_;
    
    if ($fid =~ /^fig\|(\d+)\.(\d+)\.([^.]+)\.(\d+)$/)
    {
	my ($g, $ext, $type, $num) = ($1, $2, $3, $4);
	my $tnum = $tmap{$type};

	#
	# right to left: (cumulative)
	# 17 bits for feature number    (0)
	# 4 bits for type		(17)
	# 15 bits for ext		(21)
	# Rest for genome 		(36)

	my $enc;

	$enc = $g << 36| $ext << 21 | $tnum << 17 | $num;
	
	return $enc;
    }

    return undef;
}

sub docid_to_fid
{
    my($doc) = @_;

    my($g, $e, $t, $n);

    $g = $doc >> 36;
    $e = ($doc >> 21) & 0x7fff;
    $t = ($doc >> 17) & 0xf;
    $n = $doc & 0x1ffff;
    
    my $type = $tmap{$t};
    my $genome = "$g.$e";
    my $fid = "fig|$genome.$type.$n";

    return $fid;
}

