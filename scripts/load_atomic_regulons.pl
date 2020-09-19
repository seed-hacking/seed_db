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


###########################################
use strict;

use FIG;
my $fig = new FIG;

# usage: load_atomic_regulons genome-id ar-file

#
# Load a file of atomic regulons as created by compute_atomic_regulons_for_dir.
#
# We just keep a cache from peg => (genome, regulon-number)
# so we can do fast lookups from the seed pages to determine the regulon.
#

@ARGV == 2 or die "Usage: load_atomic_regulons genome-id atomic-regulon-file\n";
my $genome = shift;
my $ar_file = shift;

open(AR, "<", $ar_file)  or die "Cannot open $ar_file: $!";

my $dbf = $fig->{_dbf};

if (!$dbf->table_exists("atomic_regulon"))
{
    $dbf->create_table( tbl => 'atomic_regulon',
		       flds => qq(fid varchar(64),
				  genome varchar(32),
				  regulon int,
				  size int),
		      );
    
    $dbf->create_index( idx  => "atomic_regulon_ix",
		       tbl  => "atomic_regulon",
		       type => "btree",
		       flds => "fid" );
    $dbf->create_index( idx  => "atomic_regulon_genome_ix",
		       tbl  => "atomic_regulon",
		       type => "btree",
		       flds => "genome" );
}

my $n = $dbf->{_dbh}->do(qq(DELETE FROM atomic_regulon
			    WHERE genome = ?), undef, $genome);
print "Deleted $n old values\n";

my $sth = $dbf->{_dbh}->prepare(qq(INSERT INTO atomic_regulon (fid, genome, regulon, size)
				   VALUES(?, ?, ?, ?)));
my @ents;
my %sizes;
while (<AR>)
{
    chomp;
    my($reg, $fid, $fn) = split(/\t/);
    $sizes{$reg}++;
    push(@ents, [$reg, $fid]);
}
if (@ents == 0)
{
    die "No entries found in $ar_file\n";
}

for my $ent (@ents)
{
    my($reg, $fid) = @$ent;
    $sth->execute($fid, $genome, $reg, $sizes{$reg});
}
close(AR);
