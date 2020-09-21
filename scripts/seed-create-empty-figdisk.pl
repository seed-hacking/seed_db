
#
# Create a new and empty FIGDisk in the $FIG_Config::fig_disk directory.
#

use strict;
use FIG_Config;
use File::Path qw(make_path);

my $dir = $FIG_Config::fig_disk;

if (-d $dir)
{
    die "FIGdisk $dir already exists\n";
}


print "Creating new FIGdisk in $dir\n";

make_path($dir,
	  $FIG_Config::var,
	  $FIG_Config::data,
	  $FIG_Config::global,
	  $FIG_Config::organisms,
	  $FIG_Config::NR,
	  $FIG_Config::temp,
	  "$FIG_Config::data/Sims",
	  "$FIG_Config::global/BBHs",
	  "$FIG_Config::data/NR",
	  "$FIG_Config::data/Logs",
	  "$FIG_Config::data/Ontologies/GO",
    );

touch("$FIG_Config::global/peg.synonyms",
      "$FIG_Config::global/ext_func.table",
      "$FIG_Config::global/ext_org.table",
      "$FIG_Config::global/chromosomal_clusters",
      "$FIG_Config::global/id_correspondence",
      "$FIG_Config::data/Ontologies/GO/fr2go",
      "$FIG_Config::data/Logs/functionalroles.rewrite",
    );

sub touch
{
    my(@files) = @_;
    for my $file (@files)
    {
	open(F, ">", $file);
	close(F);
    }
}
