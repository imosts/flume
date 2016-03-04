"""
flmw.util

Utility functions to help with flmw and umgr stuff.
"""

import flmw
import flmw.user
import os, os.path
import re

def home2uid (dir):
    """Given a home dir, return the user's armored User ID
    also known as auid."""
    try:
        uid = re.compile (os.path.sep + "+").split (dir)[2]
    except IndexError, e:
        pass
    return uid

def usernameToSymlink (uname, prefix=None):
    """Convert a username to the appropriate symlink that it
    should be living at."""
    if len (uname) < flmw.MIN_UNAME_LEN:
        raise flmw.UserNameError, ("username '%s' too short" % uname)

    arr = [ c for c in uname ]
    directory = os.path.sep.join (arr[0:flmw.DIR_DEPTH] + [uname])
    if prefix:
        directory = os.path.join (prefix, directory)
    return directory

def username2uid (uname, umgruid):
    link = usernameToSymlink (uname,
                              os.path.join ("/", flmw.IHOME, umgruid,
                                            flmw.UMGR_DIR))
    return home2uid (os.readlink (link))

def username2User (uname, umgruid):
    return flmw.user.User (uname, username2uid (uname, umgruid))
