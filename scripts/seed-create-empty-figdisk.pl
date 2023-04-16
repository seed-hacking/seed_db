
#
# Create a new and empty FIGDisk in the $FIG_Config::fig_disk directory.
#

use strict;
use FIG_Config;
use File::Path qw(make_path);

my $dir = $FIG_Config::fig_disk;

if (-d $dir)
{
    die "FIGdisk $dir already exists\n";
}


print "Creating new FIGdisk in $dir\n";

make_path($dir,
	  $FIG_Config::var,
	  $FIG_Config::data,
	  $FIG_Config::global,
	  $FIG_Config::organisms,
	  $FIG_Config::NR,
	  $FIG_Config::temp,
	  "$FIG_Config::data/Sims",
	  "$FIG_Config::global/BBHs",
	  "$FIG_Config::data/NR",
	  "$FIG_Config::data/Logs",
	  "$FIG_Config::data/Ontologies/GO",
    );

touch("$FIG_Config::global/peg.synonyms",
      "$FIG_Config::global/ext_func.table",
      "$FIG_Config::global/ext_org.table",
      "$FIG_Config::global/chromosomal_clusters",
      "$FIG_Config::global/id_correspondence",
      "$FIG_Config::data/Ontologies/GO/fr2go",
      "$FIG_Config::data/Logs/functionalroles.rewrite",
    );

open(L, ">", "$FIG_Config::global/LinksToTools");
while (<DATA>)
{
    print L $_;
}
close(L);
close(DATA);

sub touch
{
    my(@files) = @_;
    for my $file (@files)
    {
	open(F, ">", $file);
	close(F);
    }
}
__DATA__
# The general format of this file is as follows:
#
#	Short, unique, name
#	Description to appear on the protein page
#	Base URL of the cgi-bin script
#	Method to use to get the result
# 	And then a series of tab separated key-value pairs that you need to use to get the data
# 	Finally, a record separator
# 
# If you put a single line between two separators that will be used to separate things in the table
# and will be given colspan=2 align=center parameters.
#
# Modified by Rob Edwards, RobE@theFig.info, 1/25/05. Please let me know if you add more tools to this file
# Also, let me know if you want to add something but can't
//
General Tools
//
Psi-Blast
NCBI's psi-blast is used to locate distant similarities
http://www.ncbi.nlm.nih.gov:80/blast/Blast.cgi
POST
QUERY	>FIGID\nFIGSEQ
DATABASE	nr
CDD_SEARCH	on
ENTREZ_QUERY	
COMPOSITION_BASED_STATISTICS	on,
FILTER	0
EXPECT	10
WORD_SIZE	3
MATRIX_NAME	BLOSUM62
NCBI_GI	on
GRAPHIC_OVERVIEW	is_set
FORMAT_OBJECT	Alignment
FORMAT_TYPE	HTML
DESCRIPTIONS	500
ALIGNMENTS	250
ALIGNMENT_VIEW	Pairwise
SHOW_OVERVIEW	on
RUN_PSIBLAST	on
I_THRESH	0.002
AUTO_FORMAT	on
PROGRAM	blastp
CLIENT	web
PAGE	Proteins
SERVICE	plain
CMD	Put
//
Transmembrane Predictions
//
TMpred
Tool for Predicting Transmembrane regions
http://www.ch.embnet.org/cgi-bin/TMPRED_form_parser
POST
outmode	html
min	17
max	33
comm	FIGID
format	plain_text
seq	FIGSEQ
//
TMHMM
Prediction of transmembrane helices in proteins
http://www.cbs.dtu.dk/cgi-bin/nph-webface
POST
configfile	/usr/opt/www/pub/CBS/services/TMHMM-2.0/TMHMM2.cf
SEQ	>FIGID\nFIGSEQ
outform	-noshort
//
Protein Signals for <em>Gram negative</em> bacteria
//
Gram negative PSORT
Prediction of protein localization sites
http://psort.hgc.jp/cgi-bin/okumura.pl
GET
origin	Gram-negative bacterium
title	FIGID
sequence	FIGSEQ
//
#Gram negative PSORTB
#Alternative prediction of protein localization sites
#http://www.psort.org/psortb/results.pl
#GET
#gram	negative
#format	html
#seqs	>FIGID\nFIGSEQ
#submit	Submit
//
Gram negative SignalP
Predicts the presence and location of signal peptide cleavage sites
http://www.cbs.dtu.dk/cgi-bin/nph-webface
POST
configfile	/usr/opt/www/pub/CBS/services/SignalP-3.0/SignalP.cf
SEQPASTE	>FIGID\nFIGSEQ
orgtype	gram-
method	nn+hmm
graphmode	gif+eps
format	full
trunc	70
//
Protein Signals for <em>Gram positive</em> bacteria
//
Gram positive PSORT
Prediction of protein localization sites
http://psort.hgc.jp/cgi-bin/okumura.pl
GET
origin	Gram-negative bacterium
title	FIGID
sequence	FIGSEQ
//
#Gram positive PSORTB
#Alternative prediction of protein localization sites
#http://www.psort.org/psortb/results.pl
#POST
#gram	negative
#format	html
#seqs	>FIGID\nFIGSEQ
#submit	Submit
//
Gram positive SignalP
Predicts the presence and location of signal peptide cleavage sites
http://www.cbs.dtu.dk/cgi-bin/nph-webface
POST
configfile	/usr/opt/www/pub/CBS/services/SignalP-3.0/SignalP.cf
SEQPASTE	>FIGID\nFIGSEQ
orgtype	gram+
method	nn+hmm
graphmode	gif+eps
format	full
trunc	70
//
Other useful tools
//
LipoP
Prediction of lipoproteins and signal peptides in Gram negative bacteria
http://www.cbs.dtu.dk/cgi-bin/nph-webface
POST
configfile	/usr/opt/www/pub/CBS/services/LipoP-1.0/LipoP.cf
SEQ	>FIGID\nFIGSEQ
outform	-noshort
//
Radar
Rapid Automatic Detection and Alignment of Repeats in protein sequences
http://www.ebi.ac.uk/cgi-bin/radar/radar
POST
sequence	>FIGID\nFIGSEQ
FormsButton27	Run
srchtype	interactive
//
PPSearch
Search for protein motifs against all patterns stored in the PROSITE pattern database
http://www.ebi.ac.uk/cgi-bin/ppsearch/ppsearch
POST
freq	no
graph	no
javagraph	no
sequence	>FIGID\nFIGSEQ
upfile	
FormsButton3	Run
//
Gram negative CELLO
Subcellular localization predictor at National Chiao Tung University
http://cello.life.nctu.edu.tw/cgi/main.cgi
POST
species	pro
file	
seqtype	prot
fasta	>FIGID\nFIGSEQ
Submit	Submit
//
Gram positive CELLO
Subcellular localization predictor at National Chiao Tung University
http://cello.life.nctu.edu.tw/cgi/main.cgi
POST
species	gramp
file	
seqtype	prot
fasta	>FIGID\nFIGSEQ
Submit	Submit
//
ProDom
A comprehensive set of protein domain families automatically generated from the SWISS-PROT and TrEMBL sequence databases
to_prodom.pl
INTERNAL
peg	FIGID
//
PDB
An Information Portal to Biological Macromolecular Structures
http://www.rcsb.org/pdb/search/smart.do
POST
smartSearchSubtype_0	SequenceQuery
eCutOff_0	10.0
searchTool_0	blast
sequence_0	FIGSEQ
//
For Specific Organisms
//
Bacillus subtilis - Institut Pasteur
224308.1
to_org_specific.pl
INTERNAL
peg	FIGID
alias	BG
url	http://genolist.pasteur.fr/SubtiList/genome.cgi?gene_detail+
comment	No results for your search. This tool is for Bacillus subtilis or for organism with a BG id.
//
Listeria EGD-e -Institut Pasteur
169963.1
to_org_specific.pl
INTERNAL
peg	FIGID
alias	lmo
url	http://genolist.pasteur.fr/ListiList/genome.cgi?gene_detail+
comment	No results for your search. This tool is for Listeria EGD-e or for organism with a lmo id.
//	
//
Listeria innocua CLIP 11262 -Institut Pasteur
272626.1
to_org_specific.pl
INTERNAL
peg	FIGID
alias	lin
url	http://genolist.pasteur.fr/ListiList/genome.cgi?gene_detail+
comment	No results for your search. This tool is for Listeria innocuaa CLIP or for organism with a lin id.
//
Synechocystis sp. PCC 6803 - CyanoBase
1148.1
to_org_specific.pl
INTERNAL
peg	FIGID
alias	syn:
url	http://www.kazusa.or.jp/cyano/Synechocystis/cgi-bin/orfinfo.cgi?title=Chr&name=
url_end	&iden=1
rel_links	yes
problem_links	category_cyano.cgi orfinfo.cgi exinfo.cgi blinkorf.cgi
problem_links_base	http://www.kazusa.or.jp/cyano/Synechocystis/cgi-bin/
home_dir	../mutants ../comments ../map ../aa_tfa ../blast2 
home_dir_base	http://www.kazusa.or.jp/cyano/Synechocystis/
image_base	http://www.kazusa.or.jp
base	http://www.kazusa.or.jp
append_after_base	"/cyanobase
comment	No results for your search. This tool is for Synechocystis sp. PCC 6803 or for organisms with a slr/srr id.
//
Nostoc sp. PCC 7120-CyanoBase
103690.1
to_org_specific.pl
INTERNAL
peg	FIGID
alias	alr
url	http://www.kazusa.or.jp/cyano/Anabaena/cgi-bin/orfinfo.cgi?title=Beta&name=
url_end	&iden=1
rel_links	yes
problem_links	category_ana.cgi orfinfo.cgi exinfo.cgi blinkorf.cgi
problem_links_base	http://www.kazusa.or.jp/cyano/Anabaena/cgi-bin/
home_dir	../mutants ../comments ../map ../aa_tfa ../blast2 
home_dir_base	http://www.kazusa.or.jp/cyano/Anabaena/
base	http://www.kazusa.or.jp
append_after_base	"/cyanobase
comment	No results for your search. This tool is for Nostoc sp. PCC 7120 or organisms with alr ids.
//
Synechococcus sp. WH 8102-CyanoBase
84588.1
to_org_specific.pl
INTERNAL
peg	FIGID
alias	SYNW
url	http://www.kazusa.or.jp/cyano/WH8102/cgi-bin/orfinfo.cgi?title=Chr&name=
url_end	&iden=1
rel_links	yes
problem_links	category_ana.cgi orfinfo.cgi exinfo.cgi blinkorf.cgi
problem_links_base	http://www.kazusa.or.jp/cyano/WH8102/cgi-bin/
home_dir	../mutants ../comments ../map ../aa_tfa ../blast2
append_after_base	"/cyanobase
home_dir_base	http://www.kazusa.or.jp/cyano/WH8102/
base	http://www.kazusa.or.jp/
comment	No results for your search. This tool is for Synechococcus sp. WH 8102 or organisms with SYNW ids.
//
Escherichia coli K12-Ecocyc
83333.1
to_org_specific.pl
INTERNAL
peg	FIGID
alias	b
url	http://biocyc.org/ECOLI/substring-search?type=NIL&object=
rel_links	yes
problem_links	server.html query.html
append_before_base	onClick="location.href='
append_after_base	feedback.html
base	http://biocyc.org/
comment	No results for your search. This tool is for Escherichia coli K12 or organisms with b ids.
//
Saccharomyces cerevisiae - Saccharomyces Genome Database
4932.3
to_org_specific.pl
INTERNAL
peg	FIGID
alias	EnsemblProtein
url	http://db.yeastgenome.org/cgi-bin/GO/goAnnotation.pl?dbid=
comment	No results for your search. This tool is for Saccharomyces cerevisia or organisms with YAL ids
//
Thermotoga maritima MSB8 - Joint Center for Structural Genomics
243274.1
to_org_specific.pl
INTERNAL
peg	FIGID
alias	TM
url	http://www1.jcsg.org/cgi-bin/psat/targetinfo.cgi?acc=
comment	No results for your search. This tool is for Thermotoga maritima MSB8 or organisms with TM ids
//
Arabidopsis thaliana - The Arabidopsis Information Resource
3702.1
to_arabidopsis.pl
INTERNAL
peg	FIGID
alias	At2
url	http://www.arabidopsis.org/servlets/Search?type=general&search_action=detail&method=1&name=
url_end	&sub_type=gene
rel_links	yes
problem_links	/help/faq.jsp#jobs /news/ /submit /download/index.jsp /portals/ /servlets/ /browse/ /tools/ /Blast /biocyc/index.jsp /cgi-bin/ /wublast/ /help/index.jsp /contact/index.jsp /about/index.jsp 
problem_links_base	http://www.arabidopsis.org
home_dir_base	http://www.arabidopsis.org
image_base	http://www.arabidopsis.org/i/
base	http://www.arabidopsis.org
comment	No results for your search. This is only for Arabidopsis aliases with At
//
RNAFold
The RNAfold web server will predict secondary structures of single stranded RNA or DNA sequences.
http://rna.tbi.univie.ac.at/cgi-bin/RNAWebSuite/RNAfold.cgi
POST
SCREEN	FIGDNASEQ
proceed	proceed
PAGE	2
method	p
noLP	noLP
dangling	d2
param	rna2004
svg	on
reliability	on
mountain	on
//
