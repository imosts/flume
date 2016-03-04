"""
flume.util

Utilities functions built on top of flume.flmos
"""

import os
import os.path
import flume
import flume.flmos as flmo
import re
import sys

mode2topt = {'r': 0,
             'i': flume.HANDLE_OPT_DEFAULT_SUBTRACT,
             'e': flume.HANDLE_OPT_DEFAULT_ADD,
             'w': flume.HANDLE_OPT_IDENTIFIER}

mode2copts = {'r': [ flume.CAPABILITY_ADD, flume.CAPABILITY_SUBTRACT ],
             'i': [ flume.CAPABILITY_ADD ],
             'e': [ flume.CAPABILITY_SUBTRACT ],
             'w': [ flume.CAPABILITY_GROUP_SELECT ]}

def flag2tagprefix (flags):
    topts, copts = flag2opts (flags)

    if 'w' in flags:
        return topts | copts[0]
    else:
        return topts
    
def flag2opts (flags):
    n_modes = 0
    mode = None
    for c in flags:
        if c in mode2topt.keys ():
            mode = c
            n_modes += 1
    if n_modes != 1:
        raise flume.HandleError, "must give exactly 1 tag mode"
    if not mode:
        raise flume.HandleError, "no tag mode found"

    topt = mode2topt[mode]
    copts = mode2copts[mode]
    if 'p' in flags:
        topt |= flume.HANDLE_OPT_PERSISTENT
    return topt, copts

def makeTag (flags="pe", name="anon"):
    """Give mode:
    'r' = Read-Protect
    'i' = Integrity-Protect
    'e' = Export-Protect
    'w' = Write-Protect / Identifier-Only

    And addition options:
    'p' = Persistent.

    Returns a pair, (h,[c1,c2,..]), where h is the handle created and
    the c1,c2,... are a list of the capabilities gained as a result of the
    handle creation.
    """

    topt, copts = flag2opts (flags)
    h = flmo.new_handle (opts = topt, name = name)
    caps = [ h.toCapability (o) for o in copts ]

    if 'w' in flags:
        h = caps[0]
    return (h, caps)

def makeGroup (name, ls):
    h = flmo.new_group (name, ls)
    return (h, h.toCapability (flume.CAPABILITY_GROUP_SELECT))

def makeCaps (h, opts):
    """Given a handle and some capability options, make all of the
    relevant capabilities for that given handle."""
    
    table = { '+' : flume.CAPABILITY_ADD,
              '-' : flume.CAPABILITY_SUBTRACT,
              's' : flume.CAPABILITY_GROUP_SELECT }
    
    flmopts = [ table[c] for c in opts ]
    return [ h.toCapability (o) for o in flmopts ]
            
def mkdirIfNotThere (path, mode=0755, labelset=None):
    x = re.compile ("^/+$")
    if not x.match (path):
        if not os.path.exists (path) :
            flmo.mkdir (path=path, mode=mode, labelset=labelset)
        elif not os.path.isdir (path) :
            raise ValueError, ("file exists but isn't a dir: '%s'" % path)
    
def mkdirAll (path, mode=0755, labelset=None, stopat = None):
    """Given a file, make all of the directories above it
    in the FS tree, using the given labelset."""
    sp = path.split (os.path.sep)
    if stopat is not None:
        sp = sp[0:stopat]
    d = ""
    for p in sp:
        d = d + os.path.sep + p
        mkdirIfNotThere (path=d, mode=mode, labelset=labelset)
