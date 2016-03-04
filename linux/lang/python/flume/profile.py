import time, sys

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
