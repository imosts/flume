

"""flmw.__init__

Constants and base classes for flume web."""


IHOME = "ihome"
DOT_FLUME = ".flume"
TAGS_FILE = "tags"
GROUPS_FILE = "groups"
GROUP_INVITES_FILE = "group_invites"
PW_FILE = "pw"
TZW_HOME = "/home/flmw"
UMGR_HOME  = TZW_HOME + "/usermgr"
UMGR_DIR = "dir"
UMGR_BIN = "bin"
UMGR_SBIN = "setuid"
DIR_DEPTH = 4
MIN_UNAME_LEN = 6
DIR_NO_INTEGRITY = "noi"
DIR_USER_INTEGRITY = "useri"
DIR_EXPORT_PROTECT = "tainted"

class Error (Exception):
    def __init__(self, value):
        self.value = value
    def __str__(self):
        return repr(self.value)

class UserExistsError (Error):
    pass

class UserNameError (Error):
    pass

class UserLabelError (Error):
    pass

class UserMgrError (Error):
    pass

class UserPermError (Error):
    pass

class UserNotFoundError (Error):
    pass

class UserLoginError (Error):
    pass

class GroupNotFound (Error):
    pass
