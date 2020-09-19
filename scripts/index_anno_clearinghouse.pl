use strict;
use NRTools;
use FIG;
use DB_File;

#
# Create the btree indexes on an annotation clearinghouse.
#
# anno.btree: id => annotation
# org.btree: id => organism
# orgnum.btree: orgname => numeric id
# orgname.btree:  numeric id => orgname
#

my $usage = "index_anno_clearinghouse SEED-directory target-directory";

@ARGV == 2 or die  $usage;

my $dir_seed = shift;
my $dir_target = shift;

&FIG::verify_dir($dir_target);

my $dir_nr = "$dir_target/NR";

my %NR_files;

$DB_BTREE->{flags} = R_DUP;

#
# Scan inputs.
#

print "Scan NR\n";
scan_NR_dir(\%NR_files, $dir_nr);
print "Scan SEED\n";
scan_seed_dir(\%NR_files, $dir_seed);
#scan_seed_dir(\%NR_files, $dir_seed, { limit => 10 });

#
# Create btrees. Empty existing files if present.
#
my $func_file = "$dir_target/anno.btree";
my $org_file = "$dir_target/org.btree";
my $orgname_file = "$dir_target/orgname.btree";
my $orgnum_file = "$dir_target/orgnum.btree";
my $alias_file = "$dir_target/alias.btree";

my $next_orgnum = 1;

-f $func_file and unlink($func_file);
-f $org_file and unlink($org_file);
-f $orgname_file and unlink($orgname_file);
-f $orgnum_file and unlink($orgnum_file);
-f $alias_file and unlink($alias_file);
my %func;
my $func_tie = tie %func, 'DB_File', $func_file, O_RDWR | O_CREAT, 0666, $DB_BTREE;
$func_tie or die "Cannot create bree $func_file: $!\n";

my %org;
my $org_tie = tie %org, 'DB_File', $org_file, O_RDWR | O_CREAT, 0666, $DB_BTREE;
$org_tie or die "Cannot create bree $org_file: $!\n";

my %orgname;
my $orgname_tie = tie %orgname, 'DB_File', $orgname_file, O_RDWR | O_CREAT, 0666, $DB_BTREE;
$orgname_tie or die "Cannot create bree $orgname_file: $!\n";

my %orgnum;
my $orgnum_tie = tie %orgnum, 'DB_File', $orgnum_file, O_RDWR | O_CREAT, 0666, $DB_BTREE;
$orgnum_tie or die "Cannot create bree $orgnum_file: $!\n";

my %alias;
my $alias_tie = tie %alias, 'DB_File', $alias_file, O_RDWR | O_CREAT, 0666, $DB_BTREE;
$alias_tie or die "Cannot create bree $alias_file: $!\n";

for my $ent (values %NR_files)
{
    if ($ent->{type} eq 'seed_org')
    {
	my $af = "$ent->{path}/assigned_functions";
	
	my $org = &FIG::file_head("$ent->{path}/GENOME", 1);
	chomp $org;
	my $orgnum = get_orgnum($org);
	print "Process $ent->{path} ($org)\n";

	next unless -f $af;
	my %seen;
	open(A, "tac $af|") or die "cannot open tac $af pipe: $!\n";
	while (<A>)
	{
	    if (/^(fig\|\d+\.\d+\.peg\.\d+)\t(.*)/)
	    {
		next if $seen{$1};
		$func{$1} = join($;, 'SEED', $2);
		$org{$1} = $orgnum;
		
		$seen{$1}++;
		
	    }
	}
	close(A);
    }
    else
    {
	my $org_file = "$ent->{path}/org.table";
	my $func_file = "$ent->{path}/assigned_functions";

	if (open(OF, "<$org_file"))
	{
	    print "Process $org_file\n";
	    while (<OF>)
	    {
		chomp;
		my($id, $org) = split(/\t/);
		my $val = get_orgnum($org);
		$org{$id} = $val;
		# map { $org{$_} = $val } map_id($id);
	    }
	    close(OF);
	}
	if (open(FF, "<$func_file"))
	{
	    print "Process $func_file\n";
	    while (<FF>)
	    {
		chomp;
		my($id, $func) = split(/\t/);
		my $val = join($;, $ent->{name}, $func);
		$func{$id} = $val;
		#map { $func{$_} = $val } map_id($id);

		if ($id =~ /^[^|]+\|(.*)/)
		{
		    $alias{$1} = $id;
		}
	    }
	    close(FF);
	}
    }
    $func_tie->sync();
    $org_tie->sync();
    $orgname_tie->sync();
    $orgnum_tie->sync();
    $alias_tie->sync();
}

sub get_orgnum
{
    my($org) = @_;

    my $num = $orgnum{$org};
    if (!defined($num))
    {
	$num = $next_orgnum++;
	$orgnum{$org} = $num;
	$orgname{$num} = $org;
    }
    return $num
}

sub map_id
{
    my($id) = @_;

    if ($id =~ /^[^|]+\|(.*)/)
    {
	return ($id, $1);
    }
    else
    {
	return ($id);
    }
}
