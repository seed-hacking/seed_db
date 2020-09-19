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


=pod

=head1 load_pirsf

Generate correspondences between PIR or UniProt and SEED

This script is in the process of being modified by Rob. It was initially for PIR Superfamilies, but we want to generalise it for other things too.

Usage: load_pirsf.pl -p or -u
-p load PIR superfamilies
-u load Uniprot knowledge base. The uniprotKB file must be specified at the moment.
-s load swiss prot. The swiss prot prosite file must be specified at the moment.

-v be verbose

The pir files come from ftp://ftp.pir.georgetown.edu/pir_databases/pirsf/data/pirsfinfo.dat and we need to download that file and do several things with it.

1. Generate a pir/seed correspondence table
2. Generate the Feature/peg/Attributes files for each of the genomes
3. Remove the new attributes and load the new ones

=cut

use strict;
use FIG;
use LWP::Simple;
my $fig=new FIG;
use raelib; # this is my own library, but we can move it into FIG or elsewhere

### File Locations. These should really be in FIG_Config but that appears to be outside CVS control
my $pir_file_from_pir="$FIG_Config::data/Global/pirsfinfo.dat";
my $pir_correspondence_file="$FIG_Config::data/Global/pirsfcorrespondence.txt";
my $pir_source_file="ftp://ftp.pir.georgetown.edu/pir_databases/pirsf/data/pirsfinfo.dat";

my ($pir, $uniprot, $verbose, $swissprot);
while (@ARGV) {
 my $t=shift @ARGV;
 if ($t eq "-p") {$pir=1}
 elsif ($t eq "-u") {$uniprot=shift @ARGV}
 elsif ($t eq "-s") {$swissprot=shift @ARGV}
 elsif ($t eq "-v") {$verbose=1}
}

if ($uniprot) {&load_uniprot()}
elsif ($swissprot) {&load_swissprot()}
elsif ($pir) {&load_pir()}
else {die "$0 -p|-u|-s -v. Note if you use -u or -s you have to specifiy the uniprot file"}
exit(0);


# get the file we need

sub load_pir {
 my $time=time;

 if ($verbose) {print STDERR "Downloading started at ", scalar(localtime(time)), "\n"}
 my $status=&download_file();
 print STDERR "Downloading file took ", time-$time, " seconds and status is $status\n"; $time=time;
 
 # generate the correspondance table
 
 $status=raelib->pirsfcorrespondence($pir_file_from_pir, $pir_correspondence_file, $verbose);
 print STDERR "Generating correspondence took ", time-$time, " seconds and status is $status\n"; $time=time;
 
 # remove all traces of old attributes
 
 $status=$fig->erase_attribute_entirely("PIRSF");
 print STDERR "Erasing attributes took ", time-$time, " seconds and status is $status\n"; $time=time;

 # now remove all traces of all links to
 foreach my $tple ($fig->fids_with_link_to('PIRSF'))
 {
    next unless ($tple->[1] =~ /pir.georgetown.edu/ && $tple->[1] =~ /ipcSF/);
    print STDERR "Deleting link ", join(" ", @$tple), "\n";
    $fig->delete_fid_link(@$tple);
 }
 print STDERR "Deleting links took ", time-$time, " seconds\n"; $time=time;
 
 # now we can read the correspondence table 
 my $tag; my $label;
 open (IN, $pir_correspondence_file) || die "Can't open $pir_correspondence_file";
 while (<IN>) {
  chomp;
  if (/^>PIR/) {
   m/^>PIR(\S+)\s+(.*)$/;
   ($tag, $label)=($1, $2);
   $label =~ s/\'//g; 
  #$label = quotemeta($label);
   next;
  }
  elsif (/^(\S+)\t(fig.*)/) {
   my ($pir, $peg)=($1, $2);
   #the following  url is into the PIR curator system. they asked me to
   #my $url="http://pir.georgetown.edu/sfcs-cgi/new/pirclassif.pl?id=".$tag;
   #they asked me to change this to their public database:
   my $url="http://pir.georgetown.edu/cgi-bin/ipcSF?id=".$tag;
   #$fig->add_attribute($peg, "PIRSF", "PIR".$tag." ".$label, $url, "pirsf");
   $fig->add_fid_link($peg, "<a href=\"$url\">PIR$tag</a>"); # note that at the moment this doesn't have the label in the URL
  }
 }
 
 print STDERR "Adding new tag values took ", time-$time, " seconds\n"; $time=time;
}

sub load_uniprot {
 # generate the correspondence table
 my $time=time;
 my $corr=raelib->uniprotcorrespondence($uniprot, "$FIG_Config::temp/uniprotKBcorr.txt", $verbose);
 print STDERR "$corr lines read and output is in $FIG_Config::temp/uniprotKBcorr.txt. Reading took, ", time - $time, " seconds\n";
}


sub load_swissprot {
 # generate the correspondence table
 my $time=time;
 my $corr=raelib->prositecorrespondence($swissprot, "$FIG_Config::temp/swissprotcorr.txt", $verbose);
 print STDERR "$corr lines read and output is in $FIG_Config::temp/swissprotcorr.txt. Reading took, ", time - $time, " seconds\n";
}






=head2 download_file()

Download the PIR file from the FTP site using LWP. We will back up the old file before downloading and continuing.

Returns 1 on success and 0 on failure

=cut

sub download_file {
 # rename the old correspondence file. We are going to add a number to the old file so that we keep it, but this should allow us
 # to save the information for a while in case something happens. At somepoint we should probably move these to /tmp or delete them
 # or something.
 my $count=1;
 while (-e "$pir_file_from_pir.$count") {$count++}
 rename($pir_file_from_pir, "$pir_file_from_pir.$count");
 rename($pir_correspondence_file, "$pir_correspondence_file.$count");

 # now use LWP to get the data
 if ($verbose) {print STDERR "\tgetting file from website...\n"}
 my $gotit=LWP::Simple::getstore($pir_source_file, $pir_file_from_pir);

 unless ($gotit == 200) {
  rename("$pir_file_from_pir.$count", $pir_file_from_pir);
  rename("$pir_correspondence_file.$count", $pir_correspondence_file);
  print STDERR "WARNING: There was an error downloading the data from $pir_source_file to $pir_file_from_pir. The old data was retained\n";
  return 0;
 }
 return $gotit;
}
