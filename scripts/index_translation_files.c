/*  index_translation_files.c
 *
 *  compile with
 *
 *     cc -O3 -o index_translation_files index_translation_files.c
 *
 *
 *  Usage: index_translation_files  max_ids  max_id_len  [cksum_suffix_len (D=64)] \
 *                 < file_list > seek_size_and_cksum_info
 *  or     index_translation_files -v  > version_number
 *
 *
 *  file_list contains one or more lines of form:
 *
 *      FileNum \t FileName [ \t IDPrefix ]
 *
 *      FileNum    FIG file index number
 *      FileName  Name of the file to be indexed (should be absolute path)
 *      IDPrefix  If given, ids in the file will be checked for the prefix
 *
 *
 *  Seek records are of form:
 *
 *      SeqId \t FileNum \t StartSeek \t DataBytes \t SeqLen \t Cksum \t SuffixCk
 *
 *      SeqId      First max_id_len characters from sequence id
 *      FileNum    FIG file index number
 *      StartSeek  File seek to the first byte of the sequence
 *      DataBytes  Number of file bytes with the sequence data (including \n)
 *      SeqLen     Number of non-space sequence char
 *      Cksum      cksum of toupper( non-space sequence char )
 *      SuffixCk   cksum of last suffix_len toupper( non-space sequence char )
 *
 *  Version 1.00.
 *
 *  Version 2.00:
 *     Add uppercase sequence cksum (coerced to signed int) of to seek record.
 *     Add sequence suffix cksum (coerced to signed int) to seek record.
 *     Remove all but last seek for duplicated ids.
 *     Check for a specified "prefix" on ids in each file.
 *     Get most limits from command line.
 *
 *  Version 2.01:
 *     Include cksum.c and simplehash.c in this file to simplify the make.
 *
 *  Thoughts for the future:
 *     Get avg_id_len from the command line
 *     Dynamically increasing key storage would not be hard
 *     Dynamically increasing number of enties is a pain
 *          ( Since file name is known, we could autorecover using
 *            "grep '^>' filename | wc -l" to get a new max, or do
 *            our own within the program.)
 */

#include <stdio.h>
#include <stdlib.h>    /*  exit() */
#include <fcntl.h>     /*  O_RDONLY -- actually in <sys/fcntl.h> */
#include <unistd.h>    /*  ssize_t read( int fd, void *buf, size_t buflen ); */
#include <string.h>    /*  for strcmp() and strncmp() */

#define  VERSION      "2.01"  /*  Program version number  */
#define  MINLEN          11   /*  Minimum sequence length indexed */
#define  SHOWSHORT        0   /*  Report identifiers skipped due to MINLEN?  */
#define  SHOWDUPS         1   /*  Report duplicated ids (off might be best) */
#define  SUFFIXLEN       64   /*  Number of residues in a "suffix cksum" */
#define  SUFBUFLEN     1024   /*  Bytes in suffix buffer (power of 2) */
#define  SUFBUFMSK (SUFBUFLEN-1) /*  Mask to get offset into suffix buffer */
#define  KEYSPACE        32   /*  Average bytes per key, including '\0'  */
#define  MAXERROR         5   /*  Number of bad residues to report  */
#define  N_BAR_OK         4   /*  Number of vertical bars allowed in an id */

#define  BUFLEN   (128*1024)  /*  Read buffer length for translation files */
#define  INPLEN   (  4*1024)  /*  Buffer length for translation_file_list  */

/*
 *  Some structures:
 */

/*  From simplehash.h  */

typedef struct {
    size_t     size;
    unsigned   (* fnc)(void * key);
    int        (* cmp)(void * key1, void * key2);
    void    ** hash;
} hashdata;

/*  From cksum.h  */

typedef struct { unsigned  crc; unsigned  len; } cksum_t;

/*  Stuctures for this program:  */

typedef struct
{
    char      *key;       /* pointer to the key */
    long long  seqseek;   /* file seek to first residue of sequence */
    int        seqbytes;  /* total bytes spanned by the sequence residues */
    int        slen;      /* sequence length w/o white space */
    int        cksum;     /* cksum of uppercase sequence (coerced to int) */
    int        sufcksum;  /* cksum of last suffix_len residues of sequence */
} indexdata;


typedef struct
{
    int         nkey;
    int         maxkey;
    int         maxkeylen;
    int         suffixlen;
    size_t      keyspace; /* size of text area (32 * maxkey) */
    char       *keys;     /* text storage area */
    char       *nxtkey;   /* pointer to next free byte */
    indexdata  *data;     /* array to data storage structures */
    hashdata   *hash;
} globaldata;


/*
 *  Function prototypes:
 */

/*  From simplehash.h  */

hashdata * newhash( size_t maxkeys,
                    unsigned (* fnc)( void * key ),
                    int (* cmp)( void * key1, void * key2 )
                  );
void       clearhash( hashdata * hd );
void     * add2hash( hashdata * hd, void * key );
void       freehash( hashdata * hd );

/*  From cksum.h  */

cksum_t  *new_cksum( void );
cksum_t  *add2cksum( cksum_t * cksum, char * str );
cksum_t  *add_uc2cksum( cksum_t * cksum, char * str );
cksum_t  *add_lc2cksum( cksum_t * cksum, char * str );
unsigned  finish_cksum( cksum_t * cksum );
void      free_cksum( cksum_t * cksum );
unsigned  str_cksum( char * str );

/*  Prototypes for this program:  */

globaldata  *initialize( int maxids, int maxidlen, int suffixlen );

globaldata  *reset( globaldata *gd );

unsigned  my_hash_value( void *datum );

unsigned  str_cksum( char * str );

int  my_cmp_func( void *datum1, void *datum2 );

int index_a_file ( int inpfd, char *prefix, globaldata *gd, char *prog );

void  record_info( indexdata *datum, long long seek, int bytes,
                   int slen, unsigned crc, char *suffix, int suflen
                 );

int  report_info( globaldata *gd, int filenum, FILE * fp );

void  usage( char *prog );


/*  CRC table is from cksum.h  */

static unsigned crctab[] = {
0x00000000,
0x04c11db7, 0x09823b6e, 0x0d4326d9, 0x130476dc, 0x17c56b6b,
0x1a864db2, 0x1e475005, 0x2608edb8, 0x22c9f00f, 0x2f8ad6d6,
0x2b4bcb61, 0x350c9b64, 0x31cd86d3, 0x3c8ea00a, 0x384fbdbd,
0x4c11db70, 0x48d0c6c7, 0x4593e01e, 0x4152fda9, 0x5f15adac,
0x5bd4b01b, 0x569796c2, 0x52568b75, 0x6a1936c8, 0x6ed82b7f,
0x639b0da6, 0x675a1011, 0x791d4014, 0x7ddc5da3, 0x709f7b7a,
0x745e66cd, 0x9823b6e0, 0x9ce2ab57, 0x91a18d8e, 0x95609039,
0x8b27c03c, 0x8fe6dd8b, 0x82a5fb52, 0x8664e6e5, 0xbe2b5b58,
0xbaea46ef, 0xb7a96036, 0xb3687d81, 0xad2f2d84, 0xa9ee3033,
0xa4ad16ea, 0xa06c0b5d, 0xd4326d90, 0xd0f37027, 0xddb056fe,
0xd9714b49, 0xc7361b4c, 0xc3f706fb, 0xceb42022, 0xca753d95,
0xf23a8028, 0xf6fb9d9f, 0xfbb8bb46, 0xff79a6f1, 0xe13ef6f4,
0xe5ffeb43, 0xe8bccd9a, 0xec7dd02d, 0x34867077, 0x30476dc0,
0x3d044b19, 0x39c556ae, 0x278206ab, 0x23431b1c, 0x2e003dc5,
0x2ac12072, 0x128e9dcf, 0x164f8078, 0x1b0ca6a1, 0x1fcdbb16,
0x018aeb13, 0x054bf6a4, 0x0808d07d, 0x0cc9cdca, 0x7897ab07,
0x7c56b6b0, 0x71159069, 0x75d48dde, 0x6b93dddb, 0x6f52c06c,
0x6211e6b5, 0x66d0fb02, 0x5e9f46bf, 0x5a5e5b08, 0x571d7dd1,
0x53dc6066, 0x4d9b3063, 0x495a2dd4, 0x44190b0d, 0x40d816ba,
0xaca5c697, 0xa864db20, 0xa527fdf9, 0xa1e6e04e, 0xbfa1b04b,
0xbb60adfc, 0xb6238b25, 0xb2e29692, 0x8aad2b2f, 0x8e6c3698,
0x832f1041, 0x87ee0df6, 0x99a95df3, 0x9d684044, 0x902b669d,
0x94ea7b2a, 0xe0b41de7, 0xe4750050, 0xe9362689, 0xedf73b3e,
0xf3b06b3b, 0xf771768c, 0xfa325055, 0xfef34de2, 0xc6bcf05f,
0xc27dede8, 0xcf3ecb31, 0xcbffd686, 0xd5b88683, 0xd1799b34,
0xdc3abded, 0xd8fba05a, 0x690ce0ee, 0x6dcdfd59, 0x608edb80,
0x644fc637, 0x7a089632, 0x7ec98b85, 0x738aad5c, 0x774bb0eb,
0x4f040d56, 0x4bc510e1, 0x46863638, 0x42472b8f, 0x5c007b8a,
0x58c1663d, 0x558240e4, 0x51435d53, 0x251d3b9e, 0x21dc2629,
0x2c9f00f0, 0x285e1d47, 0x36194d42, 0x32d850f5, 0x3f9b762c,
0x3b5a6b9b, 0x0315d626, 0x07d4cb91, 0x0a97ed48, 0x0e56f0ff,
0x1011a0fa, 0x14d0bd4d, 0x19939b94, 0x1d528623, 0xf12f560e,
0xf5ee4bb9, 0xf8ad6d60, 0xfc6c70d7, 0xe22b20d2, 0xe6ea3d65,
0xeba91bbc, 0xef68060b, 0xd727bbb6, 0xd3e6a601, 0xdea580d8,
0xda649d6f, 0xc423cd6a, 0xc0e2d0dd, 0xcda1f604, 0xc960ebb3,
0xbd3e8d7e, 0xb9ff90c9, 0xb4bcb610, 0xb07daba7, 0xae3afba2,
0xaafbe615, 0xa7b8c0cc, 0xa379dd7b, 0x9b3660c6, 0x9ff77d71,
0x92b45ba8, 0x9675461f, 0x8832161a, 0x8cf30bad, 0x81b02d74,
0x857130c3, 0x5d8a9099, 0x594b8d2e, 0x5408abf7, 0x50c9b640,
0x4e8ee645, 0x4a4ffbf2, 0x470cdd2b, 0x43cdc09c, 0x7b827d21,
0x7f436096, 0x7200464f, 0x76c15bf8, 0x68860bfd, 0x6c47164a,
0x61043093, 0x65c52d24, 0x119b4be9, 0x155a565e, 0x18197087,
0x1cd86d30, 0x029f3d35, 0x065e2082, 0x0b1d065b, 0x0fdc1bec,
0x3793a651, 0x3352bbe6, 0x3e119d3f, 0x3ad08088, 0x2497d08d,
0x2056cd3a, 0x2d15ebe3, 0x29d4f654, 0xc5a92679, 0xc1683bce,
0xcc2b1d17, 0xc8ea00a0, 0xd6ad50a5, 0xd26c4d12, 0xdf2f6bcb,
0xdbee767c, 0xe3a1cbc1, 0xe760d676, 0xea23f0af, 0xeee2ed18,
0xf0a5bd1d, 0xf464a0aa, 0xf9278673, 0xfde69bc4, 0x89b8fd09,
0x8d79e0be, 0x803ac667, 0x84fbdbd0, 0x9abc8bd5, 0x9e7d9662,
0x933eb0bb, 0x97ffad0c, 0xafb010b1, 0xab710d06, 0xa6322bdf,
0xa2f33668, 0xbcb4666d, 0xb8757bda, 0xb5365d03, 0xb1f740b4
};

/*
 *  This table does not include * as an amino acid.  We would get fewer error
 *  messages it we were to do so.  The table has [A-IK-NP-Za-ik-np-z].
 *
 *  2008-08-17 -- Made J a valid amino acid (GJO)
 */

static int
is_aa[256] =
{
 /* 0  1  2  3  4  5  6  7  8  9  a  b  e  d  e  f        */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  /* 0 */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  /* 1 */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  /* 2 */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  /* 3 */
    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,  /* 4 */
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0,  /* 5 */
    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,  /* 6 */
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0,  /* 7 */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  /* 8 */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  /* 9 */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  /* a */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  /* b */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  /* c */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  /* d */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  /* e */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0   /* f */
};


/*
 *  Do our own ASCII case conversion to avoid overhead of localization:
 */

static int
uc[256] = {
 /* 0    1    2    3    4    5    6    7    8    9    a    b    e    d    e    f        */
    0,   1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,  15,  /* 0 */
   16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,  27,  28,  29,  30,  31,  /* 1 */
   32,  33,  34,  35,  36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,  /* 2 */
   48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,  59,  60,  61,  62,  63,  /* 3 */
   64,  65,  66,  67,  68,  69,  70,  71,  72,  73,  74,  75,  76,  77,  78,  79,  /* 4 */
   80,  81,  82,  83,  84,  85,  86,  87,  88,  89,  90,  91,  92,  93,  94,  95,  /* 5 */
   96,  65,  66,  67,  68,  69,  70,  71,  72,  73,  74,  75,  76,  77,  78,  79,  /* 4 */
   80,  81,  82,  83,  84,  85,  86,  87,  88,  89,  90, 123, 124, 125, 126, 127,  /* 7 */
  128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143,  /* 8 */
  144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159,  /* 9 */
  160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175,  /* a */
  176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191,  /* b */
  192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207,  /* c */
  208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223,  /* d */
  224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239,  /* e */
  240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255   /* f */
};


/*============================================================================
 *  At last, the program:
 *
 *  main
 *==========================================================================*/

int main ( int argc, char **argv )
{
    char        inpbuf[ INPLEN ];  /* read buffer for files to be processed */
    char       *bptr, *prefix, *filename;
    globaldata *gd;
    int         maxids, maxidlen, suflen;
    int         filenum, inpfd;
    int         c, nf, indexed;


    /*
     *  -v flag returns version
     */

    if ( ( argc == 2 ) && ( strcmp( argv[1], "-v" ) == 0 ) )
    {
	printf( "%s\n", VERSION );
	return 0;
    }

    /*
     *  Otherwise read max_ids and max_id_len:
     */

    if ( ( argc < 3 ) || ( ( maxids   = atoi( argv[1] ) ) < 1 )
                      || ( ( maxidlen = atoi( argv[2] ) ) < 1 )
       ) usage( argv[0] );

    /*
     *  Read suffix_len, or set it to default (64):
     */

    if ( ( argc > 3 ) && ( ( suflen   = atoi( argv[3] ) ) > 0 ) ) ;
    else                     suflen   = SUFFIXLEN;

    /*
     *  Get memmory and hash
     */

    #ifdef DEBUG
	fprintf( stderr, "maxids = %d, maxidlen = %d, suflen = %d\n",
	         maxids, maxidlen, suflen );
    #endif

    gd = initialize( maxids, maxidlen, suflen );
    if ( ! gd )
    {
	fprintf( stderr, "Failed to initialize memory and/or hash\n" );
	return 1;
    }

    /*
     *  Read the list of files to be processed from stdin
     */

    indexed = nf = 0;
    while ( fgets( inpbuf, INPLEN,  stdin ) )
    {
	/*
	 *  Break the line read into null terminated fields:
	 *
	 *  First, find the end of the file number
	 */

	bptr = inpbuf;
	while ( ( c = *bptr ) && ( c >= ' ' ) ) bptr++;
	if ( ! c ) continue;       /* another field is required */
	*bptr++ = '\0';            /* convert terminator to end-of-string */
	filenum = atoi( inpbuf );  /* convert the number */

	/*
	 *  Find the end of the file name
	 */

	filename = bptr;
	while ( ( c = *bptr ) && ( c >= ' ' ) ) bptr++;
	*bptr++ = '\0';           /* convert terminator to end-of-string */

	/*
	 *  If one is present, find the end of the ID prefix (otherwise leave
	 *  a valid pointer to a zero-length string).
	 */

	prefix = bptr;
	if ( c ) { while ( ( c = *bptr ) && ( c >= ' ' ) ) bptr++; }
	*bptr++ = '\0';           /* convert terminator to end-of-string */

	#ifdef DEBUG
	    fprintf( stderr, "filenum = %d, filename = %s, prefix = %s\n",
	             filenum, filename, prefix
	           );
	#endif

	/*
	 *  Open the file and pass the descriptor number to the indexing subroutine
	 */

	if ( ( inpfd = open( filename, O_RDONLY, 0 ) ) < 0 )
	{
	    fprintf( stderr,
	             "ERROR: Failed to open translations file: %s\n",
	             filename
	           );
	    continue;
	}
	(void) index_a_file( inpfd, prefix, gd, argv[0] );
	(void) close( inpfd );
	indexed += report_info( gd, filenum, stdout );
	nf++;
    }

    fprintf( stderr, "%s indexed %d sequences in %d files\n\n",
                     argv[0], indexed, nf
           );

    return 0;
}  /* main */


/*============================================================================
 *  initialize
 *==========================================================================*/

globaldata * initialize( int maxids, int maxidlen, int suffixlen )
{
    globaldata *gd;

    if ( ! maxids || ! maxidlen ) return (globaldata *) 0;

    if ( ! ( gd  = (globaldata *) malloc( sizeof( globaldata ) ) ) )
    {
	return (globaldata *) 0;
    }

    gd->nkey       = 0;
    gd->maxkey     = maxids;
    gd->maxkeylen  = maxidlen;
    gd->suffixlen  = suffixlen;

    /*
     *  There might be merit in allocating space by max key len,
     *  but that could get huge.  Another alternative would be
     *  to make the average length a command line arg.
     */

    gd->keyspace = KEYSPACE * maxids;
    gd->keys = (char *) malloc( sizeof( char ) * gd->keyspace );
    if ( ! gd->keys )
    {
	free( gd );
	return (globaldata *) 0;
    }
    gd->nxtkey = gd->keys;

    gd->data = (indexdata *) malloc( sizeof( indexdata ) * maxids );
    if ( ! gd->data )
    {
	free( gd->keys );
	free( gd );
	return (globaldata *) 0;
    }

    gd->hash = newhash( maxids,
	                (unsigned (*)(void *) )my_hash_value,
	                (int (*)(void *, void *))my_cmp_func
	              );
    if ( ! gd->hash )
    {
	free( gd->data );
	free( gd->keys );
	free( gd );
	return (globaldata *) 0;
    }

    return gd;
}  /* initialize */


/*============================================================================
 *  reset
 *==========================================================================*/

globaldata *reset( globaldata *gd )
{
    gd->nkey   = 0;
    gd->nxtkey = gd->keys;
    clearhash( gd->hash );
    return gd;
}  /* reset */


/*============================================================================
 *  my_hash_value
 *==========================================================================*/

unsigned my_hash_value( void *datum )
{
    return str_cksum( ((indexdata *)datum)->key );
}  /* my_hash_value */


/*============================================================================
 *  my_cmp_func
 *==========================================================================*/

int my_cmp_func( void *datum1, void *datum2 )
{
    return strcmp( ((indexdata *)datum1)->key, ((indexdata *)datum2)->key );
}  /* my_cmp_func */



/*============================================================================
 *  These 2 chunks of code are repeated, and they clutter the flow of the
 *  subroutine below.  They have been brought out as macros with many required
 *  side effects.  Most of the arguments MUST be simple variables.  They are
 *  functionally very similar, but the first does not record a sequence
 *  before returning to the caller.  The second tries to record the current
 *  sequence, then returns.  These macros are the only normal return points
 *  from the subroutine (yes I know just how ugly that is).  They are invoked
 *  for every character fetch.  If a buffer fill fails (most likely due to
 *  EOF), they return.  (They could be written as macro functions, but that
 *  would even be uglier.)
 *============================================================================
 *
 *  GET_CHAR_OR_RETURN( c, bptr, bufend, buffer, BUFLEN, inpfd, nfill )
 *
 *  GET_CHAR_OR_RECORD( c, bptr, bufend, buffer, BUFLEN, inpfd, nfill,
 *                      haveid, slen, seek0, crc, suffix, suflen, datum
 *                    )
 *==========================================================================*/

#define GET_CHAR_OR_RETURN(c, ptr, end, buf, blen, fd, nf)            \
    if ( ptr >= end )                                                 \
    {                                                                 \
	if ( ( end = buf + read(fd, buf, blen) ) <= buf ) return 0;   \
	nf++; ptr = buf;                                              \
    }                                                                 \
    c = *ptr++;


#define GET_CHAR_OR_RECORD(c, ptr, end, buf, blen, fd, nf, id, slen, s0, crc, suf, suflen, datum)  \
    if ( ptr >= end )                                                 \
    {                                                                 \
        if ( ( end = buf + read(fd, buf, blen) ) <= buf )             \
	{   long long seek;                                           \
	    if ( ! id ) return 0;                                     \
	    seek = (nf-1) * (long long)blen + (ptr-buf);              \
	    record_info( datum, s0, (int)(seek-s0),                   \
	                 slen, crc, suf, suflen );                    \
	    return 0;                                                 \
	}                                                             \
	nf++; ptr = buf;                                              \
    }                                                                 \
    c = *ptr++;


/*============================================================================
 *  index_a_file
 *==========================================================================*/

int index_a_file ( int inpfd, char *prefix, globaldata *gd, char *prog )
{
    int         nkey, maxkey, maxkeylen, suflen;
    hashdata   *hash;
    indexdata  *data, *datum, *hashdatum;
    char       *keys, *nxtkey, *endkeys;
    int         preflen;
    char       *key, *keyptr, *keyerr;
    char        buffer[ BUFLEN ];         /* read buffer   */
    char       *bptr, *bufend;
    char        suffix[ SUFBUFLEN ];      /* sequence suffix buffer */
    long long   seek, seek0;
    int         nfill;
    int         haveid, bars, slen, nerror;
    int         c;
    unsigned    crc;

    /*
     *  If there were previous files, reset the data structures:
     */

    if ( gd->nkey ) reset( gd );

    /*
     *  Initialize for this file:
     */

    nkey      = gd->nkey;
    maxkey    = gd->maxkey;
    maxkeylen = gd->maxkeylen;
    suflen    = gd->suffixlen;
    hash      = gd->hash;
    data      = gd->data;
    keys      = gd->keys;
    nxtkey    = gd->nxtkey;
    endkeys   = keys + gd->keyspace - 1;  /* keep space for '\0' */

    bptr      = buffer;  /* current read position in read buffer */
    bufend    = buffer;  /* one past end of valid buffer data */
    nfill     = 0;       /* track seek by number of buffer fills */
    slen      = 0;       /* non-white sequence characters */
    nerror    = 0;       /* number of reported bad characters in sequence */
    seek0     = 0;       /* beginning of current sequence entry */
    crc       = 0;
    haveid    = 0;       /* we need state info on valid id */

    key       = keys;    /* just to make compiler -Wall happy */
    datum     = data;    /* just to make compiler -Wall happy */
    datum->slen = 0;     /* ditto */

    /*
     *  Measure the length of the required id prefix:
     */

    preflen = 0;
    if ( prefix )
    {
	char *prefptr;
	prefptr = prefix;
	while ( *prefptr++ ) preflen++;
    }

    /*
     *  Process the file line-by-line
     */

    while ( 1 )
    {
	/*
	 *  Failure to get a character here is the normal termination
	 *  (end-of-file after a newline).
	 */

	GET_CHAR_OR_RECORD( c, bptr, bufend, buffer, BUFLEN, inpfd, nfill,
	                    haveid, slen, seek0, crc, suffix, suflen, datum
	                  );

	/*
	 *  Got a character.  Is this an identifier line or sequence data?
	 */

	if ( c == '>' )
	{
	    /*
	     *  New identifier line.  Is there a previous sequence to record?
	     */

	    if ( haveid )
	    {   /*  In the seek calculation, the -1 is for the > just read  */
		seek = ( nfill-1 ) * (long long)BUFLEN + ( bptr-buffer ) - 1;
		record_info( datum, seek0, (int)(seek-seek0),
		             slen, crc, suffix, suflen );
	    }

	    /*
	     *  Flush white space up to id (should not be any, but...)
	     */

	    GET_CHAR_OR_RETURN(c, bptr, bufend, buffer, BUFLEN, inpfd, nfill);

	    while ( ( c <= ' ') && ( c != '\n' ) && c )
	    {
		GET_CHAR_OR_RETURN(c, bptr, bufend, buffer, BUFLEN, inpfd, nfill);
	    }

	    /*
	     *  Is there space for another entry?
	     */

	    if ( nkey >= maxkey )
	    {
		fprintf( stderr, "ERROR: Maximum number of ids (%d) reached.\n", maxkey );
		if ( nkey < 1 ) exit(3);      /*  Severe error  */
		datum = data + nkey - 1;      /*  Last added key  */
		fprintf( stderr, "   Last entry processed was:\n   %s\n", datum->key );
		exit(3);
	    }

	    /*
	     *  Read the id and find out if it is new.  Only if it is new will
	     *  the values of nkey and nxtkey be increased.  If it is reusing
	     *  an old key, the data structure pointer will be moved to the old
	     *  copy found by add2hash.
	     */

	    keyptr = key = nxtkey;     /* pointer to next free key */
	    keyerr = key + maxkeylen;  /* if keyptr reaches here, key is long */
	    if ( keyerr > endkeys ) keyerr = endkeys;  /* end of buffer */
	    bars = N_BAR_OK;           /* number of | allowed in id  */

	    while ( c > ' ' )          /*  poorman's "is not space" */
	    {
		if ( keyptr >= keyerr )
		{
		    /*
		     *  Sequence ID is too long.
		     */

		    if ( keyptr >= endkeys )
		    {
			fprintf( stderr,
			         "ERROR: Program ran out of space for keys.  Increase the value of KEYPSPACE\n"
			         "       (currently %d), or use a larger value of max_ids (curently %d).\n",
			         KEYSPACE, gd->maxkey
			       );
			if ( nkey < 1 ) exit(2);     /*  Severe error  */
			datum = data + nkey - 1;     /*  Last added datum  */
			fprintf( stderr, "   Last entry processed was:  %s\n",
			                     datum->key
			       );
			exit(2);
		    }
		    else
		    {
			*keyptr = '\0';
			fprintf( stderr,
			         "WARNING: Truncating id to %d characters: %s\n",
			         maxkeylen, key
			       );
		    }
		    break;
		}

		/*
		 *  Following the perl, break id at second vertical bar
		 */

		if ( ( c == '|' ) && ( bars-- <= 0 ) ) break;

		/*
		 *  So much for testing.  Save the character and get another.
		 */

		*keyptr++ = c;
		GET_CHAR_OR_RETURN(c, bptr, bufend, buffer, BUFLEN, inpfd, nfill);
	    }

	    /*
	     *  Terminate the key and flush the rest of the input line.
	     */

	    *keyptr++ = '\0';

	    while ( ( c != '\n' ) && c )
	    {
		GET_CHAR_OR_RETURN(c, bptr, bufend, buffer, BUFLEN, inpfd, nfill);
	    }

	    /*
	     *  Is the ID valid?  Is it non-null?  Does it match the prefix?
	     *  If not, set haveid to zero and go to next line.
	     */

	    if ( ! *key )
	    {
		fprintf( stderr, "WARNING:  Null sequence identifier skipped.\n" );
		if ( nkey > 0 )
		{
		    datum = data + nkey - 1;     /*  Last added datum  */
		    fprintf( stderr, "   Previous entry was:  %s\n", datum->key );
		}
		haveid = 0;
		continue;
	    }
	    else if ( preflen && strncmp( key, prefix, preflen ) )
	    {
		fprintf( stderr,
		         "WARNING:  Skipping sequence id \"%s\", \n"
		         "          which does not match prefix \"%s\".\n",
		         key, prefix
		       );
		haveid = 0;
		continue;
	    }
	    haveid = 1;

	    /*
	     *  Key is okay.  Link it into the next available indexdata struct.
	     *  Add it to the hash (or get a pointer to the preexisting copy).
	     */

	    datum = data + nkey;
	    datum->key = key;

	    hashdatum = (indexdata *) add2hash( hash, (void *) datum );
	    if ( hashdatum == datum )
	    {                          /*  New key:  */
		gd->nkey   = ++nkey;   /*     reserve the indexdata struct */
		gd->nxtkey = nxtkey = keyptr; /* reserve the key text area */
		datum->slen = 0;      /*     mark as having no valid data yet */
		#if DEBUG > 1
		    fprintf( stderr, "New key (%d) = %s\n", nkey, key );
		#endif
	    }
	    else
	    {                         /*  Key was already present:  */
		datum = hashdatum;    /*  use the existing indexdata struct */
		#if DEBUG > 1
		    fprintf( stderr, "Repeat key (%d) = %s\n", (int)(datum-data+1), key );
		#endif
	    }

	    /*
	     *  bptr is at start of sequence data; move seek0 to coincide.
	     *  Reset other important values.
	     */

	    seek0  = ( nfill - 1 ) * (long long)BUFLEN + ( bptr - buffer );
	    slen   = 0;
	    crc    = 0;
	    nerror = 0;
	}

	/*
	 *  Wow!  That was all for an id line.  If we have a valid sequence id,
	 *  here's what we do with a data line.
	 */

	else if ( haveid )
	{
	    while ( ( c != '\n' ) && c )
	    {
		/*
		 *  Is it a valid amino acid character?  If so, record it.
		 */

		if ( is_aa[ c ] )
		{
		    c = uc[ c ];      /* cksums are based on uppercase char */
		    crc = ( crc << 8 ) ^ crctab[ ( crc >> 24 ) ^ ( c & 0xFF ) ];
		    suffix[ slen & SUFBUFMSK ] = c;  /* last SUFBUFLEN chars */
		    slen++;
		}

		/*
		 *  If not an amino acid, it should be white space, but ...
		 */

		else if ( c > ' ' && c != '*' )
		{
		    /*
		     *  ... the perl code counts all nonwhite chars as amino acids,
		     *  so we will too.  But, let's add error messages ...
		     */

		    if ( ++nerror < MAXERROR )
		    {
			fprintf( stderr,
			         "Invalid amino acid (%c) in translation %s\n",
			         c, key
			       );
		    }
		    else if ( nerror == MAXERROR )
		    {
			fprintf( stderr, "Etc.\n" );
		    }

		    /*
		     *  ... before we record the residues in slen and the crcs.
		     */

		    slen++;
		    c = uc[ c ];      /* cksums are based on uppercase char */
		    crc = ( crc << 8 ) ^ crctab[ ( crc >> 24 ) ^ ( c & 0xFF ) ];
		    suffix[ slen & SUFBUFMSK ] = c;  /* last SUFBUFLEN chars */
		    slen++;
		}

		GET_CHAR_OR_RECORD( c, bptr, bufend, buffer, BUFLEN, inpfd, nfill,
		                    haveid, slen, seek0, crc, suffix, suflen, datum
		                  );
	    }
	}

	/*
	 *  If we do not have an id, we should still flush the line
	 */

	else
	{
	    while ( ( c != '\n' ) && c )
	    {
		GET_CHAR_OR_RETURN(c, bptr, bufend, buffer, BUFLEN, inpfd, nfill);
	    }
	}
    }

    /*
     *  Never get here due to while (1) {...}.  However -Wall is not that smart.
     */

    return( 0 );
}  /* index_a_file */


/*============================================================================
 *  record_info
 *
 *  Record the data for the new sequence in the indexdata struct.  We cannot
 *  print it yet, since it might get replaced by a later version.
 *==========================================================================*/

void record_info( indexdata *datum, long long seek, int bytes,
                  int slen, unsigned crc, char *suffix, int suflen
                )
{
    char  sufbuf[ SUFBUFLEN+1 ], *sufptr;
    int   i0, i;

    if ( ! datum || ! datum->key || ! *(datum->key) || ! suffix ) return;
    if ( slen < MINLEN )
    {
	#if SHOWSHORT
	    fprintf( stderr, "Skipping %d residue sequence %s\n",
	                     slen, datum->key
	           );
	#endif
	return;
    }

    /*
     *  datum->slen is zero if there are no data, otherwise we are replacing
     *  a previous value.  Message only come up if both new and old data were
     *  valid.  This means that nkey is not count of valid data!
     */

    #if SHOWDUPS
	if ( datum->slen )
	{
	    // fprintf( stderr, "Duplicate id replacing old data: %s\n", datum->key );
	}
    #endif

    datum->seqseek  = seek;
    datum->seqbytes = bytes;
    datum->slen     = slen;

    /*
     *  Finish the cksum calculation.
     */

    {
	unsigned len = slen;
	while ( len != 0 )
	{
	    crc = ( crc << 8 ) ^ crctab[ ( crc >> 24 ) ^ ( len & 0xFF ) ];
	    len >>= 8;
	}
    }
    datum->cksum = (int) (~crc);

    /*
     *  All of the bytes of the sequence were written into suffix.  The last
     *  SUFBUFLEN bytes have not been overwritten, but are circularly permuted.
     *  They are unpermuted by being copied into sufbuf, a null is added at
     *  the end, and this provides the basis of the suffix cksum.
     */

    sufptr = sufbuf;
    i0 = ( slen <= suflen ) ? 0 : ( slen - suflen );
    for ( i = i0; i < slen; i++ ) *sufptr++ = suffix[ i & SUFBUFMSK ];
    *sufptr++ = '\0';

    datum->sufcksum = (int) str_cksum( sufbuf );

    return;
}  /* record_info */


/*============================================================================
 *  report_info
 *
 *  SeqId \t FileNum \t StartSeek \t DataBytes \t SeqLen \t Cksum \t SuffixCk
 *==========================================================================*/

int report_info( globaldata *gd, int filenum, FILE * fp )
{
    indexdata *datum;
    int        i, n;

    if ( ! gd || ! gd->nkey ) return 0;

    n = 0;
    for ( i = 0; i < gd->nkey; i++ ) {
	datum = gd->data + i;
	if ( ! datum->slen ) continue;
	fprintf( fp, "%s\t%d\t%lld\t%d\t%d\t%d\t%d\n",
	             datum->key, filenum, datum->seqseek, datum->seqbytes,
	             datum->slen, datum->cksum, datum->sufcksum
	       );
	n++;
    }

    return n;
}  /* report_info */


/*============================================================================
 *  usage
 *==========================================================================*/

void usage( char *prog )
{
    fprintf( stderr,
             "\n"
             "Usage: %s  max_ids  max_id_len  [cksum_suffix_len (D=64)] \\\n"
             "               < file_list > seek_size_and_cksum_info\n"
             "or     %s -v  > version_number\n"
             "\n",
             prog, prog
           );
    exit(0);
}  /* usage */


/*============================================================================
 *========================  Source code from cksum.c  ========================
 *==========================================================================*/

static unsigned uc_tbl[256] = {
/*  0    1    2    3    4    5    6    7    8    9    a    b    e    d    e    f        */
    0,   1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,  15,  /* 0 */
   16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,  27,  28,  29,  30,  31,  /* 1 */
   32,  33,  34,  35,  36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,  /* 2 */
   48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,  59,  60,  61,  62,  63,  /* 3 */
   64,  65,  66,  67,  68,  69,  70,  71,  72,  73,  74,  75,  76,  77,  78,  79,  /* 4 */
   80,  81,  82,  83,  84,  85,  86,  87,  88,  89,  90,  91,  92,  93,  94,  95,  /* 5 */
   96,  65,  66,  67,  68,  69,  70,  71,  72,  73,  74,  75,  76,  77,  78,  79,  /* 4 */
   80,  81,  82,  83,  84,  85,  86,  87,  88,  89,  90, 123, 124, 125, 126, 127,  /* 7 */
  128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143,  /* 8 */
  144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159,  /* 9 */
  160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175,  /* a */
  176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191,  /* b */
  192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207,  /* c */
  208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223,  /* d */
  224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239,  /* e */
  240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255   /* f */
};

static unsigned lc_tbl[256] = {
/*  0    1    2    3    4    5    6    7    8    9    a    b    e    d    e    f        */
    0,   1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,  15,  /* 0 */
   16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,  27,  28,  29,  30,  31,  /* 1 */
   32,  33,  34,  35,  36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,  /* 2 */
   48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,  59,  60,  61,  62,  63,  /* 3 */
   64,  97,  98,  99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111,  /* 6 */
  112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122,  91,  92,  93,  94,  95,  /* 5 */
   96,  97,  98,  99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111,  /* 6 */
  112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127,  /* 7 */
  128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143,  /* 8 */
  144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159,  /* 9 */
  160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175,  /* a */
  176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191,  /* b */
  192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207,  /* c */
  208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223,  /* d */
  224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239,  /* e */
  240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255   /* f */
};

#define  ascii_uc( x )  uc_tbl[ (int)( x ) & 0xFF ]
#define  ascii_lc( x )  lc_tbl[ (int)( x ) & 0xFF ]


cksum_t * new_cksum( void ) {
    cksum_t * cksum;

    cksum = (cksum_t *) malloc( sizeof( cksum_t ) );
    if ( cksum ) { cksum->crc = cksum->len = 0; }
    return cksum;
}


cksum_t * add2cksum( cksum_t * cksum, char * str ) {
    if ( cksum && str ) {
        unsigned  crc, chr;
        char    * str0;

        crc = cksum->crc;
        str0 = str;

        while ( ( chr = *(char *)str++ ) ) {
            crc = ( crc << 8 ) ^ crctab[ ( crc >> 24 ) ^ ( chr & 0xFF ) ];
        }

        cksum->crc  = crc;
        cksum->len += str - str0;
    }

    return cksum;
}


cksum_t * add_uc2cksum( cksum_t * cksum, char * str ) {
    if ( cksum && str ) {
        unsigned  crc, chr;
        char    * str0;

        crc = cksum->crc;
        str0 = str;

        while ( ( chr = *(char *)str++ ) ) {
            crc = ( crc << 8 ) ^ crctab[ ( crc >> 24 ) ^ ascii_uc( chr ) ];
        }

        cksum->crc  = crc;
        cksum->len += str - str0;
    }

    return cksum;
}


cksum_t * add_lc2cksum( cksum_t * cksum, char * str ) {
    if ( cksum && str ) {
        unsigned  crc, chr;
        char    * str0;

        crc = cksum->crc;
        str0 = str;

        while ( ( chr = *(char *)str++ ) ) {
            crc = ( crc << 8 ) ^ crctab[ ( crc >> 24 ) ^ ascii_lc( chr ) ];
        }

        cksum->crc  = crc;
        cksum->len += str - str0;
    }

    return cksum;
}


unsigned finish_cksum( cksum_t * cksum ) {
    unsigned  len, crc;

    if ( ! cksum ) return (unsigned) 0;

    crc = cksum->crc;
    len = cksum->len;

    while ( len != 0 ) {
        crc = ( crc << 8 ) ^ crctab[ ( crc >> 24 ) ^ ( len & 0xFF ) ];
        len >>= 8;
    }

    free( cksum );
    return ~crc;
}


void free_cksum( cksum_t * cksum ) {
    if ( cksum ) { free( cksum ); }
    return;
}


unsigned str_cksum( char * str ) {
    unsigned  len, crc, chr;
    char     *str0;

    if ( ! str ) return (unsigned) 0;

    crc = 0;
    str0 = str;
    while ( ( chr = *str++ ) ) {
        crc = ( crc << 8 ) ^ crctab[ ( crc >> 24 ) ^ ( chr & 0xFF ) ];
    }

    len = str - str0 - 1;
    while ( len != 0 ) {
        crc = ( crc << 8 ) ^ crctab[ ( crc >> 24 ) ^ ( len & 0xFF ) ];
        len >>= 8;
    }

    return ~crc;
}


/*============================================================================
 *=====================  Source code from simplehash.c  ======================
 *==========================================================================*/

hashdata * newhash( size_t maxkeys,
                    unsigned (* fnc)( void * key ),
                    int (* cmp)( void * key1, void * key2 )
                  ) {
    hashdata * hd;

    if ( ! maxkeys || ! cmp ) return (hashdata *) 0;
    hd = (hashdata *) malloc( sizeof( hashdata ) );
    if ( ! hd ) return (hashdata *) 0;
    hd->size = ( 5 * maxkeys ) / 4;
    hd->hash = (void **) malloc( sizeof( void * ) * hd->size );
    if ( ! hd->hash ) {
        free( hd );
        return (hashdata *) 0;
    }
    hd->fnc = fnc;
    hd->cmp = cmp;
    (void) clearhash( hd );
    return hd;
}


void clearhash( hashdata * hd ) {
    int    i;
    void **hp;

    if ( ! hd || ! hd->hash ) return;
    hp = hd->hash;
    for ( i = 0; i < hd->size; i++ ) *hp++ = (void *) 0;
    return;
}


/*  add2hash:  adds a key pointer to the hash, returning the pointer it
 *        or:  returns the pointer to the equal key already in the hash
 *
 *  If the keys are in a list with keyspace bytes per key, then the index is
 *
 *     ( key - keys ) / keyspace
 *
 *  A bit ugly, but the hash need not know about the structure of the data.
 *  (If the key is the first element of a structure, then the pointer is also
 *  a pointer to the structure.  But unless the size of the structures are
 *  known at compile time, this is also ugly.)
 *
 *  Note that in the seed, most keys will only occur once, so the emphasis
 *  should be on efficiently adding new entries.
 */

void * add2hash( hashdata * hd, void * key ) {
    int        i, i0;
    size_t     size;
    void    ** hp;
    unsigned   (* fnc)( void * );
    int        (* cmp)( void *, void * );

    if ( ! hd || ! hd->hash
              || ! ( size = hd->size )
              || ! ( fnc  = hd->fnc )
              || ! ( cmp  = hd->cmp )
       ) {
        fprintf( stderr, "Error: add2hash called with null hash\n");
        exit( 1 );
    }
    if ( ! key ) {
        fprintf( stderr, "Error: add2hash called with null key\n");
        exit( 1 );
    }

    i = i0 = fnc( key ) % size;
    hp = hd->hash + i;
    while (1) {
        if      ( ! *hp )             { *hp = key; break; }  /* empty slot */
        else if ( ! cmp( *hp, key ) ) {            break; }  /* matching key */

        if ( ++i >= hd->size ) { hp = hd->hash; i = 0; }  /* wrap back to zero */
        else                   { hp++;                 }  /* simple increment */

        if ( i == i0 ) {                  /* ouch; full circuit is a full table */
            fprintf( stderr, "Table overflow in add2hash (size = %u)\n", (unsigned) size );
            exit( 1 );
        }
    }

    return *hp;
}


void freehash( hashdata * hd ) {
    if ( hd ) {
       if ( hd->hash ) free( hd->hash );
       free( hd );
    }
}
