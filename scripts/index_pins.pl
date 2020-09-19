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

#
# Scan and index the precomputed pins data, loading the table
# pin_seeks.
#

use FIG;
use File::Basename;
use Tracer;
use strict;

my $fig = new FIG;

# usage: index_pins [pins_dir]

use DBrtns;

my $pin_dir;
if (@ARGV == 0)
{
    $pin_dir = "$FIG_Config::data/PrecomputedPins";
}
elsif (@ARGV == 1)
{
    $pin_dir = shift @ARGV;
}
else
{
    die "Usage: $0 [pin-dir]\n";
}

if (!(-d $pin_dir)) {
    Trace("Precomputed pins directory $pin_dir not found.") if T(1);
    exit;
}

Trace("Re-creating pins table.") if T(2);
my $dbf = $fig->db_handle;

#
# Scan the pins directory.
#

my $seeks = "$FIG_Config::temp/pin_seeks.$$";

open(SEEKS, ">$seeks") or die "Cannot open seeks file $seeks: $!\n";

opendir(D, $pin_dir) or die "Cannot open pins directory $pin_dir: $!\n";

for my $genome (readdir(D))
{
    next if $genome =~ /^\./;
    if ($genome !~ /^\d+\.\d+$/ or not -d "$pin_dir/$genome")
    {
	die "Pins directory contains invalid entry $genome\n";
    }

    warn "Index $genome\n";

    #
    # Actual pins data stored in files named with the sims cutoff value.
    #
    for my $pfile (<$pin_dir/$genome/*>)
    {
	open(PINS, "<$pfile") or die "Cannot open pins file pfile: $!\n";

	my $filenum = $fig->file2N("$pfile");

	my $peg;
	my $block;
	my $seek;
	my $lseek;
	my $null;
	my $cutoff;
    
	while (<PINS>)
	{
	    if (/^(fig\|\d+\.\d+\.peg\.\d+)$/)
	    {
		$peg = $1;
		$null = 0;

		#
		# Default cutoff.
		#
		$cutoff = 1.0e-20;

		#
		# Search for key/value parameters.
		#

		while (<PINS>)
		{
		    last if m,^//,;
		    chomp;
		    my($k, $v) = split(/\t/);

		    if ($k eq 'cutoff')
		    {
			$cutoff = $v;
		    }
		}
		$seek = tell(PINS);
	    }
	    elsif (m,^//$,)
	    {
		my $len = $lseek - $seek;
		if ($null)
		{
		    print SEEKS "$peg\t$cutoff\t\\N\t\\N\t\\N\n";
		}
		else
		{
		    print SEEKS "$peg\t$cutoff\t$filenum\t$seek\t$len\n";
		}
	    }
	    elsif (/VAR1 = undef/)
	    {
		$null++;
		$lseek = tell(PINS);
	    }
	    else
	    {
		$lseek = tell(PINS);
	    }
	}
	close(PINS);
    }
}
closedir(D);
close(SEEKS);

$fig->reload_table('all', 'pin_seeks',
		   qq(fid varchar(32) NOT NULL,
		      cutoff real,
		      fileno INTEGER,
		      seek INTEGER,
		      len INTEGER),
	            { pin_seeks_fid_idx => 'fid' },
		   $seeks);
		   
