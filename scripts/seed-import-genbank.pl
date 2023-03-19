#
# Import a genome from a genbank file. We can either
# import one at a time with an override of the genome ID,
# or we can import from a tab delimited file with
# genbank-filename genome-name genome-id
#

use strict;
use GenomeTypeObject;
use gjogenbank;
use GenBankToGTO;
use Getopt::Long::Descriptive;
use Data::Dumper;
use IPC::Run;
use FIG;

my($opt, $usage) = describe_options("%c %o",
				    ["One of --genbank-file or --file-table must be selected"],
				    ["file-table=s" => "Load genbank files from this table. Tab-delimited, values are filename, genome name, and genome ID."],
				    ["genbank-file=s" => "Load this genbank file. Must specify --genome-id"],
				    ["genome-id=s" => "Use this genome ID for the load"],
				    ["genome-name=s" => "Override genome name from the genbank file with this value"],
				    ["private-genome-range-start=i" => "Start of private genome suffix range",
				     { default => 10000}],
				    ["taxdump-dir=s" => "Use this taxdump data for looking up taxonomy"],
				    ["data-dir=s" => "Use the given datadir instead of a temp dir"],
				    ["help|h" => 'Show this help message']);
print($usage->text), exit 0 if $opt->help;
die($usage->text) if @ARGV != 0;

my $fig = new FIG;

#
# Load current genomes and initialize suffix tables.
#

my %existing_suffix;
my %existing_genome;
for my $g ($fig->genomes)
{
    if (my($gid, $suffix) = $g =~ /^(\d+)\.(\d+)$/)
    {
	$existing_suffix{$gid} //= $suffix;
	$existing_genome{$g} = 1;
    }
    else
    {
	die "Invalid genome returned from FIG::Genomes";
    }
}

$ENV{TAXONKIT_DB} = $opt->taxdump_dir;

my $typemap = {
    rRNA => 'rna',
    tRNA => 'rna',
    misc_RNA => 'rna',
    CDS => 'peg',
    peg => 'peg',
    source => '',
};

my $data_dir = $opt->data_dir // File::Temp->newdir();

my @to_load;

if ($opt->file_table)
{
    die "Only one of --file-table and --genbank-file may be specified\n" if ($opt->genbank_file);

    open(F, "<", $opt->file_table) or die "Cannot open " . $opt->file_table . ": $!";
    while (<F>)
    {
	chomp;
	my($fn, $gname, $gid) = split(/\t/);
	-f $fn or die "File $fn from " . $opt->file_table . " does not exist";
	-s $fn or die "File $fn from " . $opt->file_table . " is empty";
	if ($gid)
	{
	    $gid =~ /^\d+\.\d+/ or die "Genome ID $gid is not of the form number.number\n";
	}
	push(@to_load, [$fn, $gname, $gid]);
    }
}
elsif ($opt->genbank_file)
{
    my $fn = $opt->genbank_file;
    -f $fn or die "File $fn does not exist";
    -s $fn or die "File $fn is empty";
    my $gid = $opt->genome_id;
    if ($gid)
    {
	$gid =~ /^\d+\.\d+/ or die "Genome ID $gid is not of the form number.number\n";
    }
    push(@to_load, [$fn, $opt->genome_name, $gid]);
}
else
{
    die "One of --file-tale and --genbank-file must be specified\n";
}

for my $load (@to_load)
{
    my($fn, $gname, $gid) = @$load;

    open(F, "<", $fn) or die "Cannot open $fn: $!";

    my @entries = gjogenbank::parse_genbank(\*F);
    close(F);

    my %orgs;
    $orgs{$_}++ foreach map { $_->{ORGANISM} } @entries;
    if (!$gname)
    {
	if (%orgs > 1)
	{
	    warn "More than one org name; voting\n";
	    my @names = sort { $orgs{$b}  <=> $orgs{$a} } keys %orgs;
	    $gname = $names[0];
	}
	else
	{
	    ($gname) = keys %orgs;
	}
    }

    if ($gid)
    {
	if ($existing_genome{$gid})
	{
	    warn "$gid is already loaded; skipping\n";
	    next;
	}
	
    }
    else
    {
	my $tax = name_to_taxon($gname) // 2;
	my $cur = $existing_suffix{$tax};
	if (!$cur || $cur < $opt->private_genome_range_start)
	{
	    $cur = $opt->private_genome_range_start;
	}
	$cur++;
	$existing_suffix{$tax} = $cur;
	$gid = "$tax.$cur";
    }
    my($taxon_id) = $gid =~ /^(\d+)/;

    my $lin = taxon_to_lineage($taxon_id);
    print "Assigned $gid for $gname\n";

    my $gto = GenBankToGTO::new({ entry => \@entries,
				  id => $gid,
				});

    $gto->{taxonomy} = $lin if $lin;
	
    if ($gname)
    {
	$gto->{scientific_name} = $gname;
    }

    #
    # Walk the features; prokka annotations may have aliases in the products
    #
    for my $f ($gto->features)
    {
	if ($f->{function} =~ /^((\S+\|)+)(.*)$/)
	{
	    my @aliases = grep { $_ } split(/\|/, $1);
	    push(@{$f->{aliases}}, @aliases);
	    $gto->update_function('import', $f, $3);
	}
    }

    my $dest = "$data_dir/$gid";
    -d $dest or mkdir $dest or die "Cannot mkdir $dest: $!";
	
    $gto->write_seed_dir($dest, { typemap => $typemap });
    open(P, ">", "$dest/PROJECT") or die "Cannot write $dest/PROJECT: $!";
    print P "Genome imported from $fn\n";
    close(P);

    print "Loading $dest\n";
    my $rc = system("fig", "add_genome", $ENV{USER}, $dest, "-force");
}

# taxonkit access routines

sub taxon_to_lineage
{
    my($taxon) = @_;

    my $inp = "$taxon\n";
    my $res;
    
    my $ok = IPC::Run::run(['taxonkit', 'lineage'],
			   "<", \$inp,
			   ">", \$res);
    $ok or die "Error running taxonkit lineage\n";
    open(my $s, "<", \$res);
    while (<$s>)
    {
	chomp;
	if (/^(\d+)\t(.*)$/ && $1 == $taxon)
	{
	    my @parts = split(/;/, $2);
	    shift @parts if $parts[0] eq 'cellular organisms';
	    return wantarray ? @parts : \@parts;
	}
    }
    return undef;
   
}

sub name_to_taxon
{
    my($gname) = @_;

    my $inp;
    
    my @name_parts = split(/\s+/, $gname);
    while (@name_parts)
    {
	$inp .= "@name_parts\n";
	pop @name_parts;
    }
    my $res;
    my $ok = IPC::Run::run(["taxonkit", "name2taxid"], 
			   "<", \$inp,
			   ">", \$res);
    $ok or die "Failure looking up names from $inp";

    open(my $s, "<", \$res);
    while (<$s>)
    {
	chomp;
	my($name, $taxon) = split(/\t/);
	return $taxon if $taxon =~ /^\d+$/;
    }
    return undef;
}
