SEED database support

The SEED database is a combination of a flat file collection and a
relational database that indexes it.


hacks to make mysql work on mac

add a ldflags option to Makefile.PL
change place where $opt{ldflags} is set to have it append
 /Applications/PATRIC.app/runtime/bin/perl Makefile.PL  --ldflags="-rpath /usr/local/mysql/lib" --libs="-L/usr/local/mysql/lib -lmysqlclient" --nossl

then edit the makefile to have the proper rpath

====

export PATH=/Applications/PATRIC.app/runtime/bin:$PATH
 git clone git@github.com:TheSEED/DBD-mysql.git
perl Makefile.PL --rpath /usr/local/mysql/lib --verbose --nossl  --libs="-L/usr/local/mysql/lib -lmysqlclient"
make OTHERLDFLAGS="-rpath /usr/local/mysql/lib"
make test
make install