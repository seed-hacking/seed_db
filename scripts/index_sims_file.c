/*
 * Copyright (c) 2003-2006 University of Chicago and Fellowship
 * for Interpretations of Genomes. All Rights Reserved.
 *
 * This file is part of the SEED Toolkit.
 * 
 * The SEED Toolkit is free software. You can redistribute
 * it and/or modify it under the terms of the SEED Toolkit
 * Public License. 
 *
 * You should have received a copy of the SEED Toolkit Public License
 * along with this program; if not write to the University of Chicago
 * at info@ci.uchicago.edu or the Fellowship for Interpretation of
 * Genomes at veronika@thefig.info or download a copy from
 * http://www.theseed.org/LICENSE.TXT.
 */


/*  index_sims_file.c
 *
 *  Usage:  index_sims_file  SimsFileNumber  < SimsFile  > SimSeeks
 *  or      index_sims_file -v   (to return version number on standard output)
 *
 *  Read a sims file from standard in and
 *  write a line with four fields to stdout:
 *
 *     SeqID \t FileNumber \t Seek \t Length
 *
 *  Compile with:  cc -O index_sims_file.c -o index_sims_file
 */

#define  VERSION  "1.00"

#include <sys/types.h>
#include <stdio.h>
#include <ctype.h>   /*  isspace()  */
#include <stdlib.h>  /*  exit()     */
#include <string.h>
#include <unistd.h>  /*  ssize_t read( int fd, void * buf, size_t buflen ); */
                     /*  int close( int fd );  */
/* int open( char * name, int mode, int perms ); */  /*  acts like it is implicit  */
#include <sys/types.h>

/* 263.110u 147.320s 22:04.81 with 128 kB buffer */
/* 279.630u 151.410s 21:21.02 with 256 kB buffer */
/* 295.940u 154.350s 21:21.30 with 512 kB buffer */
#define BUFLEN  (256*1024)  /* read buffer length */
#define IDLEN   (    1024)  /* maximum id length  */

typedef unsigned long long u_long_long;

void report_last_seek( char * id, char * filenum, u_long_long seek0, u_long_long seek );
void report_seek( char * id, char * filenum, u_long_long seek0, u_long_long seek );
void usage( char *prog );

char buffer[BUFLEN];
char idbuf[IDLEN+1];

int main (int argc, char **argv) {
    char   *filenum, *iptr, *bptr;
    char    c;

    u_long_long seek0, seek, nfills;
    int ntogo;

    /* -v flag returns version */

    if ( ( argc == 2 ) && ( argv[1][0] == '-'  )
                       && ( argv[1][1] == 'v'  )
                       && ( argv[1][2] == '\0' )
       ) {
        printf( "%s\n", VERSION );
        return 0;
    }

    if (argc != 2) usage(argv[0]);
    filenum = argv[1];

    idbuf[0] = '\0';  /* initialize to empty string */

    /* Filling the buffer before starting helps simplify loop */

    ntogo = read( 0, buffer, BUFLEN );
    if ( ntogo <= 0 ) {
	fprintf( stderr, "%s: Empty sims file or read error\n", argv[0] );
	exit( 0 );
    }
    nfills = 1;
    bptr   = buffer;
    seek0  = 0;

    /* Read the input, line-by-line */

    while ( 1 ) {

	/* Seek for beginning of this line: */

	seek = BUFLEN * ( nfills - 1 ) + ( bptr - buffer );

        /*  Check for same id */

        iptr = idbuf;
        while ( 1 ) {
	    if ( ntogo <= 0 ) {
		ntogo = read( 0, buffer, BUFLEN );
		if ( ntogo <= 0 ) {
		    /*  This is the point for normal termination (run out */
		    /*  of input when trying to read next identifier).    */
		    /*  This should happen when ( iptr == idbuf ), ...    */

		    if ( iptr != idbuf ) {
			fprintf( stderr, "End of sims file inside identifier\n" );
		    }
		    report_last_seek( idbuf, filenum, seek0, seek );
		}
		nfills++; bptr = buffer;
	    }
	    if ( *bptr != *iptr ) break;
	    bptr++; ntogo--;
	    iptr++;
	}

        /* Either we have reached string terminators, or this is a new id */

	c = *bptr++; ntogo--;
        if ( ( ! isspace( (int) c ) ) || ( *iptr != '\0' ) ) {

            /* New id.  If there is a previous similarity, record it */

	    report_seek( idbuf, filenum, seek0, seek );
	    seek0 = seek;

            /* Copy the new id; starting from first difference */

	    while ( ! isspace( (int) c ) ) {
                if ( ( iptr - idbuf ) > IDLEN ) {
                    *iptr = '\0';
                    fprintf( stderr, "Identifier at seek of %llu is > %d bytes\n%s\n",
                             seek, IDLEN, idbuf );
                    exit( 0 );
                }
		*iptr++ = c;
		if ( ntogo <= 0 ) {
		    ntogo = read( 0, buffer, BUFLEN );
		    if ( ntogo <= 0 ) report_last_seek( idbuf, filenum, seek0, seek );
		    nfills++; bptr = buffer;
		}
		c = *bptr++; ntogo--;
	    }

            *iptr = '\0';  /* Terminate id string */
        }

        /*  Flush the rest of the input line  */

        while ( c != '\n' ) {
	    if ( ntogo <= 0 ) {
		ntogo = read( 0, buffer, BUFLEN );
		if ( ntogo <= 0 ) {
		    /*  Possibly a missing newline character.  We should */
		    /*  check count of fields, but this might change     */
		    seek = BUFLEN * ( nfills - 1 ) + ( bptr - buffer );
		    report_last_seek( idbuf, filenum, seek0, seek );
		}
		nfills++; bptr = buffer;
	    }
	    c = *bptr++; ntogo--;
	}
    }
    exit( 0 );
}


void report_last_seek( char * id, char * filenum, u_long_long seek0, u_long_long seek ) {
    report_seek( id, filenum, seek0, seek );
    exit( 0 );
}


void report_seek( char * id, char * filenum, u_long_long seek0, u_long_long seek ) {
    if ( id && id[0] && strlen(id) < 64 && filenum && filenum[0] && ( seek > seek0 ) ) {
        printf("%s\t%s\t%llu\t%llu\n", id, filenum, seek0, seek-seek0);
    }
}


void usage( char * prog ) {
    fprintf( stderr,
             "Usage: %s  SimsFileNumber  < SimsFile  > SimSeeks\n"
             "or     %s  -v    (writes the version to stdout)\n",
             prog, prog
           );
    exit( 0 );
}
