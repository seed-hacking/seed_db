#!/usr/bin/perl -w

#
# Copyright (c) 2003-2011 University of Chicago and Fellowship
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

use strict;
use AlignsAndTrees;
use Sapling;
use gjoseqlib;
use gjonewicklib;
use Tracer;

=head1 Load an Alignment and Tree

    load_md5_alignment directory alignFile treeFile alignMetaFile seqMetaFile

Load an MD5 alignment and tree from the specified files. There are five positional
parameters:

=over 4

=item 1

Name of the directory containing the files with the data to load.

=item 2

Base name of a FASTA file containing the aligned sequences.

=item 3

Base name of a NEWICK tree file containing the tree.

=item 4

Base name of a file containing the alignment metadata fields, one per line.

=item 5

Base name of a tab-delimited file describing the relationship between the alignments
and the sequences.

=back

=cut

# Check to see if this is a local Sapling.

my $sap;
if ($ENV{SAS_SERVER} eq 'localhost') {
    # Use the test database.
    $sap = Sapling->new(dbms => 'SQLite',
                        DBD => 'd:/Bruce/FIG/FIG/WinBuild/SaplingDBD.xml',
                        dbName => 'd:/Bruce/FIG/WebData/saplingTest.db');
} else {
    # Use the real database.
    $sap = Sapling->new();
}
# Get the parameters.
my ($directory, $alignFile, $treeFile, $metaFile, $seqMetaFile) = @ARGV;
# Verify the directory.
if (! -d $directory) {
    die "Invalid or missing input directory.\n";
}
# Create the alignment structure from the alignment file.
my $alignStruct = gjoseqlib::read_fasta("$directory/$alignFile");
# Create the tree structure from the tree file.
my $treeStruct = gjonewicklib::read_newick_tree("$directory/$treeFile");
# Get the alignment metadata.
my $ih = Tracer::Open(undef, "<$directory/$metaFile");
my (undef, $alignMethod, $alignParms, $alignProps, $treeMethod, $treeParms, $treeProps) = <$ih>;
close $ih;
# Loop through the sequence file, creating the sequence list.
my @sequenceData;
$ih = Tracer::Open(undef, "<$directory/$seqMetaFile");
while (! eof $ih) {
    # We need to replace the first column with a duplicate version of the MD5 ID.
    my (undef, @fields) = Tracer::GetLine($ih);
    push @sequenceData, [$fields[0], @fields];
}
# Call the alignment loader method.
my $alignID = AlignsAndTrees::load_md5_alignment_and_tree($sap, $alignStruct, $treeStruct,
                                                          \@sequenceData,
                                                          [$alignMethod, $alignParms, $alignProps,
                                                           $treeMethod, $treeParms, $treeProps]);
# Inform the user of the new alignment ID.
print "Alignment $alignID loaded.\n";

