#
# Propagate annotations from other genomes in the SEED to the target genome.
#

use strict;
use Data::Dumper;
use FIG;
use Getopt::Long::Descriptive;

my($opt, $usage) = describe_options("%c %o genome [genome..]",
				    ["help|h" => "Show this help message."]);
print($usage->text), exit 0 if $opt->help;
die($usage->text) if @ARGV == 0;

my @genomes = @ARGV;

my $fig = FIG->new();

my $dbh = $fig->db_handle()->dbh();

#
# Create temp table for reference genomes.
#
$dbh->do(qq(CREATE TEMPORARY TABLE reference_genome ( genome_id varchar(32) )));

#
# Find the PATRIC reference genomes
#
my $sth = $dbh->prepare(qq(INSERT INTO reference_genome VALUES (?)));
for my $g ($fig->genomes)
{
    my $dir = $fig->organism_directory($g);
    if (open(P, "<", "$dir/PROJECT"))
    {
	$_ = <P>;
	if (/imported from PATRIC/)
	{
	    $sth->execute($g);
	}
	close(P);
    }
}

my $cond = join(", ", map { "?" } @genomes);

my $res = $dbh->selectall_arrayref(qq(SELECT this_seq.gid, this.prot, this.assigned_function, that.assigned_function, count(that.prot)
				   FROM protein_sequence_MD5 this_seq 
				   JOIN protein_sequence_MD5 that_seq ON this_seq.md5 = that_seq.md5 
				   JOIN assigned_functions this ON this.prot = this_seq.id 
				   JOIN assigned_functions that ON that.prot = that_seq.id
				   JOIN reference_genome r ON r.genome_id = that_seq.gid
				   WHERE
				   this_seq.gid IN ($cond) AND
				   this_seq.gid != that_seq.gid AND
				   this.assigned_function != that.assigned_function
				   GROUP BY this_seq.gid, this.prot, this.assigned_function, that.assigned_function
				   ORDER BY this_seq.gid, this.prot, count(that.prot)
), undef, @genomes);

my %identical_assignments;

for my $ent (@$res)
{
    my($gid, $this, $this_func, $that_func, $count) = @$ent;
    push(@{$identical_assignments{$gid}->{$this}}, [$this_func, $that_func, $count]);
}

for my $gid (@genomes)
{
    my $iden = $identical_assignments{$gid};
    for my $fid ($fig->all_features($gid, 'peg'))
    {
	my $match = $iden->{$fid};
	if (!$match)
	{
	    print "$fid\n";
	}
    }
}
