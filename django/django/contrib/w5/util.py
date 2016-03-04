import random, os, flume, wikicode
import flume.flmos as flmo
from wikicode import W5Uri, get_devel_un, request_uri, DEVEL_HOMEDIR_ENV
from wikicode.db.user import client_from_env, devel_from_env
from wikicode.const import *

def urlprefix (link_ls=None, js=None, mode=None, therest=None,
               file=None, cid=None, geturl=False, devel=None,
               trusted=False):
    req = request_uri ()
    
    if mode is None:
        mode = req.mode
    if file is None:
        file = req.file
    if devel is None:
        devel = get_devel_un ()
    if js is None:
        js = req.jsmode
    
    uri = W5Uri (mode=mode, devel=devel, file=file, jsmode=js,
                 therest=therest,
                 link_ls=link_ls, trusted=trusted)

    if cid:
        uri.reset_context_id (newcid=cid)

    if geturl:
        return uri
    return str (uri)

def new_page_id ():
    return random.randint (0, 2**32-1)

def base_ls ():
    w5u = client_from_env ()
    devel = devel_from_env ()

    if USE_USER_WCAPS:
        olab = flmo.Label ([w5u.get_tag ('wtag')])
    elif USE_DEVEL_WCAPS:
        olab = flmo.Label ([devel.get_tag ('wtag')])
    else:
        olab = flmo.get_label (flume.LABEL_O)

    if wikicode.IMODE & wikicode.IMODE_USER:
        ls = flmo.LabelSet (S=flmo.get_label (flume.LABEL_S),
                            I=flmo.Label ([w5u.script_tag ()]),
                            O=olab)

    elif wikicode.IMODE == wikicode.IMODE_ONEBIT:
        ls = flmo.LabelSet (S=flmo.get_label (flume.LABEL_S),
                            I=flmo.get_label (flume.LABEL_I),
                            O=olab)
    else:
        raise NotImplementedError ("IMODE %d" % wikicode.IMODE)
    
    return ls

def django_setup_py ():
    if SCRIPTMODE == SCRIPTMODE_PUBLISH:
        s = '/publish'
    elif SCRIPTMODE == SCRIPTMODE_ITAG:
        s = '/scripts'
    
    return ("import sys; sys.path.append ('%s'); "
            "import w5djangoutil; w5djangoutil.setup (); "
            % (os.environ[DEVEL_HOMEDIR_ENV] + s,))

def get_one_py (app, obj_type, obj_owner_col, obj_id):
    s = (django_setup_py () +
         "from %s.models import %sPointer, %s; " % (app, obj_type, obj_type) +
         "objs = %sPointer.objects.get (id=%d).%s_set." % (obj_type, obj_id, obj_type.lower()))

    if wikicode.IMODE & wikicode.IMODE_USER:
        s += "itag_owner_in_col ('%s_id'); " % (obj_owner_col,)
    else:
        s += "all (); "
    s += "objs = [o for o in objs]; obj = objs[0]; "
    return s
