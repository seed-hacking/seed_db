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


# usage: load_links

use strict;
use FIG;
use Tracer;
my $fig = new FIG;

$fig->reload_table('all', "literature_titles",
					"gi varchar(32), pmid varchar(32), title text",
					{ titles_gi_ix => "gi", titles_pmid_ix => "pmid" },
					"$FIG_Config::global/Literature/gi_pmid_title");
Trace("Literature titles loaded.");
