use strict;
use Data::Dumper;
use Getopt::Long;
use SeedEnv;
use DB_File;

my $dataD;
my $input;
my $genome_encoding;

my $rc  = GetOptions('d=s' => \$dataD,
                     'i=s' => \$input);

my $usage = "usage: load_db -d Data -i by.kmer.peg\n";

if ((! $rc) || (! $dataD) || (! $input))
{ 
    print STDERR $usage; exit ;
}
unlink("$dataD/kmer_to_pegs.db");
my %kmer_to_pegs;
tie %kmer_to_pegs, "DB_File", "$dataD/kmer_to_pegs.db", O_RDWR|O_CREAT, 0666, $DB_HASH 
	or die "Cannot open file kmer_to_pegs.db: $!\n";

open(IN,"<$input") || die "could not open $input";
my %genomes;
while(defined($_ = <IN>))
{
    if ($_ =~ /^\S+\tfig\|(\d+\.\d+)/)
    {
	$genomes{$1} = 1;
    }
}
close(IN);
my $n = 0;
my %encodeG;
open(GENOMES,">$dataD/genome_encoding") || die "could not open $dataD/genome_encoding";
foreach my $g (sort { $a <=> $b } keys(%genomes))
{
    print GENOMES join("\t",($n,$g)),"\n";
    $encodeG{$g} = $n;
    $n++;
}
close(GENOMES);
print STDERR "# genomes = $n\n";

open(IN,"<$input") || die "could not open $input";
my $last = <IN>;
while ($last && ($last =~ /^(\S+)/))
{
    my $kmer = $1;
    my @pegs = ();
    while ($last && ($last =~ /^(\S+)\tfig\|(\d+\.\d+)\.peg\.(\d+)/) && ($1 == $kmer))
    {
	my $pegN = $3;
	my $g = $encodeG{$2};
	my $encoded_peg = ($g << 15) | $pegN;
	push(@pegs,$encoded_peg);
	$last = <IN>;
    }
    $kmer_to_pegs{$kmer} = join(",",sort { $a <=> $b} @pegs);
}
close(IN);
untie %kmer_to_pegs;
