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


# usage: load_id_correspondence [file]

=head ID Correspondence Table Loader
    
This script loads a table of id correspondence data into the SEED database. 

This table has an arbitrary number of columns, one per data source. The first row
of the table contains the data source identifier for that column.

Each row of the table defines a set of corresponding identifiers. 

We load the table into two relations in the database. The id_correspondence_type
table defines the set of allowed data sources; it may be lazily loaded based on the
columns in a correspondence table, as well as explicitly curated. The curation will 
allow one to define the type-specific linking rules.

Each set of identifiers is decomposed into a set of 3-tuples <set-id, identifier, type> 
where set-id is an encoding of the file name & line number, identifier is the identifier from the 
table, and type is the type designator for the column of the table.

=cut

use strict;
use FIG;
my $fig = new FIG;
use DBrtns;
use Data::Dumper;

my $dbf = $fig->db_handle;
use Tracer;

my $file = "$FIG_Config::global/id_correspondence";

if (@ARGV)
{
    $file = shift;
}

if (@ARGV)
{
    die "Usage: $0 [file]\n";
}

my $filenum = $fig->file2N($file);

my $table = "id_correspondence";
my $type_table = "id_correspondence_type";

$dbf->drop_table(tbl => $type_table);
$dbf->create_table(tbl => $type_table,
		   flds => qq(id		INTEGER,
			      name		VARCHAR(128),
			      searchable	BOOLEAN
			     )
		  );

my $tmp = "$FIG_Config::temp/id_load_temp";
open(TMP, ">$tmp") or die "Cannot write $tmp: $!";

#
# Read the correspondence file, and split into the 3-column form.
#
# If it is missing, jump to the table creation. 
#

open(F, "<$file") or die "Cannot read $file: $!";

#
# Read the header line & process column info.
#
$_ = <F>;

if (!$_)
{
    warn "Input file $file is empty\n";
    goto create_table;
}

chomp;
my @cols = split(/\t/, $_);
my @col_type;

#
#  Next line has uniqueness data.
#
$_ = <F>;
$_ or die "Input file $file too short.\n";
chomp;
my @col_search = split(/\t/, $_);

for my $cidx (0..$#cols)
{
    my $col = $cols[$cidx];

    my $res = $dbf->SQL(qq(SELECT id
			   FROM $type_table
			   WHERE name = ?), undef, $col);
    my $id;
    if (@$res)
    {
	$id = $res->[0]->[0];
    }
    else
    {
	#
	# Need to insert. Do this inside a transaction so we can safely allocate
	# a new index.
	#

	$dbf->begin_tran();
	my $res = $dbf->SQL(qq(SELECT MAX(id) FROM $type_table));

	if (@$res == 0)
	{
	    $id = 1;
	}
	else
	{
	    $id = $res->[0]->[0] + 1;
	}
	$dbf->SQL(qq(INSERT INTO $type_table (id, name, searchable)
		     VALUES (?, ?, ?)), undef, $id, $col, $col_search[$cidx]);
	$dbf->commit_tran();
    }

    $col_type[$cidx] = $id;
}

my $maxlen;
while (<F>)
{
    chomp;
    my @dat = split(/\t/);
    for my $i (0..$#dat)
    {
	for my $v (split(/;\s*/, $dat[$i]))
	{
	    if ($v ne '')
	    {
		print TMP join("\t", $filenum, $., $v, $col_type[$i]), "\n";
		my $lv = length($v);
		$maxlen = $lv if $lv > $maxlen;
	    }
	    #
	    # Last here if we want only the first entry. Current status
	    # 2008-03-12 is to take all entries.
	    # last;
	}
    }
}
close(TMP);

Trace("Recreating id correspondence table.") if T(2);

$maxlen++;

create_table:

my $file_num_type = "INTEGER";
my $type_type = "INTEGER";
if ($FIG_Config::dbms eq 'mysql')
{
    $file_num_type = "SMALLINT UNSIGNED";
    $type_type = "TINYINT UNSIGNED";
}
$maxlen //= 32;

$dbf->reload_table('all', $table,
		   qq(file_num		$file_num_type,
		      set_id		INTEGER,
		      protein_id	CHAR($maxlen),
		      type		$type_type),
	           { idc_set_idx => "file_num, set_id", idc_prot_idx => "protein_id" },
		   $tmp,
		  );

Trace("Id correspondence loaded.") if T(2);

