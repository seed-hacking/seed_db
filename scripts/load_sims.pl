#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
# 
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License. 
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#



# -*- perl -*-

use FIG;
use strict;

use Cwd 'abs_path';
    
my $fig = new FIG;

use DBrtns;

my $usage = "usage: load_sims [-clear] SimsDir";

my $dir;

my $drop_tables = 0;

if ($ARGV[0] eq '-clear')
{
    $drop_tables = 1;
    shift @ARGV;
}

($dir = shift @ARGV)
    || die $usage;

$dir = abs_path($dir);

-d $dir or die "Sims dir $dir does not exist\n";

my $dbf = $fig->db_handle();

my($mediumint, $pscType);
if ($dbf->{_dbms} eq 'mysql')
{
    $mediumint = "mediumint";
    $pscType = "real";
}
else
{
    $mediumint = "integer";
    $pscType = "float8";
}


opendir(SIMS,$dir) || die "$dir does not exist";
my @files = map { "$dir/$_" } grep { $_ !~ /^\./ } readdir(SIMS);

closedir(SIMS);

my($row_size, $max_rows) = $dbf->estimate_table_size(\@files);

if ($drop_tables)
{
    $dbf->drop_table( tbl => "condensed_sims" );
    $dbf->create_table( tbl => 'condensed_sims',
		       flds => "g1 smallint, p1 $mediumint, g2 smallint, p2 $mediumint, iden real, psc $pscType, paraN INTEGER",
		       type => 'InnoDB'
		      );
}

my $tmp_file = "$FIG_Config::temp/load_sim_tmp.$$";

foreach my $file (@files)
{
    my $load_file = $file;
    
    if (-s $file)
    {
	#
	# Determine if we need to map.
	#

	open(S, "<$file") or die "Cannot open $file: $!\n";
	$_ = <S>;

	if (/^fig/)
	{
	    print "Mapping $file\n";

	    open(TMP, ">$tmp_file") or die "Cannot open $tmp_file for writing: $!\n";

	    while (defined($_))
	    {
		chomp;
		my($p1, $p2, @rest) = split(/\t/);
		print TMP join("\t", $fig->map_peg_to_ids($p1), $fig->map_peg_to_ids($p2), @rest), "\n";

		$_ = <S>;
	    }
	    close(TMP);
	    close(S);

	    $load_file = $tmp_file;
	}
	
	print "Loading $load_file\n";
	
	$dbf->load_table( tbl => "condensed_sims",
			  file => $load_file );
    }
}

if ($drop_tables)
{
    print "Creating index\n";
    $dbf->create_index( idx  => "condensed_sims_ix",
		       tbl  => "condensed_sims",
		       type => "btree",
		       flds => "g1, p1" );
}

$dbf->vacuum_it("condensed_sims");

