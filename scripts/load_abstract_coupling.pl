
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

use FIG;
use Tracer;

my $fig = new FIG;

# usage: load_abstract_coupling

my $dirA = "$FIG_Config::data/AbstractFuncCoupling";
if (! opendir(DIR,$dirA))
{
    Trace("Abstract Coupling directory $dirA not found.") if T(1);
    exit;
}
my @types = grep { $_ !~ /^\./ } readdir(DIR);
closedir(DIR);

use DBrtns;

my $dbf = $fig->db_handle;
$dbf->drop_table( tbl => 'afc' );
$dbf->create_table( tbl => 'afc', 
                    flds => 'peg1 varchar(32), peg2 varchar(32), score float, type varchar(16), extra varchar(255)'
                    );
my($type);
foreach $type (@types)
{
    Trace("adding coupling data: type=$type") if T(2);
    if (opendir(DATA,"$dirA/$type/Data"))
    {
        my @to_load = grep { $_ =~ /^\d+\.\d+/ } readdir(DATA);
        closedir(DATA);
        foreach my $file (@to_load)
        {
            &load_file($dbf,$type,"$dirA/$type/Data/$file");
        }
    }
}

Trace("Building index.") if T(2);
$dbf->create_index( idx  => "afc_ix",
                    tbl  => "afc",
                    type => "btree",
                    flds => "peg1" );

Trace("Abstract Couplings loaded.") if T(2);

sub load_file {
    my($dbf,$type,$file) = @_;
    my $tmpFileName = "$FIG_Config::temp/$type$$.dxx";
    # Use tracer Open to get nice error messages.
    Open(\*TMP, "<$file");
    Open(\*TMPOUT, ">$tmpFileName");
    # Convert the input file so that it can be loaded directly into the database. We do
    # this by changing the delimiter from the standard (TAB) to an escape character.
    my $count = 0;
    while (defined($_ = <TMP>))
    {
        if ($_ =~ /^(fig\|\d+\.\d+\.peg\.\d+)\t(fig\|\d+\.\d+\.peg\.\d+)\t(\S+)(\t(\S.*\S))?/)
        {
            my($peg1,$peg2,$sc,$extra) = ($1,$2,$3,$5);
            $extra = defined($extra) ? $extra : "";
            my $line = join("\e", $peg1, $peg2, $sc, $type, $extra);
            print TMPOUT "$line\n";
            $count++;
        }
    }
    close TMP;
    close TMPOUT;
    Trace("$count records read from $file.") if T(2);
    # Load the table from the temp input file.
    Trace("Loading AFC data from $tmpFileName.") if T(2);
    $dbf->load_table( tbl => "afc", file => $tmpFileName, delim => "\e" );
    # Delete the temp input file.
    Trace("Deleting $tmpFileName.") if T(2);
    unlink $tmpFileName;
}
