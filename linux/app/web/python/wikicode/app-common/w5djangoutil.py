import sys, os, os.path, wikicode
from wikicode.db.user import User, devel_from_env, client_from_env
from wikicode.prepare import is_prepare, prepare_uri, prepare_stags

if wikicode.IMODE & wikicode.IMODE_APP:
    from DBV.dbapi import add_filters

# RPCs into the gateway
rpc_proxy = None
def get_new_cid ():
    global rpc_proxy
    return rpc_proxy.new_cid ()

def may_read (ls):
    global rpc_proxy
    return rpc_proxy.may_read (ls.toRaw().armor())

def get_all_readable ():
    import flume.flmos as flmo
    global rpc_proxy
    return [flmo.Handle (v) for v in rpc_proxy.get_all_readable ()]

def get_url (url):
    global rpc_proxy
    return rpc_proxy.get_url (url)

def send_email (username, msg):
    global rpc_proxy
    return rpc_proxy.send_email (username, msg)

def get_friendlist ():
    global rpc_proxy
    return rpc_proxy.get_friendlist ()

def append_to_path (user, zipfile=None):
    if isinstance (user, User):
        u = user
    else:
        u = User.object_withkey (user)

    path = u.script_loc ()
    if zipfile:
        path = os.path.join (path, zipfile)
    sys.path.append (path)

def add_djangotools  ():
    t = User ('djangotools')
    if wikicode.USE_DJANGOZIP:
        append_to_path (t, 'django.zip')
    append_to_path (t)

global_setup_done = False
def global_setup ():
    """ Setup things that we only need to do once per fork-server """
    global global_setup_done
    if global_setup_done:
        return
    global_setup_done = True

    #add_djangotools ()
    devel = devel_from_env ()
    
    # Setup python path
    append_to_path (devel)

    # Each app developer adds the path of each of the developers they trust.
    projname = devel.un
    if projname == 'photoedit':
        append_to_path ('photoapp')
    elif projname == 'newcalendarapp':
        append_to_path ('calendarapp')
        append_to_path ('weathergrabber')
    elif projname == 'compare':
        append_to_path ('facebook')
    
    setup_django_path_and_environ (devel.un, projname)

def setup_django_path_and_environ (devel_un, projname):
    add_djangotools ()

    # Setup django environment
    from djangotools.util import setup_environ_wrapper
    os.environ[wikicode.DEVEL_UN_ENV] = projname

    setup_environ_wrapper (devel_un, projname)

def setup ():
    # need to setup rpc proxy so gateway doesn't hang.
    if os.environ.has_key (wikicode.RPC_TAG_ENV):
        global rpc_proxy
        try:
            rpc_fd, rpc_proxy = wikicode.to_rpc_proxy (os.environ[wikicode.RPC_TAG_ENV])
        except OSError:
            pass

    devel = devel_from_env ()
    client = client_from_env ()
    if wikicode.USER_FILTERS:
        client.apply_filters ()

    if wikicode.IMODE & wikicode.IMODE_APP:
        wikicode.apply_app_filters ()
        devel.apply_filters ()
        add_filters (devel.get_user_filters ())

        # Add user filters.  Since we run with User and Devel integrity,
        # we must filter {master_i} -> {master_i, user_publish, user_itag}.
        add_filters (client.get_user_filters ())

        # XXX Need a filter here to do {djangotools} -> {djangotools, djangodevel} ?

    # This needs to be called once per fork child because it sets the
    # DJANGO_SETTINGS_MODULES env variable which gets cleared when
    # frksrv sets the child's env equal to the env sent by the fork
    # server's master.  Another approach would be to make frksrv
    # smarter about how it sets the child's env.
    setup_django_path_and_environ (devel.un, devel.un)

