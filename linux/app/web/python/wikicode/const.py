import os.path

PYTHON = '/usr/bin/python'

TRUSTED_WORKER_UNAME = 'wctrusted'

W5MODE_TRUSTED_PY            = 'trusted'
W5MODE_TRUSTED_PYWORKER      = 'trusted-worker'
W5MODE_TRUSTED_PYAPP_FORK    = 'trusted-appf'
W5MODE_TRUSTED_TOOLBAR       = 'toolbar'
W5MODE_UNTRUSTED_PY          = 'python'
W5MODE_UNTRUSTED_PYFORK      = 'pythonf'
W5MODE_UNTRUSTED_BIN         = 'exec'
W5MODE_UNTRUSTED_STATIC      = 'static'
W5MODE_UNTRUSTED_STATIC_IHOME= 'static-ihome'

trusted_modes = (W5MODE_TRUSTED_PY,
                 W5MODE_TRUSTED_PYWORKER,
                 W5MODE_TRUSTED_PYAPP_FORK,
                 W5MODE_TRUSTED_TOOLBAR)
script_modes = (W5MODE_UNTRUSTED_BIN,
                W5MODE_UNTRUSTED_PY,
                W5MODE_TRUSTED_PYWORKER,
                W5MODE_TRUSTED_PYAPP_FORK,
                W5MODE_UNTRUSTED_PYFORK)
static_modes = (W5MODE_UNTRUSTED_STATIC,
                W5MODE_UNTRUSTED_STATIC_IHOME)
legal_modes = trusted_modes + static_modes + script_modes

JS_MODE_ON  = 'js'
JS_MODE_OFF = 'njs'
jsmodes = (JS_MODE_ON, JS_MODE_OFF)
URL_LABEL_CHANGE = 'lc_'

# Only django apps use url_fmt.  The slash following the ls2 is
# optional in this rx because django collapses '//' to '/'
url_fmt = (r'(?:%s)/(?:%s)/%s(?:\w*,\w*,\w*)?/\w*/[\w\.]+'
           % ('|'.join (legal_modes), '|'.join (jsmodes), URL_LABEL_CHANGE))

url_fmt2 = (r'(%s)/(%s)/%s(\w*,\w*,\w*)?/(\w*)/([\w\.]+)'
           % ('|'.join (legal_modes), '|'.join (jsmodes), URL_LABEL_CHANGE))
url_rx = r'^/' + url_fmt2 + r'(/(.*))?'

invalid_script_filenames = ('/', '..')
invalid_therest_filename = ()

CODE_INTEGRITY_FNAME = 'code'
PERM_INTEGRITY_FNAME = 'perm'
IHOME = os.path.sep + 'ihome'

CLIENT_UN_ENV      = 'FLUME_UN'
CLIENT_HOMEDIR_ENV = 'CLIENT_HOMEDIR'
DEVEL_UN_ENV       = 'DEVEL_UN'
DEVEL_HOMEDIR_ENV  = 'DEVEL_HOMEDIR'
RPC_TAG_ENV        = 'RPC_TAG'
APP_FILTERS_ENV    = 'APP_FILTERS'

COOKIE_UN_ENV  = 'FLUME_UN'
COOKIE_GID_ENV = 'FLUME_GID'
COOKIE_TPW_ENV = 'FLUME_TPW'

PREPARE_URI_ENV   = 'FLUME_PREPARE_URI'
PREPARE_STAGS_ENV = 'FLUME_PREPARE_STAGS'

RESERVED_CIDS = []

DEF_COOKIE_LIFE = 24
USER_FILTERS    = False
USE_DJANGOZIP   = False
USE_FROZEN      = False
RAW_URLS        = True

HTTP_OK    = '200 OK'
HTTP_REDIR = '302 Temporarily moved'

IS_SUBFRAME_TRUE  = 'TRUE'
IS_SUBFRAME_FALSE = 'FALSE'

HTTPHDR_W5MODE_TRUSTED   = 'trusted'
HTTPHDR_W5MODE_UNTRUSTED = 'untrusted'

CONTENT_TYPES = {'jpeg': 'image/jpeg',
                 'jpg': 'image/jpeg',
                 'html': 'text/html',
                 'css': 'text/css',
                 'js': 'text/javascript',
                 }

# integrity options

IMODE_USER    = 1
IMODE_APP     = 2
IMODE_ONEBIT  = 4
IMODE = IMODE_ONEBIT

SCRIPTMODE_PUBLISH = 1
SCRIPTMODE_ITAG    = 2
SCRIPTMODE = SCRIPTMODE_ITAG

# wcap options
USE_USER_WCAPS = False
USE_DEVEL_WCAPS = True

FRIEND_ACL_NAME = 'friend_acl'
FRIEND_ETAG_NAME = 'friends'


# Widget Blog
#WIDGETS = [WIDGET_TWITTER, WIDGET_PUPPIES, WIDGET_EVIL]
WIDGETS = ["twitter", "puppies", "evil", "popular", "comments", "link", "recentposts", "cbox", "blog_content", "calendar", "youtube", "history", "labels", "random", "frame1", "frame2"]
#WIDGETS = ["popular", "comments"]

# Facebook
FBAPP_LINK_SELF_PRIV     = 'private'
FBAPP_LINK_SELF_FRIEND   = 'friends'
FBAPP_LINK_SELF_PUB      = 'public'
FBAPP_LINK_SELF_PAIRWISE = 'pairwise'

FBAPP_LINK_VIEW_PRIV     = 'vprivate'
FBAPP_LINK_VIEW_FRIEND   = 'vfriends'
FBAPP_LINK_VIEW_PUB      = 'vpublic'
FBAPP_LINK_VIEW_PAIRWISE = 'vpairwise'

# Misc per application data that should actually be stored in a database somewhere.
FBAPP_POKE = 'poke'
FBAPP_WALL = 'wall'
FBAPP_COMPARE = 'compare'
FBAPPS = [FBAPP_POKE, FBAPP_WALL, FBAPP_COMPARE]

fbapp_link_names = {
    FBAPP_POKE: {FBAPP_LINK_SELF_PRIV    : 'View Pokes',
                 FBAPP_LINK_SELF_FRIEND  : None, # This doesn't make much sense
                 FBAPP_LINK_SELF_PUB     : None,
                 FBAPP_LINK_SELF_PAIRWISE: 'Send Poke',

                 FBAPP_LINK_VIEW_PRIV    : None,
                 FBAPP_LINK_VIEW_FRIEND  : None,
                 FBAPP_LINK_VIEW_PUB     : None,
                 FBAPP_LINK_VIEW_PAIRWISE: 'Send Poke',
                 },

    FBAPP_WALL: {FBAPP_LINK_SELF_PRIV    : 'View Wall',
                 FBAPP_LINK_SELF_FRIEND  : 'Write on Wall',
                 FBAPP_LINK_SELF_PUB     : None,
                 FBAPP_LINK_SELF_PAIRWISE: None,

                 FBAPP_LINK_VIEW_PRIV    : 'View Wall',
                 FBAPP_LINK_VIEW_FRIEND  : 'Write on Wall',
                 FBAPP_LINK_VIEW_PUB     : None,
                 FBAPP_LINK_VIEW_PAIRWISE: None,
                 },

    FBAPP_COMPARE: {FBAPP_LINK_SELF_PRIV    : 'Similar People',
                    FBAPP_LINK_SELF_FRIEND  : None,
                    FBAPP_LINK_SELF_PUB     : None,
                    FBAPP_LINK_SELF_PAIRWISE: None,
                    
                    FBAPP_LINK_VIEW_PRIV    : 'Similar People',
                    FBAPP_LINK_VIEW_FRIEND  : None,
                    FBAPP_LINK_VIEW_PUB     : None,
                    FBAPP_LINK_VIEW_PAIRWISE: None,
                    },
}

VERBOSE_CAPTIONS = False
