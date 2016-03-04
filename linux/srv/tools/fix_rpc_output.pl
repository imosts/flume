#!/usr/bin/perl -w

@ok_symbols = ("bool_t", 
               "u_longlong_t",
	       "longlong_t",
               "int32_t",
               "xdr_u_longlong_t",
               "xdrproc_t",
               "enum_t");

@bad_symbols = ("flume_prog_1_table",
                "flume_prog_1_nproc",
                "flume_prog_1");

while (<>) {
    
    # Replace all _t symbols with _tc
    s/_t(\W)/_tc$1/g;

    # Replace bad symbols
    foreach $s (@bad_symbols) {
        s/$s/${s}c/g;
    }

    # Revert the symbols in ok_symbols
    foreach $s (@ok_symbols) {
        s/${s}c/$s/g;
    }

    print "$_";
}

