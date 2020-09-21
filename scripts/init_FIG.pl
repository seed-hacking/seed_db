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
use strict;
use Data::Dumper;
use IPC::Run qw(run);

#
# Initialize FIG database.
#
# This is database-system specific.
#
# We assume the database system has been configured and the database
# server is up and running. Responsibility for this lies with the
# SEED configure process.
#
# We use system below because it's okay for the database drop to fail; if we used
# $FIG::run it would cause the script to terminate.
#

my $table_init = "CREATE TABLE file_table ( file varchar(200) UNIQUE NOT NULL, fileno INTEGER, PRIMARY KEY (file));";

if ($FIG_Config::dbms eq "Pg")
{

    my $dbport = $FIG_Config::dbport;
    my $dbuser = $FIG_Config::dbuser;

    #
    # Try to do some due diligence on ensuring we don't delete an active
    # database. Do this by creating a $fig and querying against the
    # genome table (in an eval in case it fails, like it really should).
    #

    my $genomes;
    eval {
	#
	# Consume the warnings that db init may emit.
	#
	my ($fig, $dbh);
        do {
	    local $SIG{__WARN__} = sub { die @_; };
	
	    $fig = new FIG;
	    $dbh = $fig->db_handle();
	} while(0);

	local $dbh->{_dbh}->{PrintError} = 0;
	local $dbh->{_dbh}->{RaiseError} = 1;

	my $resp = $dbh->SQL("select count(*) from genome");
	if ($resp && @$resp > 0)
	{
	    $genomes = $resp->[0]->[0];
	}

    };

    my $need_dropdb = 1;
    
    if ($@ eq "")
    {
	#
	# We didn't get an error - that means we were able to connect. Be wary.
	#

	if ($genomes > 0)
	{
	    #
	    # Yah, there's stuff in here.
	    #

	    print "You are initializing a SEED database named $FIG_Config::Db that appears to contain live data\n";
	    print "(it has $genomes genomes loaded). If you continue, this data will be\n";
	    print "wiped and a reload required.\n";
	    print "\nDo you wish to continue? (y/n) ";

	    my $ans = <STDIN>;
	    if ($ans !~ /^y/i)
	    {
		exit;
	    }
	}
	else
	{
	    #
	    # Yah, there might be.
	    #

	    print "You are initializing a SEED database named $FIG_Config::db that might contain live data\n";
	    print "(the database exists, but does not appear to have data)\n";
	    print "\nDo you wish to continue? (y/n) ";

	    my $ans = <STDIN>;
	    if ($ans !~ /^y/i)
	    {
		exit;
	    }
	}
    }
    else
    {
	if ($@ =~ /FATAL:\s+database\s+"$FIG_Config::db"\s+does\s+not\s+exist/)
	{
	    $need_dropdb = 0;
	}
    }

    print "\nInitializing new SEED database $FIG_Config::db\n\n";

    if ($need_dropdb)
    {
	system("dropdb -p $dbport -U $dbuser $FIG_Config::db");
    }
    &FIG::run("createdb -p $dbport -U $dbuser $FIG_Config::db");
    open(PSQL,"| psql -p $dbport -U $dbuser $FIG_Config::db") || die "could not initialize DB";

    print PSQL $table_init;

    close(PSQL);

    print "\nComplete. You will need to run \"fig load_all\" to load the data.\n";
} elsif ($FIG_Config::dbms eq "mysql" && !$FIG_Config::win_mode) {

    my @args;
    my @opts;
    if ($FIG_Config::dbsock ne "")
    {
	push(@args, -S => $FIG_Config::dbsock);
	push(@opts, "mysql_socket=$FIG_Config::dbsock");
    }
    push(@args, -u => $FIG_Config::dbuser);
    if ($FIG_Config::dbpass)
    {
	push(@args, "-p$FIG_Config::dbpass");
    }
    if ($FIG_Config::dbhost)
    {
	push(@args, "-h $FIG_Config::dbhost");
	push(@opts, "host=$FIG_Config::dbhost");
    }
    
    require DBI;
    my $db_dsn = join(";", "dbi:mysql:$FIG_Config::db", @opts);
    my $bare_dsn = join(";", "dbi:mysql:", @opts);

    my $dbh = DBI->connect($db_dsn, $FIG_Config::dbuser, $FIG_Config::dbpass, { RaiseError => 0, PrintWarn => 0, PrintError => 0 });
    if ($dbh)
    {
	my $c = $dbh->selectcol_arrayref(qq(SELECT count(*) from genome));
	if ($c && @$c && $c->[0] > 0)
	{
	    print "You are initializing a SEED database named $FIG_Config::db that appears to have live data\n";
	}
	else
	{
	    print "You are initializing a SEED database named $FIG_Config::db that might contain live data\n";
	    print "(the database exists, but does not appear to have data)\n";
	}
	print "\nDo you wish to continue? (y/n) ";
	    
	my $ans = <STDIN>;
	if ($ans !~ /^y/i)
	{
	    exit;
	}
	$dbh->do("drop database $FIG_Config::db");
    }

    print "Creating database $FIG_Config::db\n";
    my $dbh = DBI->connect($bare_dsn, $FIG_Config::dbuser, $FIG_Config::dbpass, { RaiseError => 0, PrintWarn => 0, PrintError => 0 });
    if (!$dbh)
    {
	print "Could not connect to database: $DBI::errstr\n";
    }

    my $ok = $dbh->do("create database $FIG_Config::db");
    if (!$ok)
    {
	print "Error creating database\n";
	exit 1;
    }
    $dbh->disconnect();

    my $dbh = DBI->connect($db_dsn, $FIG_Config::dbuser, $FIG_Config::dbpass, { RaiseError => 0, PrintWarn => 0, PrintError => 0 });

    if (!$dbh)
    {
	print "Could not connect to new database: $DBI::errstr\n";
	exit;
    }

    $dbh->do($table_init);
    $dbh->disconnect();
    
} elsif ($FIG_Config::dbms eq "mysql" && $FIG_Config::win_mode) {
    # Here we're in Windows, and we can't create the database on the
    # command line because of password glitchiness.
	# First, we connect to the database.
	my $fig = new FIG;
	my $dbh = $fig->db_handle();
	# Drop all the tables.
	my @tables = $dbh->get_tables();
	for my $table (@tables) {
		print "Dropping $table.\n";
		$dbh->drop_table(tbl => $table);
	}
	# Create the file table.
	print "Creating file table.\n";
	$dbh->SQL($table_init);
	# Tell the user we're done.
	print "Run load_all to load the data.\n";
}
elsif ($FIG_Config::dbms eq 'SQLite')
{
    # don't need to really do anything but create the table..
    my $fig = new FIG;
    my $dbh = $fig->db_handle();
    print "Creating file table.\n";
    $dbh->SQL($table_init);
} else {
	print "Invalid database configuration. Check the \"dbms\" variable in FIG_Config.\n";
}
