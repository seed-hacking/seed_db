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
my($remove_dups,%assignments,$must_correct);
Trace("Recreating fid links table.") if T(2);
$dbf->drop_table( tbl => "fid_links" );
$dbf->create_table( tbl  => "fid_links",
		    flds => "fid varchar(32), link varchar(255)"
		  );

opendir(ORGS,"$FIG_Config::organisms") || die "could not open $FIG_Config::organisms";
my @orgs = grep { $_ =~ /^\d+\.\d+/ } readdir(ORGS);
closedir(ORGS);

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
			if (opendir(FEAT,"$FIG_Config::organisms/$org/Features/$type"))
			{
				my @links = grep { $_ =~ /links$/ } readdir(FEAT);
				closedir(FEAT);
		
				my $file;
				foreach $file (@links)
				{
					if (open(LINKS,"<$FIG_Config::organisms/$org/Features/$type/$file"))
					{
						$_ = <LINKS>;
						chop;
						my @flds = split(/\t/,$_);
						close(LINKS);
			
						if (@flds == 2)
						{
							$dbf->load_table( tbl => "fid_links", 
									  file => "$FIG_Config::organisms/$org/Features/$type/$file"
									  );
						}
						elsif (@flds == 3)
						{
							if (open(REFORMATTED,">/tmp/links.$$"))
							{
								while (defined($_))
								{
									if (@flds == 3)
									{
										my $link = join("",("<a href=",$flds[2],">",$flds[1],"</a>"));
										print REFORMATTED "$flds[0]\t$link\n";
									}
									$_ = <LINKS>;
									chop; 
									@flds = split(/\t/,$_);
								}
								close(REFORMATTED);
								$dbf->load_table( tbl => "fid_links", 
										  file => "/tmp/links.$$"
										  );
								unlink("/tmp/links.$$");
							}
						}
					}
				}
			}
		}
    }
}
Trace("Building index.") if T(2);
$dbf->create_index( idx  => "fid_links_ix",
		    tbl  => "fid_links",
		    type => "btree",
		    flds => "fid" );

$dbf->vacuum_it("fid_links");
Trace("Links loaded.") if T(2);

