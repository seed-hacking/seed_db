#
# Import subsystems from pubseed
#

use Subsystem;
use LWP::UserAgent;
use YAML;
use strict;
use URI::Escape;
use JSON::XS;
use File::Slurp;
use Date::Parse;
use Data::Dumper;
use FIG;

my $fig = FIG->new;
my $ua = LWP::UserAgent->new;

my $seed = "https://pubseed.theseed.org";

#
# Load genome list for populating the subsystem
#

my %genomes = map { $_ => 1 } $fig->genomes;

#
# Load subsystem list to look up curator and classification.
#

open(F, "-|", "seed-list-pubseed-subsystems")
    or die "Cannot run seed-list-pubseed-subsystems: $!";

my %ss_info;
while (<F>)
{
    chomp;
    my($name, $c1, $c2, $curator, $version, $last_mod) = split(/\t/);
    $name =~ s/\s+/_/g;
    $ss_info{$name} = [$c1, $c2, $curator, $version, str2time($last_mod)];
}


for my $ss_name (@ARGV)
{
    print "$ss_name\n";

    my $names_doc = Dump([$ss_name]);
    my $res = $ua->post("$seed/subsystem_server.cgi",
			{ function => "roles", args => $names_doc });
    if (!$res->is_success)
    {
	warn "Failure retrieving roles for $ss_name\n";
	next;
    }
    my $roles = Load($res->content);

    my $ss = $fig->get_subsystem($ss_name);
    if (!$ss)
    {
	$ss = Subsystem->new($ss_name, $fig, 1);
    }

    my($c1, $c2, $curator, $version, $last_mod) = @{$ss_info{$ss_name}};

    $ss->{classification} = [$c1, $c2];
    $ss->{last_updated} = $ss->{created} = $last_mod;
    $ss->{curator} = $curator;
    $ss->{version} = $version;
    $ss->{exchangable} = 0;

    my($rlist) = map { $_->[1] }  grep { $_->[0] eq $ss_name } @$roles;

    for my $r (@$rlist)
    {
	my($role, $abbr) = @$r;
	my $id = $ss->get_role_index($role);
	if (!defined($id))
	{
	    $ss->add_role($role, $abbr);
	}
    }

    my $res;
    for my $retry (1..10)
    {
	my $this_res = $ua->post("$seed/subsystem_server.cgi",
			 { function => "subsystem_spreadsheet", args => $names_doc });
	if ($this_res->is_success)
	{
	    $res = $this_res;
	    last;
	}
	warn "Failure retrieving spreadsheet for $ss_name: " . $res->status_line . " " . $res->content;
	sleep 10;
    }
    if (!$res)
    {
	die "Failed to retrieve spreadsheet for $ss_name after retrying\n";
    }
    my $spreadsheet = Load($res->content);

    for my $ent (@$spreadsheet)
    {
	my($ent_ss, $genome, $variant, $cells) = @$ent;
	next if $ent_ss ne $ss_name;
	next unless $genomes{$genome};

	my $row = $ss->get_genome_index($genome);
	if (!defined($row))
	{
	    $row = $ss->add_genome($genome);
	    $ss->{variant_code}->[$row] = $variant;
	}

	for my $cell (@$cells)
	{
	    my($fid, $role) = @$cell;

	    my $col = $ss->{role_index}->{$role};
	    my $ss_cell = $ss->get_cell($row, $col);
	    push(@$ss_cell, $fid);
	}
    }

    $ss->write_subsystem();

    # Overwrite the curation log with import info
    open(L, ">", "$ss->{dir}/curation.log") or die "Cannot write $ss->{dir}/curation.log: $!";
    print L "$ss->{created}\t$ss->{curator}\tstarted\n";
    print L "$ss->{created}\t$ss->{curator}\tupdated\n";
    close(L);
    $ss->db_sync();
}

