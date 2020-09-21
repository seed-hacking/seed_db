#
# Import a genome from PATRIC.
#

use strict;
use P3DataAPI;

my @genomes = @ARGV;

my $api = P3DataAPI->new();

my $typemap = {
    rRNA => 'rna',
    tRNA => 'rna',
    misc_RNA => 'rna',
    CDS => 'peg',
    peg => 'peg',
    source => '',
};

my $data_dir = File::Temp->newdir();
my @dirs;

for my $genome (@genomes)
{
    if ($genome !~ /^\d+\.\d+$/)
    {
	warn "Skipping invalid genome id $genome\n";
	next;
    }
    print "Pulling GTO of $genome from PATRIC\n";
    my $dir = load_gto($genome, $data_dir);
    push(@dirs, $dir);
}

$ENV{DBKERNEL_DEFER_VACUUM} = 1;

for my $dir (@dirs)
{
    print "Loading $dir\n";
    my $rc = system("fig", "add_genome", $ENV{USER}, $dir, "-force");
}

sub load_gto
{
    my($genome, $data_dir) = @_;

    my $gto = $api->gto_of($genome);

    if (!$gto)
    {
	print STDERR "Error retrieving GTO for $genome\n";
	return;
    }

    my $dest = "$data_dir/$genome";
    -d $dest or mkdir $dest or die "Cannot mkdir $dest: $!";
	
    $gto->write_seed_dir($dest, { typemap => $typemap });
    open(P, ">", "$dest/PROJECT") or die "Cannot write $dest/PROJECT: $!";
    print P "Genome imported from PATRIC\n";
    close(P);
    return $dest;
}

   
