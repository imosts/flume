import time, psycopg2, sys

_start = None
_last = None

def start ():
    global _start, _last
    _start = _last = time.time ()
    return _start

def delta ():
    global _last
    
    now = time.time ()
    ret = now - _last
    _last = now
    return ret

def total ():
    global _start
    return time.time () - _start

def print_delta (caption, do_it=True):
    if do_it:
        sys.stderr.write (caption + ' %0.3f %0.3f\n' % (delta (), time.time ()))

def print_total (caption, do_it=True):
    if do_it:
        sys.stderr.write (caption + ' %0.3f %0.3f\n' % (total (), time.time ()))


stats = {}
def add_time (name, val):
    if not stats.has_key (name):
        stats[name] = []
    stats[name].append (val)

def print_times ():
    avgs = {}
    for name, vals in stats.items ():
        total = sum (vals)
        avgs[name] = total / len (vals)

    print "\n".join (["%s %0.3f" % (k, v) for k, v in avgs.items ()])

if sys.argv[1] == 'flume':
    import DBV
    import DBV.dbapi as dbapi
    use_flume = True
elif sys.argv[1] == 'postgres':
    use_flume = False
else:
    print "argument error"

ITERS = int (sys.argv[2])
SOCKIDX = int (sys.argv[3])

for i in range (ITERS):
    start ()

    if use_flume:
        dbname, user, pw, sname, sdir = DBV.default_db_user_pw (sockidx=SOCKIDX)
        conn = psycopg2.connect ('dbname=%s user=%s password=%s host=%s' %
                                 (dbname, user, pw, sdir))
    else:
        conn = psycopg2.connect ('dbname=%s user=%s password=%s '
                                 'host=18.26.4.76' % ('yipal', 'yipal', 'pw'))
    
    add_time ('connect', delta ())
                  
    cur = conn.cursor ()
    add_time ('cursor', delta ())
    
    cur.execute ("SELECT username from w5_user where username='alice'")
    add_time ('execute', delta ())

    ret = cur.fetchall ()
    add_time ('fetch', delta ())

    cur.close ()
    conn.close ()
    add_time ('close', delta ())
    
    #print "query %d records %d %s" % (i, len (ret), ' '.join (['%s %0.3f' % (x,y) for x,y in times]))

print_times ()
