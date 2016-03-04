import os, sys, re

if False:
    NUSERS = [1]
    NUMREQ = [200]
    CONCUR = [1,10,20,25,30,40]
else:
    NUSERS = [1000]
    NUMREQ = [5000]
    CONCUR = [1,10,15,20,25,30,40]

MAX_USERS = 1000 # This is the number of users created by wcsetup.py

REQ_LOGINPAGE   = 'loginpage'
REQ_HOMEPAGE    = 'homepage'
REQ_BLOG        = 'blog'
REQ_ALBUM       = 'album'
REQ_FASTCGITEST = 'fastcgitest'
REQ_NULLPY      = 'nullpy'
REQ_NULLC       = 'nullc'
REQ_APACHENULLC = 'apachenullc'
REQ_DJANGONULL  = 'djangonull'
REQ_DJANGOALBUM = 'djangoalbum'

all_request_types = (REQ_LOGINPAGE,
                     REQ_HOMEPAGE,
                     REQ_BLOG,
                     REQ_ALBUM,
                     REQ_FASTCGITEST,
                     REQ_NULLPY,
                     REQ_NULLC,
                     REQ_APACHENULLC,
                     REQ_DJANGONULL,
                     REQ_DJANGOALBUM)
default_request_types = (REQ_NULLC, REQ_NULLPY, REQ_LOGINPAGE, REQ_HOMEPAGE, REQ_BLOG, REQ_ALBUM, REQ_APACHENULLC)

PROXY_IP = "18.26.4.60"
PROXY_PORT = 8000

SERVER = 'hydra.lcs.mit.edu'

# Get env settings
BINDIR = os.popen ('ssh %s flume-cfg bin' % SERVER).read ().strip ()
PYBIN  = os.popen ('ssh %s flume-cfg pybin' % SERVER).read ().strip ()
PYVERS  = os.popen ('ssh %s flume-cfg pyvers' % SERVER).read ().strip ()

PYTHON='flume-python'
PREPARE='w5-prepare-bench.py'
ASCLI='../ascli'

verbose = False

def stats(r):
    #returns the median, mean, standard deviation, min and max of a sequence
    tot = sum(r)
    mean = tot/len(r)
    sdsq = sum([(i-mean)**2 for i in r])
    s = list(r)
    s.sort()
    return s[len(s)//2], mean, (sdsq/(len(r)-1 or 1))**.5, min(r), max(r)

def print_results (numusers, err_dat, which_page):
    # Calculat throughput
    dat_line = err_dat[-2]
    m = re.match (r'(\d+),(\d+),(\d+)', dat_line)
    if (m is None):
        report_err ("Could not parse bad output1: %s" % dat_line)

    concur = int (m.group (1))
    numreq = int (m.group (2))
    total_us = float (m.group (3))

    total_sec = total_us / 1000000
    req_per_sec = numreq / total_sec

    # Calculate latency
    latency_list = [float (e)/1000 for e in err_dat[0:numreq]]
    med, mean, sd, min, max = stats (latency_list)

    if verbose:
        print "which_page: %s" % which_page
        print "num_users: %d" % numusers
        print "num_requests: %d" % numreq
        print "concurrency: %d" % concur
        print "totalsec: %0.5f" % total_sec
        print "throughput: %0.5f" % req_per_sec
        print "latencyms_median: %0.3f" % med
        print "latencyms_mean: %0.3f" % mean
        print "latencyms_stddev: %0.3f" % sd
        print "latencyms_min: %0.3f" % min
        print "latencyms_max: %0.3f" % max

    else:
        print ("%-10s %s %s %s %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f"
               % (which_page, numusers, numreq, concur, req_per_sec,
                  med, mean, sd, min, max))

def check_errors (err_dat):
    err_line = err_dat[-1]
    m = re.search (r'bad_responses=(\d+);', err_line)
    if (m is None):
        report_err ("Could not parse bad output2: %s" % err_line)
    elif int (m.group(1)) > 0:
        report_err ("Got bad responses: %s" % err_line)

def run_experiment (userlist, concur, numreq, numusers, which_page):
    # Run ascli
    cmd = ('%s -c %d -n %d w5cli -p %s -u - -n %d %s:%d'
           % (ASCLI, concur, numreq, which_page, numusers, PROXY_IP, PROXY_PORT))


    dbg ("cmd %s" % cmd)
    fin, fout, ferr = os.popen3 (cmd)
    fin.write (userlist)
    fin.close ()

    out_dat = fout.read ()
    err_dat = ferr.read ()
    dbg ("err: %s" % err_dat)
    #dbg ("out: %s" % out_dat)

    check_errors (err_dat.splitlines ())
    print_results (numusers, err_dat.splitlines (), which_page)

def report_err (s):
    sys.stderr.write (s)
    sys.exit (-1)

def dbg (s):
    if verbose:
        print s

def usage ():
    print "%s -v -f <login_file> -p <req_type>" % sys.argv[0]
    print "  -v : enable verbose messages"
    print "  -f : save/use login info to file <login_file>"
    print "  -p : request type, one of these: %s" % (all_request_types,)
    sys.exit (-1)

def do_prepare (non_frozen):
    cmd = '%s%s %s%s -n %d %s' % (BINDIR, PYTHON, PYBIN, PREPARE, max(NUSERS), non_frozen)
    dbg ("cmd %s" % cmd)
    userlist = os.popen ('ssh %s %s' % (SERVER, cmd)).read ()
    dbg ("made userlist [%s]" % userlist)
    return userlist

def main ():
    # Parse args
    global verbose
    login_file = None
    which_page = default_request_types
    non_frozen = ''
        
    args = sys.argv[1:]
    while (len (args) > 0):
        arg = args.pop (0)
        if arg == '-v':
            verbose = True
        elif arg == '-f':
            login_file = args.pop (0)
        elif arg == '-p':
            which_page = args.pop (0)
            if which_page not in all_request_types:
                usage ()
        elif arg == '-nf':
            non_frozen = '-nf'
        else:
            usage ()

    if login_file and os.path.exists (login_file):
        userlist = open (login_file, 'r').read ()
        if len (userlist.splitlines ()) < max (NUSERS):
            print "Not enough users in login file"
            usage ()
    else:
        userlist = do_prepare (non_frozen)
        if login_file:
            f = open (login_file, 'w')
            f.write (userlist)
            f.close ()

    if max (NUSERS) > MAX_USERS:
        print "You requested too many users for the user database"
        usage ()

    if type (which_page) not in (tuple, list):
        which_page = [which_page]

    for typ in which_page:
        for nusers in NUSERS:
            for c in CONCUR:
                for n in NUMREQ:
                    run_experiment (userlist, c, n, nusers, typ)

if __name__ == "__main__":
    main ()

