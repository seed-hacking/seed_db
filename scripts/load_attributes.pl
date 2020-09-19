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

use FIG;
use Tracer;
use strict;

my $fig = new FIG;

=head1 Attribute Loader

This script loads attributes into the FIG database. The load process drops and re-creates
the attribute table and then applies any transactions present in the logs.

This script begins by deleting the database tables for ALL attributes. It then
reloads the data. It then processes through each of the genome directories according
to C<< $fig->genomes() >> and looks for attributes in each directory. These are written to
a temporary file and then loaded.

Note that key names can only contain the characters matched by the \w method
(i.e. [a-zA-Z0-9_])

The following command-line options are supported.

=over 4

=item trace

Tracing level. A higher trace level means more messages will appear. The default
trace level is 2. Tracing will be to the file C<trace.log> in the FIG temporary
directory as well as to the standard output.

=item sql

Turn on tracing for SQL commands.

=item links

Include the links as attributes. Currently, only pubmed IDs are loaded as links.

=item keep

Keep the temporary files. The temporary files are used to load the database.

=item noglobal

Ignore attributes in the global directory. This means only feature attributes will
be loaded.

=item safe

Normally, if errors or bad keys are found in an input file, the input file is replaced
with a cleaned copy. If this flag is set, the input file will be left alone and a the
cleaned copy will remain in the directory with the input file.

=back

In addition to the command-line options, the user can specify one or more genome IDs as
positional parameters. If specified, only these genomes would be processed; however, the
entire data table is dropped, so this option should only be used in testing.

=cut

# Get the command-line options.
my ($options, @genomes) = StandardSetup([],
                              { links => [0, "include the links as attributes"],
                                safe => [0, "do not replace input files with clean copies"],
                                keep => [0, "do not delete temporary load files"],
                                noglobal => [0, "ignore attributes in the global directory"],
                              }, "",
                              @ARGV);

Trace("Deleting and Recreating attribute table.") if T(2);


my %IGNORE_ATTR=('evidence_code'=>1);


# Set up the database tables. We have an attribute table and the a table of data about
# the attribute keys.
my $dbf = $fig->db_handle;
$dbf->drop_table( tbl => "attribute" );
$dbf->create_table( tbl => 'attribute', flds => "genome varchar(255), ftype varchar(64), id varchar(64), tag varchar(64), val text, url text");
$dbf->drop_table( tbl => "attribute_metadata" );
$dbf->create_table( tbl => 'attribute_metadata', flds => "attrkey varchar(64), metakey varchar(64), metaval text");

if ($FIG_Config::preIndex)
{
    create_indexes();
}

# we are going to store any transaction_logs we encounter here, and then process them at the end
my @tlogs;
# we are going to store any attributes metadata we encounter here, and then process them at the end
my @akeys;

# Loop through the genomes. We will store the attribute data in flat files and then load them
# all at once.
if (! @genomes) {
    @genomes = $fig->genomes;
}
Trace("Processing genomes.") if T(2);
foreach my $genome (@genomes) {
    # Get a unique attribute file name for this genome. We look for a file name that
    # does not yet exist. We don't expect there to be many, since keeping the files
    # is nonstandard.
    my $filecount = 1;
    while (-e "$FIG_Config::temp/load_attributes.$$.$genome.$filecount") {$filecount++}
    my $attributesFN = "$FIG_Config::temp/load_attributes.$$.$genome.$filecount";
    # Open the file for output.
    my $attributesFH = Open(undef, ">$attributesFN");
    my %kv;
    # I have rewritten this to allow the following things:
    # 1. Attributes for genomes are now available in $FIG_Config::organisms/$genome/Attributes
    # 2. Attributes for features (not just pegs) are now available in $FIG_Config::organisms/$genome/Features/*/Attributes

    my $dir = "$FIG_Config::organisms/$genome/Attributes";
    # Process the genome attribute directory.
    process_directory($dir, $attributesFH);

    # Now find the feature attributes files. There is one feature subdirectory
    # for each feature type-- peg, rna, etc. The attribute directories are below
    # this level.
    # We should use File::Find here, but I am not sure if that is in the
    # default distro, so I'll just write a quickie. Not as good, though.

    my $fattdir="$FIG_Config::organisms/$genome/Features";
    # This loop gets the feature type directories.
    foreach my $dir (OpenDir($fattdir, 1, 1)) {
        # Look for hyperlinks in the feature directory.
        if ($options->{links} && -e "$fattdir/$dir/$dir.links") {
            Trace("Loading links for feature directory $dir.") if T(4);
            # Convert the links into attributes.
            &links_file("$fattdir/$dir/$dir.links", $attributesFH);
        }
        # Process the feature attribute directory for this feature type.
        process_directory("$fattdir/$dir/Attributes", $attributesFH);
    }
    close($attributesFH);
    # If we didn't find anything for this genome, delete its file.
    if (!-s "$attributesFN") {
        unlink($attributesFN);
    } else {
        # finally load all the attributes
        my $result = $dbf->load_table( tbl => "attribute",
                                       file => "$attributesFN" );
        Trace("Got $result for " . $fig->genus_species($genome) . " ($genome) while trying to load database.") if T(3);
        if (! $options->{keep}) {
            unlink($attributesFN);
        } else {
            Trace("Genome load file $attributesFN kept.");
        }
    }
}

# now we need to load the global attributes files
if (! $options->{noglobal}) {
    Trace("Processing global attributes.") if T(2);
    my $globalDir = "$FIG_Config::global/Attributes";
    my $globalFN = "$FIG_Config::temp/global_attributes";
    my $globalFH = Open(undef, ">$globalFN");
    process_directory($globalDir, $globalFH);
    close $globalFH;
    if (-s "$globalFN") {
        my $result = $dbf->load_table( tbl => "attribute", file => "$globalFN" );
        Trace("Got $result for global load from $globalFN") if T(2);
    }
    if (! $options->{keep}) {
        unlink("$globalFN");
    } else {
        Trace("Global load file $globalFN kept.") if T(2);
    }
} else {
    Trace("Global attributes not requested.") if T(2);
}

# finally parse the transaction_log files and attributes_metadata Note that we only
# do this if the lists are non-empty.
&parse_transaction_logs(\@tlogs) if (scalar(@tlogs));
&parse_attributes_metadata(\@akeys) if (scalar(@akeys));

if (not $FIG_Config::preIndex)
{
    create_indexes();
}


Trace("Attributes loaded.") if T(2);
exit(0);

sub create_indexes
{
    Trace("Creating indexes.") if T(2);

    # rob messing with indexes
    # fields are now : genome ftype id key val url
    $dbf->create_index( idx  => "attribute_genome_ix", tbl  => "attribute", type => "btree", flds => "id,genome,ftype");
    $dbf->create_index( idx  => "attribute_genome_ftype_ix", tbl  => "attribute", type => "btree", flds => "genome, ftype");
    $dbf->create_index( idx  => "attribute_key_ix", tbl  => "attribute", type => "btree", flds => "tag" );
    #$dbf->create_index( idx  => "attribute_val_ix", tbl  => "attribute", type => "btree", flds => "val");
    #$dbf->create_index( idx  => "attribute_metadata_ix", tbl  => "attribute_metadata", type => "btree", flds => "attrkey, metakey, metaval");
    $dbf->create_index( idx  => "attribute_metadata_ix", tbl  => "attribute_metadata", type => "btree", flds => "attrkey, metakey");
}


=head3 process_directory

    process_directory($dir, $attributesFH);

Process attribute files in a particular directory. Transaction log file names will be
stored in the global C<@tlogs> and metadata files will be stored in C<@akeys>. All
other non-temporary files in the directory will be parsed into the file handle in
I<$attributesFH>. I<$dir> must be the directory name.

=cut

sub process_directory {
    my ($dir, $attributesFH) = @_;
    # Look for files in the attribute directory for this genome. The map is applied to file
    # names that aren't temporary and a failure to open is ignored.
    # Transaction log files and metadata file names are saved in the lists. The other files
    # are parsed into the database load file by "parse_file_to_temp".
    map {
        $_ eq "transaction_log" ?
            push @tlogs, "$dir/$_"
        : ($_ eq "attribute_keys" || $_ eq "attribute_metadata") ?
            push @akeys, "$dir/$_"
        : &parse_file_to_temp("$dir/$_", $attributesFH);
    } OpenDir($dir, 1, 1);
}

=head3 links_file()

Read the links and write them to the output filehandle provided. Requires two arguments -
the links file and the filehandle where they should be written to

=cut

sub links_file {
   # we are going to parse the links into a temporary file, and then read them
   # at the moment there is something weird where links has lots of things like gi, uniprot id, and so on. These are aliases
   # and I am not sure why they are in links.
   # I am just going to keep the pubmed links for now
   # however, I am going to parse out any pubmed link that may be for the genome article.
   # this will be done by removing any article with some large number of hits
   my ($links_file, $write_to)=@_;
   return unless (-e $links_file);

   Open(\*IN, "<$links_file");
   my $output;
   # Loop through the links file.
   while (<IN>) {
        # We only process PUBMED links.
        next unless (/pubmed/i);
        chomp;
        # Parse out the FIG ID, the link, and the link text.
        m#^(fig\|\d+\.\d+\.\w\w\w\.\d+).*(http.*)>(.*?)</a>#i;
        unless ($1 && $2 && $3) {
            Trace("Error parsing\n>>>$_<<<\n") if T(1);
            next
        }
        my ($peg, $url, $val) = ($1, $2, $3);
        # Remove the pubmed title from the link text.
        $val =~ s/pubmed\s+//i;
        # Create a feature attribute for the PUBMED link.
        push (@{$output->{$val}}, "$peg\tPUBMED\t$val\t$url\n");
   }
   # Only output a set of links if there are 100 or fewer.
   if ($output) {
      foreach my $key (keys %$output) {
            next if (scalar @{$output->{$key}} > 100);
            print $write_to @{$output->{$key}};
        }
    }
}



=head2 parse_file_to_temp()

This method takes two arguments, the name of a file to read and a filehandle to write to.
The file is opened, comments and blank lines are ignored, a couple of tests are applied,
and the data is written to the filehandle. The incoming file must be an attribute file.

Note, we also ignore the attributes stored in the hash %IGNORE_ATTR. These are mainly computed attributes.

=cut

sub parse_file_to_temp {
    my ($from, $to) = @_;
    return unless ($from);
    unless ($to) {
        open ($to, ">-")
    } #open $to to STDOUT if needed.

    Trace("Parsing $from.") if T(3);
    Open(\*IN, "<$from");

    # Create a file to contain a cleaned copy of the data. We do some fancy dancing to
    # try to make the name reasonable and unique.
    my $cleanName;
    if ($from =~ m#([^/]+)/Attributes/(.*)$#i) {
        $cleanName = "$FIG_Config::temp/$1$2.$$.cleaned";
    } else {
        $cleanName = "$FIG_Config::temp/attr.$$.cleaned";
    }
    my $fileCount = 1;
    while (-e "$cleanName$fileCount") {
        $fileCount++;
    }
    $cleanName = "$cleanName$fileCount";
    Open(\*CLEAN, ">$cleanName");
    # Count the input lines, errors, and comments.
    my $lineCount = 0;
    my $errorCount = 0;
    my $cleanCount = 0;
    while (<IN>) {
        $lineCount++;
        # Unlike chomp, Strip removes \r\n when needed.
        my $inputLine = Tracer::Strip($_);
        # Fix internal \r characters.
        $inputLine =~ s/\r/ /g;
        # Now we have a cleaned-up input line. We are going to set $comment to
        # 1 if the line should be skipped and $error to 1 if the line is in
        # error. Skipped lines are echoed unmodified to the output. Error
        # lines are converted to comments. Unskipped lines will be reassembled
        # and written back.
        my $error = 0;
        my $comment = 0;
        # We'll split the line into this variable.
        my @line = ();
        if ($inputLine =~ /^\s*\#/ || $inputLine =~ /^\s*$/) {
            # Echo blank and comment lines unmodified.
            $comment = 1;
        } else {
            @line = split /\t/, $inputLine;
	    # quietly ignore the IGNORE_ATTR keys
	    next if ($IGNORE_ATTR{$line[1]});


            if (! $line[0]) {
                Trace("No ID at line $lineCount in $from.") if T(1);
                $error = 1;
            } elsif (! $line[1]) {
                Trace("No key at line $lineCount in $from.") if T(1);
                $error = 1;
            } elsif (! $line[2]) {
                Trace("No value at line $lineCount in $from.") if T(1);
                $error = 1;
            } elsif (length($line[1]) > 64) {
                Trace("Key is longer than 64 characters at line $lineCount in $from.") if T(1);
                $error = 1;
            } else {
                if ($#line > 3) {
                    Trace("Line $lineCount in $from has more than 4 columns.") if T(1);
                    $error = 1;
                } else {
                    # Clean the key.
                    if ($line[1] =~ /\W/) {
                        $cleanCount++;
                        $line[1] = $fig->clean_attribute_key($line[1]);
                    }
                }
            }
        }
        # Now we output the line to the cleaned file.
        if ($comment) {
            print CLEAN "$inputLine\n";
        } elsif ($error) {
            print CLEAN "## ERROR ## $inputLine\n";
            $errorCount++;
        } else {
            # Insure we have a URL value.
            unless (defined $line[3]) {
                $line[3] = "";
            }
            # Rejoin the line and print it to the clean file.
            print CLEAN join("\t", @line) . "\n";
            # The clean file has been handled. Now we output to the load file.
            # Replace the first element in the line with the split feature as
            # appropriate.
            splice(@line, 0, 1, $fig->split_attribute_oid($line[0]));
            # Unescape the periods. Postgres behaves in a goofy way regarding
            # escape sequences.
            $inputLine = join "\t", @line;
            $inputLine =~ s/\\\./\./g;
            print $to "$inputLine\n";
        }
    }
    close IN;
    Trace("$lineCount lines read from $from.") if T(4);
    close CLEAN;
    # Now we figure out what to do with the clean file. If we did real work, then
    # we'll replace the original file with it. Otherwise, we delete it.
    if ($cleanCount || $errorCount) {
        Trace("$cleanCount malformed keys and $errorCount errors found in $from.") if T(1);
        if (! $options->{safe}) {
            rename $from, "$from~";
            rename $cleanName, $from;
        } else {
            Trace("Clean file $cleanName kept.") if T(3);
        }
    } else {
        unlink $cleanName;
    }
}

=head2 parse_transaction_logs

This method takes a reference to an array of paths to transactions_logs and will read
and process them

=cut

sub parse_transaction_logs {
    my $logs = shift;
    return unless $logs;
    foreach my $l (@$logs) {
        Trace("Parsing transaction log $l") if T(2);
        $fig->read_attribute_transaction_log($l);
    }
}

=head2 parse_attributes_metadata

This method takes a reference to an array of attributes metadata files and loads
them into the database. It will also rename attribute_keys to attribute_metadata
to be consistent and hopefully clearer.

=cut

sub parse_attributes_metadata {
    my $akeys = shift;
    return unless ($akeys);
    # first we are going to see if we need to rename or append any files
    my %attributekeys;
    foreach my $ak (@$akeys) {
        # rename attribute_keys to attribute_metadata by
        # appending to a file in case there is more data there.
        if ($ak =~ /attribute_keys$/) {
            my $location=$fig->update_attributes_metadata($ak);
            $attributekeys{$location}=1;
        } else {
            $attributekeys{$ak} = 1;
        }
    }
    foreach my $ak (keys %attributekeys) {
        Trace("Parsing attribute metadata $ak.") if T(4);
        Open(\*IN, "<$ak");
        while (<IN>) {
            next if (/^\s*\#/);
            chomp;
            my @line = split /\t/;
            # here we pass in the attribute key (line[0]) and a reference to
            # an array with metakey and key info
            $fig->key_info($line[0], {$line[1]=>$line[2]}, 1);
        }
    }
}

1;
