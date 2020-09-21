SEED database support

The SEED database is a combination of a flat file collection and a
relational database that indexes it.


hacks to make mysql work on mac

add a ldflags option to Makefile.PL
change place where $opt{ldflags} is set to have it append
 /Applications/PATRIC.app/runtime/bin/perl Makefile.PL  --ldflags="-rpath /usr/local/mysql/lib" --libs="-L/usr/local/mysql/lib -lmysqlclient" --nossl

then edit the makefile to have the proper rpath
