# -*- perl -*-
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


# usage: load_links

use strict;
use FIG;
my $fig = new FIG;
use DBrtns;
my $dbf = $fig->db_handle;
use Tracer;

my($org);

Trace("Recreating fid locks table.") if T(2);
$dbf->drop_table( tbl => "fid_locks" );
$dbf->create_table( tbl  => "fid_locks",
		    flds => "fid varchar(32)"
		  );

opendir(ORGS,"$FIG_Config::organisms") || die "could not open $FIG_Config::organisms";
my @orgs = grep { $_ =~ /^\d+\.\d+/ } readdir(ORGS);
closedir(ORGS);

my $tmpF = "$FIG_Config::temp/tmp_load.$$";
foreach $org (@orgs)
{
    Trace("Processing features for $org") if T(3);
    if ((-d "$FIG_Config::organisms/$org/Features") && opendir(TYPES,"$FIG_Config::organisms/$org/Features"))
    {
	my @types = grep { $_ !~ /^\./ } readdir(TYPES);
	closedir(TYPES);
	
	my $type;
	foreach $type (@types)
	{
	    my $file = "$FIG_Config::organisms/$org/Features/$type/locks";
	    if (open(IN,"<$file"))
	    {
		my %set;
		open(OUT,">$tmpF") || die "could not open $tmpF";
		while (defined($_ = <IN>))
		{
		    if ($_ =~ /^(\S+)\t(\d)/)
		    {
			$set{$1} = $2;
		    }
		}
		close(IN);

		foreach $_ (keys(%set))
		{
		    if ($set{$_})
		    {
			print OUT "$_\n";
		    }
		}
		close(OUT);
		$dbf->load_table( tbl => "fid_locks", 
		                  file => $tmpF
				);
	    }
	}
    }
}
unlink($tmpF);

Trace("Building index.") if T(2);
$dbf->create_index( idx  => "fid_links_ix",
		    tbl  => "fid_links",
		    type => "btree",
		    flds => "fid" );

$dbf->vacuum_it("fid_links");
Trace("Links loaded.") if T(2);

