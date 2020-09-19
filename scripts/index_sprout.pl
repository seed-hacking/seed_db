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



#
# Sprout indexer.
#
# usage: index_sprout
#

use FIG;
use FIG_Config;
use Sprout;
use SproutFIG;
use Data::Dumper;
use DB_File;
use Fcntl;
use Tracer;

use strict;

TSetup("2 Sprout", "ERROR");

my $sproutData = "$FIG_Config::sproutData";

my $sfig  = SproutFIG->new($FIG_Config::sproutDB, $FIG_Config::sproutData);

my $indexDir = "$sproutData/Indexes";


&FIG::verify_dir($indexDir);

if (! -d $sproutData)
{
    die "Sprout data directory not found\n";
}

#
# Create indexes.
#
# We only index a subset of the data files.
#

my @index_files = create_index_files();

my $glimpse_input;

for my $f (@index_files)
{
    if (-f $f)
    {
	$glimpse_input .= "$f\n";
    }
    else
    {
	warn "Cannot find sprout data file to index: $f\n";
    }
}

#
# Clear out old indexes.
#

if (opendir(D, "$indexDir"))
{
    foreach (readdir(D))
    {
	if (/\.glimpse/)
	{
	    my $p = "$sproutData/Indexes/$_";
	    print "Remove $p\n";
	    unlink $p or die "Cannot remove $p: $!\n";
	}
    }
    closedir(D);
}

open(P, "| $FIG_Config::ext_bin/glimpseindex -b -E -n -z -H $sproutData/Indexes -F ");
print P $glimpse_input;
close(P);

opendir(D, "$sproutData/Indexes");
for $_ (readdir(D))
{
    if (/^\.glimpse/)
    {
	chmod 0666, "$sproutData/Indexes/$_";
    }
}

sub create_index_files
{
    my @files;

    push(@files, create_property_index());
    push(@files, create_feature_index());
    push(@files, create_alias_index());
    push(@files, create_annotation_index());

    return @files;
}

sub create_feature_index
{
    #
    # Create an index of the feature stuff - genus/species, tax, etc.
    #

    Trace("Creating feature index\n");

    if (!open(F, "<$sproutData/Genome.dtx"))
    {
	warn "Cannot open Feature table: $!\n";
	return;
    }

    my %genome;
    while (<F>)
    {
	chomp;
	my ($genome, undef, $genus, $species, $strain, $tax) = split(/\t/);
	$tax =~ s/;//g;

	push(@{$genome{$genome}}, $genus, $species, $strain, $tax);
    }

    close(F);

    #
    # Read the ComesFrom table too.
    #
    
    if (!open(F, "<$sproutData/ComesFrom.dtx"))
    {
	warn "Cannot open ComesFrom table: $!\n";
	return;
    }

    while (<F>)
    {
	chomp;
	my ($genome, $origin) = split(/\t/);

	push(@{$genome{$genome}}, $origin);
    }

    close(F);

    #
    # Read the features table, and write the index for it.
    #

    my $index_file = "$indexDir/feature";

    if (!open(IDX, ">$index_file"))
    {
	warn "cannot open $index_file for writing: $!\n";
	return;
    }

    if (!open(F, "<$sproutData/Feature.dtx"))
    {
	warn "Cannot open Feature table: $!\n";
	return;
    }

    while (<F>)
    {
	chomp;
	if (/^(fig\|(\d+\.\d+)[^\t]+)\t/)
	{
	    my $peg = $1;
	    my $gid = $2;

	    my $info = $genome{$gid};
	    if (ref($info))
	    {
		print IDX "$peg\t", join(" ", @{$genome{$gid}}), "\n";
	    }
	    else
	    {
		Trace("No info for $peg gid=$gid") if T(3);
	    }
	}
    }
    close(F);
    close(IDX);

    return $index_file;
}


sub create_property_index
{
    Trace("Creating property index.");
    #
    # Create a table
    #
    #   peg propname [propname...]
    #
    # where each property has a nonzero value.
    #
    #
    # We define some aliases here for the matches
    # that people might make.
    #

    my %aliases = (
		   'virulence-associated' =>  ['virulent', 'virulence'],
		  );

    #
    # Read the property values. Maintain a list of wanted-properties that
    # have nonzero values.
    #

    if (!open(F, "<$sproutData/Property.dtx"))
    {
	warn "Cannot open property table: $!\n";
	return;
    }
    my %wanted_properties;
    my %values;
    
    while (<F>)
    {
	chomp;
	my($id, $name, $value) = split(/\t/);
	if ($value ne "0")
	{
	    $wanted_properties{$id} = $name;
	    $aliases{$name} = [] unless $aliases{$name};
	    $values{$id} = $value;
	}
	else
	{
	    print "Skipping $id\n";
	}
    }
    close(F);

    my $index_file = "$indexDir/peg_property";
    if (!open(IDX, ">$index_file"))
    {
	warn "Cannot open $indexDir/peg_property for writing: $!\n";
	return;
    }

    if (!open(F, "<$sproutData/HasProperty.dtx"))
    {
	warn "Cannot open HasProperty table: $!\n";
	return;
    }

    while (<F>)
    {
	chomp;
	my($peg, $id) = split(/\t/);

	if (my $name = $wanted_properties{$id})
	{
	    print IDX "$peg\t$name ", join(" ", @{$aliases{$name}}, $values{$id}), "\n";
	}
	else
	{
	    print "Didn't find wanted props for $id\n";
	}
    }

    close(F);
    close(IDX);

    return $index_file;
}

sub create_annotation_index
{
    Trace("Creating annotation index.");
    #
    # Create the annotation index table.
    #
    # It contains a line for each annotation, of the form
    #
    # peg_id unique words in annotation
    #
    # We create this by relying on the structure of the keys in the Annotation
    # table being of the form figid:timestamp, so we can just drop the timestamp.
    #

    my $index_file = "$indexDir/annotation";

    if (!open(F, "<$sproutData/Annotation.dtx"))
    {
	warn "Cannot open Annotation table: $!\n";
	return;
    }

    if (!open(IDX, ">$index_file"))
    {
	warn "Cannot open $index_file for writing: $!\n";
	return;
    }

    while (<F>)
    {
	chomp;

	my ($aid, $ts, $anno) = split(/\t/);

	if ($aid =~ /^(fig\|.*):\d+/)
	{
	    my $peg = $1;
	    my %awords;

	    $anno =~ s/\\./ /g;
	    map { $awords{$_}++ } $anno =~ /\S+/g;

	    my @extra;
	    for my $aw (keys(%awords))
	    {
		if ($aw =~ /(\d+\.\d+\.\d+\.[\d|-]+)/)
		{
		    push(@extra, $1);
		}

	    }
	    print IDX "$peg\t", join(" ", keys(%awords), @extra), "\n";
	}
	    
    }
    close(F);
    close(IDX);
    return $index_file;
   
}
    
    
    
sub create_alias_index
{
    Trace("Creating alias index.");
	
    #
    # Create the alias index files.
    #

    #
    # Read the featurealias table.
    #

    my(@index_files);
    
    my %alias_to_id;
#    my $dbm_file = "$FIG_Config::temp/index_sprout.$$.db";

#    my $tied = tie %alias_to_id, 'DB_File', $dbm_file,  O_CREAT | O_RDWR, 0666, $DB_HASH;

#    $tied or die "Cannot create DB_File $tied: $!";

    if (!open(F, "<$sproutData/FeatureAlias.dtx"))
    {
	warn "Cannot open FeatureAlias table: $!\n";
	return;
    }

    #
    # Read FeatureAlias table. This table maps
    # each feature ID to its aliases:
    #
    #	fig|217.1.peg.1040      gi|729512
    #	fig|217.1.peg.1040      sp|Q07910
    #	fig|217.1.peg.1040      uni|Q07910
    #
    # In order to save memory overhead, we scan sequentially, collecting the set
    # of aliases for each peg and writing the external_alias index file.
    # We also collect the alias->peg mapping in the DB_File hash.
    #

    Trace("Read FeatureAlias " . time . "");


    my $index_file = "$indexDir/external_alias";
    push(@index_files, $index_file);

    if (!open(IDX, ">$index_file"))
    {
	warn "Cannot open $index_file for writing: $!\n";
	return;
    }

    my $cur;
    my @aliases;
    
    while (<F>)
    {
	chomp;

	my($id, $alias) = split(/\t/);

	if ($cur and $id ne $cur)
	{
	    print IDX join("\t", $cur, @aliases), "\n";
	    @aliases = ();
	    $cur = $id;
	}
	elsif (not $cur)
	{
	    $cur = $id;
	}

	#
	# For aliases of the form key|value, add "value" to the list.
	#

	push(@aliases, $alias);
	if ($alias =~ /^[^|]+\|(.*)$/)
	{
	    push(@aliases, $1);
	}

	$alias_to_id{$alias} .= "$id ";

	Trace("$.") if $. % 10000 == 0;
    }
    
    print IDX join("\t", $cur, @aliases), "\n";

    close(F);
    close(IDX);
    
    #
    # Now handle the external alias tables.
    #

    if (!open(F, "<$sproutData/ExternalAliasOrg.dtx"))
    {
	warn "Cannot open table ExternalAliasOrg: $!\n";
	return;
    }

    Trace("Index for ExternalAliasOrg " . time);
    my %peg_words;
    while (<F>)
    {
	chomp;
	my($alias, $org) = split(/\t/);

	#
	# Fix a bug in some org names.
	#
	$org =~ s/^\d+://;

	for my $peg (split(/ /, $alias_to_id{$alias}))
	{
	    if ($peg ne "")
	    {
		push(@{$peg_words{$peg}}, $org);
	    }
	}
    }
    close(F);

    my $index_file = "$indexDir/external_alias_org";

    if (!open(IDX, ">$index_file"))
    {
	warn "Cannot open $index_file for writing: $!\n";
	return;
    }
    Trace("Write index " . time);

    push(@index_files, $index_file);

    for my $peg (keys(%peg_words))
    {
	print IDX "$peg\t", join(" ", @{$peg_words{$peg}}), "\n";
    }

    close(IDX);

    #
    # And the functions.
    #

    if (!open(F, "<$sproutData/ExternalAliasFunc.dtx"))
    {
	warn "Cannot open table ExternalAliasFunc: $!\n";
	return;
    }

    Trace("Index for ExternalAliasFunc " . time);

    my %peg_words;
    while (<F>)
    {
	chomp;
	my($alias, $func) = split(/\t/);
	my(@extra);

	if ($func =~ /(\d+\.\d+\.\d+\.[\d+-]+)/g)
	{
	    push(@extra, $1);
	}

	for my $peg (split(/ /, $alias_to_id{$alias}))
	{
	    if ($peg ne "")
	    {
		push(@{$peg_words{$peg}}, $func, @extra);
	    }
	}
    }
    close(F);

    my $index_file = "$indexDir/external_alias_func";

    Trace("Write index " . time);

    if (!open(IDX, ">$index_file"))
    {
	warn "Cannot open $index_file for writing: $!\n";
	return;
    }

    push(@index_files, $index_file);

    for my $peg (keys(%peg_words))
    {
	print IDX "$peg\t", join(" ", @{$peg_words{$peg}}), "\n";
    }

    close(IDX);

    
    return @index_files;
    
}
