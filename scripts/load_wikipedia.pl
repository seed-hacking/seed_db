#
# Load wikipedia links into the database.
#
# Expensive; run periodically.
#

use strict;
use FIG;

my $fig = new FIG;

my $res = $fig->db_handle->SQL(qq(SELECT genome, gname FROM genome));

my $tmp = "$FIG_Config::temp/wiki.$$";
open(T, ">$tmp") or die "cannot write $tmp: $!";
T->autoflush(1);
my %done;
for my $ent (@$res)
{
    my($genome, $gname) = @$ent;

    my @organism_tokens = split(/\s/, $gname);
    my $gs = join(" ", @organism_tokens[0..1]);
    my $link;
    if (exists($done{$gs}))
    {
	print "$gs already done\n";
	$link = $done{$gs};
    }
    else
    {
	print "$gs lookup\n";
	$link = $fig->wikipedia_link($gs);
	$done{$gs} = $link;
	print T "$gs\t$link\n";
    }
}

close(T);

$fig->reload_table('all', "genome_wikipedia_link",
		       "gname varchar(255), url varchar(255), "
		       . "PRIMARY KEY ( gname )",
		       { },
		       $tmp);

unlink($tmp);
