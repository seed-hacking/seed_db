#
# Import a genome from a GTO file
#

use strict;
use P3DataAPI;
use Getopt::Long::Descriptive;
use GenomeTypeObject;

my($opt, $usage) = describe_options("%c %o gto [gto...]",
				    ["help|h" => "Show this help message"]);
print($usage->text), exit 0 if $opt->help;
die($usage->text) if @ARGV < 1;

my @gto_files = @ARGV;

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

my $err = 0;
for my $gto_file (@gto_files)
{
    if (! -f $gto_file)
    {
	warn "$gto_file is unreadable\n";
	$err++;
    }
}
die "Errors reading data\n" if $err;

for my $gto_file (@gto_files)
{
    my $dir = save_gto($gto_file, $data_dir);
    push(@dirs, $dir);
}

$ENV{DBKERNEL_DEFER_VACUUM} = 1;

for my $dir (@dirs)
{
    print "Loading $dir\n";
    my $rc = system("fig", "add_genome", $ENV{USER}, $dir, "-force");
}

sub save_gto
{
    my($gto_file, $data_dir) = @_;
    my $genome;

    my $gto = GenomeTypeObject->new({file => $gto_file});
    my $genome = $gto->{id};

    my $dest = "$data_dir/$genome";
    -d $dest or mkdir $dest or die "Cannot mkdir $dest: $!";
	
    $gto->write_seed_dir($dest, { typemap => $typemap });
    open(P, ">", "$dest/PROJECT") or die "Cannot write $dest/PROJECT: $!";
    print P "Genome imported from GTO file $gto_file\n";
    close(P);
    return $dest;
}

   
