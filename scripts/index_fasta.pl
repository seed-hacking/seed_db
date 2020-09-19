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


#  usage: index_fasta Fasta > Index

($fasta = shift @ARGV)
    || die "usage: index_fasta Fasta > Index";

if ( open( FASTA, "<$fasta" ) )
{
    $seek1 = tell FASTA;
    while ( defined( $_ = <FASTA> ) )
    {
	$seek2 = tell FASTA;
	if ( $_ =~ /^>(\S+)/ )
	{
	    $id = $1;
	    $id =~ s/^([^|]+\|[^|]+)\|.*$/$1/;
	    if ( $last_id )
	    {
		$ln = $seek1 - $start_seek;
		if ( ( $ln > 10 ) && ( $slen > 10 ) )
		{
		    print "$last_id\t$start_seek\t$ln\t$slen\n";
		}
		else
		{
		    print STDERR "$last_id not loaded: ln=$ln slen=$slen\n";
		}
	    }
	    $last_id = $id;
	    $start_seek = $seek2;
	    $slen = 0;
	}
	else
	{
	    $_ =~ s/\s+//g;
	    $slen += length( $_ );
	}
	$seek1 = $seek2;
    }

    if ( $last_id )
    {
	$ln = $seek1 - $start_seek;
	if ( ( $ln > 10 ) && ( $slen > 10 ) )
	{
	    print "$last_id\t$start_seek\t$ln\t$slen\n";
	}
	else
	{
	    print STDERR "$last_id not loaded: ln=$ln slen=$slen\n";
	}
    }
}
