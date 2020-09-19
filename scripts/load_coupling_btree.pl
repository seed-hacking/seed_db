use FIG;
use Tracer;
use FIG_Config;

use DB_File;

use strict;

$DB_BTREE->{flags} = R_DUP;

my $file = "$FIG_Config::data/Global/coupling.btree";

if (-f $file)
{
    unlink($file);
}

my %h;
my $db = tie %h, "DB_File", $file, O_RDWR | O_CREAT, 0666, $DB_BTREE;
$db or die "Cannot create btree $file: $!\n";

my $scores = "$FIG_Config::data/CouplingData/scores";
open(F, "<$scores") or die "Cannot open $scores: $!\n";
print "Load $scores\n";
while (<F>)
{
    chomp;
    my($p1, $p2, $score) = split(/\t/);
    $h{$p1}= "$p2\t$score";
}
close(F);
untie %h;
