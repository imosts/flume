
"""flume.__init__

Exceptions and constants for use with flume."""

# import everything not prefixed by "_" into this address space
# so that people who import us can get all of the flume constants.
from flume_internal import *
import flume_internal as ti
import errno

def init_errors ():
    oserr = [ "ENOENT", "EROFS", "EPERM", "EINVAL",
              "ERANGE", "ENOMEM", "EEXIST" ]
    flmerr = [ "OK", "ECAPABILITY", "EEXPIRED", "EHANDLE", "ENULL", "EATTR",
               "EPERSISTENCE", "EXDR" ]

    for e in oserr:
        code = getattr (ti, "FLUME_" + e)
        globals ()[e] = code
        _os_err_map[code] = getattr (errno, e)
        
    for e in flmerr:
        code = getattr (ti, "FLUME_" + e)
        globals()[e] = code

#
# rename all FLUME constants for convenience
#
_os_err_map = {}
init_errors ()

def sysErrno ():
    return _os_err_map.get (ti.get_errno ())

class FlumeError (Exception):
    def __init__(self, value):
        self.value = value
    def __str__(self):
        return repr(self.value)

class PermissionError (FlumeError):
    pass

class RawError (FlumeError):
    pass

class ReadOnlyError (FlumeError):
    pass

class DeclassificationError (FlumeError):
    pass

class IntegrityError (FlumeError):
    pass

class HandleError (FlumeError):
    pass

class CapabilityError (FlumeError):
    pass

class LoginError (FlumeError):
    pass

class ExpirationError (FlumeError):
    pass

class ExtattrError (FlumeError):
    pass

class PersistenceError (FlumeError):
    pass
