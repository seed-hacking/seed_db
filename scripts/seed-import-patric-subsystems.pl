#
# Import subsystems from BV-BRC
#

use Subsystem;
use P3DataAPI;
use strict;
use URI::Escape;
use JSON::XS;
use File::Slurp;
use Date::Parse;
use Data::Dumper;
use FIG;

my $api = P3DataAPI->new;
my $fig = FIG->new;

#
# Build genome list for our query.
#

my @genomes;
for my $g ($fig->genomes)
{
    my $dir = $fig->organism_directory($g);
    if (open(P, "<", "$dir/PROJECT"))
    {
	$_ = <P>;
	if (/imported from PATRIC/)
	{
	    push(@genomes, $g);
	}
	close(P);
    }
}

my $genome_cond = "(" . join(",", @genomes) . ")";

my @ss_data = $api->query("subsystem_ref");

#write_file("ref.json", JSON::XS->new->canonical->pretty->encode(\@ss_data));
#exit;

#die Dumper(@ss_data);
for my $dat (@ss_data)
{
    print "Load $dat->{subsystem_name}\n";
    my $ss = $fig->get_subsystem($dat->{subsystem_name});
    if (!$ss)
    {
	$ss = Subsystem->new($dat->{subsystem_name}, $fig, 1);
    }
    $ss->{description} = $dat->{description};;
    $ss->{notes} = join("\n", @{$dat->{notes}});
    $ss->{classification} = [$dat->{superclass}, $dat->{class}];
    $ss->{last_updated} = $ss->{created} = int(str2time($dat->{date_inserted}));
    $ss->{curator} = "BV-BRC";
    $ss->{version} = 1;
    $ss->{exchangable} = 0;

    for my $i (0..$#{$dat->{role_name}})
    {
	my $row = $ss->get_role_index($dat->{role_name}->[$i]);
	if (defined($row))
	{
	    if ($row ne $i)
	    {
		warn "Role already exists but index wrong for $dat->{role_name}->[$i]\n";
	    }
	    next;
	}
	my $id = $dat->{role_id}->[$i];
	my $name = $dat->{role_name}->[$i];
	# BV-BRC subsystem data does not have abbreviations
	my $abbr = "R" . ($i + 1); 
	$ss->add_role($name, $abbr);
    }

    my @cdat = $api->query("subsystem",
			   ["eq", "subsystem_id", uri_escape($dat->{subsystem_id})],
			   ["in", "genome_id", $genome_cond]);
    printf "%d cells\n", scalar @cdat;
    for my $cent (@cdat)
    {
	my $row = $ss->get_genome_index($cent->{genome_id});
	if (!defined($row))
	{
	    $row = $ss->add_genome($cent->{genome_id});
	    $ss->{variant_code}->[$row] = $cent->{active};
	}
	my $col = $ss->{role_index}->{$cent->{role_name}};
	my $cell = $ss->get_cell($row, $col);
	push(@$cell, $cent->{patric_id});
    }

    $ss->write_subsystem();
    # Overwrite the curation log with import info
    open(L, ">", "$ss->{dir}/curation.log") or die "Cannot write $ss->{dir}/curation.log: $!";
    print L "$ss->{created}\t$ss->{curator}\tstarted\n";
    print L "$ss->{created}\t$ss->{curator}\tupdated\n";
    close(L);
    $ss->db_sync();
}

