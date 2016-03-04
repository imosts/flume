#!/usr/bin/perl -w

#
# This is a little script that takes the libc.map generated
# by the glibc build process, and inserts some flume-specific
# symbols, which are then exported.
#
# Taken from plash, more or less.
#
# Usage:
#
#    edit-libc-map.pl <export-list> 
#
# And then this script will act as a filter.
#

use IO::File;

if ($#ARGV != 0) {
    warn "usage: $0 <symbol-list>\n";
    exit (1);
}

my $infn = $ARGV[0];

my $fh = new IO::File ("<$infn");
die "Cannot open file $infn\n" unless $fh;

my $list = "";
while (<$fh>) {
    chomp;
    $list .= "\n    $_;";
}

my $data = join('', <STDIN>);

$data =~ s/^(GLIBC\S+ \s* { \s* global:) /$1$list/x
  || die "Can't find first version in libc.map";

print $data;
