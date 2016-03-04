import flume.flmos as flmo
from flume.labelsetdesc import LabelSetDesc

import wikicode, os, flume
from wikicode.db.user import User
from wikicode.spawn import spawn_child

def is_prepare ():
    return os.environ.has_key (wikicode.PREPARE_URI_ENV)

def prepare_uri ():
    return os.environ[wikicode.PREPARE_URI_ENV]

def prepare_stags ():
    rd = flmo.RawData (dat=os.environ[wikicode.PREPARE_STAGS_ENV], armored=True)
    l = flmo.Label (rd)
    return l.toList ()

def run_prepare (user, cid, new_stags, env):
    """
    Run the cgi app in 'prepare' mode.
    """
    
    child_ls, uri = user.get_context (cid)
    uri = wikicode.W5Uri (uri=uri, trusted=False)

    devel = User (uri.devel)
    devel.set_env (env)
        
    script_file = os.path.join (devel.script_loc (), uri.file)
    filters = user.get_app_filters (devel=devel.un, script_name=uri.file)

    # Make an env for the child that looks like a regular CGI call
    child_env = wikicode.untrusted_env (user, env, devel, filters)
    child_env[wikicode.PREPARE_URI_ENV] = str(uri)
    child_env[wikicode.PREPARE_STAGS_ENV] = flmo.Label (new_stags).toRaw ().armor ()
    child_env['REQUEST_URI'] = str (uri)
    child_env['SCRIPT_NAME'] = '/python'
    child_env['HTTP_HOST'] = cid + wikicode.get_zone_suffix (env)
    del child_env['QUERY_STRING']

    lsd = LabelSetDesc (CAPSET=['ENV: MASTERGTAG_CAP, MASTERGTAG_TOK'])
    lsd.acquire_capabilities (savels=True, env=env)

    add_o = []
    for t in child_ls.get_S () + child_ls.get_I () + child_ls.get_O ():
        add_o.extend (t.toCapabilities ())
    flmo.set_label2 (O=flmo.get_label (flume.LABEL_O) + add_o)

    argv = [wikicode.PYTHON, '-S', script_file]
    try:
        ret = spawn_child (child_ls, argv, env=child_env, frksrv=(uri.mode == 'pythonf'))
        out, err, status = ret[0:3]
    finally:
        lsd.pop_labelset ()

    return out, err, status

