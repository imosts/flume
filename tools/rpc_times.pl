#!/usr/bin/perl -w
#
# Suggested command line:
#   grep trazrm output | rpc_times.pl | sort -n | less
#

%times = ();

while (<STDIN>) {
    if (/ ([\d\.]+) .+:(\S+ x=\S+)$/) {
        #print "[$1] [$2]\n";
        $time = $1;
        $key = $2;
        
        if (!$times{$key}) {
            $times{$key} = [];
        }

        if (/serve/) {
            if ($times{$key}[0]) {
                print STDERR "duplicate key $key overlapped, ignoring first instance\n";
            }
            $times{$key}[0] = $time;

        } elsif (/reply|reject/) {
            if ($times{$key}[1]) {
                print STDERR "duplicate key $key overlapped, ignoring first instance\n";
            }
            $times{$key}[1] = $time;
        }

        if ($times{$key}[0] && $times{$key}[1]) {
            $diff = $times{$key}[1] - $times{$key}[0];
            printf "%06f %s\n", $diff, $key;
            delete($times{$key});
        }
    }
}

foreach $k (keys %times) {
    print STDERR "Could not find reply for RPC $k\n";
}
