use FIG;
use Tracer;
use FIG_Config;

use DB_File;

use strict;

my $file = "$FIG_Config::data/Global/bbhs.btree";

$DB_BTREE->{flags} = R_DUP;

if (-f $file)
{
    unlink $file;
}

my %h;
my $db = tie %h, "DB_File", $file, O_RDWR | O_CREAT, 0666, $DB_BTREE;
$db or die "Cannot create btree $file: $!\n";

my @files = map { "$FIG_Config::global/BBHs/$_" } grep { $_ =~ /^\d+\.\d+$/ } OpenDir("$FIG_Config::global/BBHs");

for my $file (@files)
{
    open(F, "<$file") or die "Cannot open $file: $!\n";
    print "Load $file\n";
    while (<F>)
    {
	chomp;
	my($p1, $p2, $psc) = split(/\t/);
	my $val = "$p2\t$psc";
	$h{$p1}= $val;
    }
    close(F);
    $db->sync;
}
untie %h;
