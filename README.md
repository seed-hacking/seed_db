# SEED database support

The SEED database is a combination of a flat file collection and a
relational database that indexes it.

# Hacks to make mysql work on mac

* add a ldflags option to Makefile.PL
* change place where $opt{ldflags} is set to have it append
  /Applications/PATRIC.app/runtime/bin/perl Makefile.PL  --ldflags="-rpath /usr/local/mysql/lib" --libs="-L/usr/local/mysql/lib -lmysqlclient" --nossl

then edit the makefile to have the proper rpath

```
export PATH=/Applications/PATRIC.app/runtime/bin:$PATH
 git clone git@github.com:TheSEED/DBD-mysql.git
perl Makefile.PL --rpath /usr/local/mysql/lib --verbose --nossl  --libs="-L/usr/local/mysql/lib -lmysqlclient"
make OTHERLDFLAGS="-rpath /usr/local/mysql/lib"
make test
make install
```

## Database creation
```
 mysql> create database seedtest;
 Query OK, 1 row affected (0.00 sec)

 mysql> create user seed@localhost identified by 'seedlocal';
 Query OK, 0 rows affected (0.00 sec)

 mysql> grant all privileges on seedtest.* to seed@localhost;
 Query OK, 0 rows affected (0.00 sec)
```
