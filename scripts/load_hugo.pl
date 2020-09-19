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


use strict;
use FIG;
use LWP::Simple;
use FIG_Config;

my $fig = new FIG;

my $HugoAttribName = "HUGO";      # The name of the key for storing this info in attribs

my %symbol_to_name;            

print "Downloading new Hugo data\n";

my $source_file ="http://www.gene.ucl.ac.uk/cgi-bin/nomenclature/gdlw.pl?title=All+Data;col=gd_hgnc_id;col=gd_app_sym;col=gd_app_name;col=gd_status;col=gd_locus_type;col=gd_prev_sym;col=gd_prev_name;col=gd_aliases;col=gd_pub_chrom_map;col=gd_date2app_or_res;col=gd_date_mod;col=gd_date_name_change;col=gd_pub_acc_ids;col=gd_enz_ids;col=gd_pub_eg_id;col=gd_mgd_id;col=gd_other_ids;col=gd_pubmed_ids;col=gd_pub_refseq_ids;col=gd_gene_fam_name;col=md_gdb_id;col=md_eg_id;col=md_mim_id;col=md_refseq_id;col=md_prot_id;status=Approved;status=Approved+Non-Human;status=Entry+Withdrawn;status_opt=3;=on;where=;order_by=gd_app_sym_sort;limit=;format=text;submit=submit;.cgifields=;.cgifields=status;.cgifields=chr";

my $download_file = "$FIG_Config::global/HUGO_download_file.txt";

my $gotit=LWP::Simple::getstore($source_file, $download_file);
die "Failed to download HUGO data from $source_file.\n" unless ($gotit == RC_OK);

open(IN,"$download_file");
open(OUT,">$FIG_Config::global/HUGO_correspondence.txt");
open(OUT2,">$FIG_Config::global/CV/cv_search_HUGO.txt");

#
# build map from hugo symbols to hugo names
#

print "Building Hugo symbol <-> name correspondence map.\n";

my @lines = <IN>;
my $counter = 1;
for my $l (@lines)
{
    if ($l =~ /(^\d+)\t(.*?)\t(.*?)\t(.*)/)
    {
        $symbol_to_name{$2} =$3;
	print OUT2 "HUGO\t$2\t$3\n"
    }

}

#
#remove all old HUGO attributes first

print "Erasing $HugoAttribName attributes.\n";
my $status=$fig->erase_attribute_entirely( $HugoAttribName );

# Insert the HUGO names as attributes to each PEG with a
# HUGO symbol

my $dir = "$FIG_Config::data/Genomes";
my @hsapien_genomes = ();    

foreach my $genome( $fig->genomes())
{ 
    if ($genome =~/^9606\./){push(@hsapien_genomes,$genome)}
}

foreach my $genome (@hsapien_genomes)
{
 print "$genome\n";
 foreach my $peg ($fig->pegs_of($genome))
 {
    my @aliases = $fig->feature_aliases($peg);
    foreach my $a (@aliases)
    {
       if ($a =~/HGNC:(.*)/)
       {
	  my $symbol = $1;
          my $value = $symbol_to_name{$symbol};
          my $attribute_value = $symbol."; ".$value;
          print OUT "$peg\t$HugoAttribName\t$1\t$attribute_value\n";
	  print "$peg\t$HugoAttribName\t$attribute_value\n";
          
	  # actually, enter these as controlled vocab, not as plain attribs
          #$fig->add_attribute($peg,$HugoAttribName,$attribute_value);

          my $status = $fig->add_cv_term("master:batch", $peg, $HugoAttribName,$symbol, $value);
	  if (!$status) {
	      print "$peg- Added ($HugoAttribName, $symbol, $value)\n";
	  } else {
	      print "$peg- Error for ($HugoAttribName, $symbol, $value)\t$status\n";
	  }
       }
    }
  } 
}      
 
