"""
This script sets up the W5 server/database with some initial users.
One of which is the 'django-tools' user which is a regular,
unprivileged W5 user.  Anything in this script could be accomplished
through the web interface, but this is easier...

The django-tools user implements some django logic such as:
  -syncdb

"""

import os, os.path, sys, re, wikicode
import flume
import flume.flmos as flmo
from flume.labelsetdesc import LabelSetDesc
import DBV.dbapi as dbapi
from wikicode.db.user import User
from wikicode.db.app import App
from wikicode.errors import *
from wikicode.util import *
from wikicode.const import *
from wikicode.setup_data import setup_data_debug, setup_data_experiment

USER = os.environ['USER']
REAL_IHOME_LOCATION = '/disk/%s' % USER

lsd = LabelSetDesc (O=['ENV: MASTERGTAG_CAP', 'ENV: MASTERI_CAP'],
                    CAPSET=['ENV: MASTERGTAG_CAP, MASTERGTAG_TOK'])
masteritag = LabelSetDesc.get_tags ('ENV: MASTERI_CAP')[0].toTag ()


def reset_labels ():
    flmo.set_label2 (S=None)
    flmo.set_label2 (I=None)

    flmo.set_label2 (O=lsd.get_label (flume.LABEL_O))
    return

def register_apps (apps):
    for devel, dat in apps.items ():
        try:
            a = App (devel, dat['name'], dat['script'], dat['mode'])
            a.save ()
        except NotImplementedError:
            pass

        if dat['freeze']:
            try:
                a = App (devel, dat['name'] + "Frozen",
                         os.path.splitext (dat['script'])[0],
                         'exec')
                a.save ()
            except NotImplementedError:
                pass

def setup_acls (acl_data):
    for user, acl_lists in acl_data:
        u = User (user)

        for aclname, members in acl_lists:
            for member in members:
                if u.add_to_aclinstance (aclname, member):
                    print "Adding %s to %s's ACL %s" % (member, user, aclname)
    return

def create_user (un, pw, extratags=[], instances=[], declassifiers=[],
                 srcdir=None, script_files=None, static_files=None):
    u = User (un)
    try:
        u.create_data (pw, None)
    except DuplicateError:
        pass

    for flags, tname in extratags:
        try:
            u.maketag (flags, tname)
        except DuplicateError:
            pass
    reset_labels ()

def install_files (un, pw, extratags=[], instances=[], declassifiers=[],
                   srcdir=None, script_files=None, static_files=None):
    # Create additional user tags
    u = User (un)
    u.pwlogin (pw)

    if script_files:
        copy_files (u, u.script_ls(), srcdir, u.script_dir(), script_files)

    if static_files:
        copy_files(u, u.static_ls(), srcdir, u.static_dir(), static_files)

def copy_files (user, labelset, srcdir, dstdir, files):
    oldo = flmo.get_label (flume.LABEL_O)
    # widgets_user = User.objects.get (username="widgets")
    
    # Add any I capabilities we need because later, we'll have to
    # open other endpoints and our integrity will not let us read the users groups.
    add_o = []

    tags = labelset.get_S () + labelset.get_I () + user.script_ls().get_I() + user.get_tag ('wtag')
    if SCRIPTMODE == SCRIPTMODE_PUBLISH:
        tags.extend (user.publish_ls().get_I())
    
    for t in (tags):
        add_o += t.toCapabilities ()
    flmo.set_label2 (O=oldo + add_o)
        
    for fn in files:
        if type (fn) in (tuple, list):
            fullsrc = fn[0]
            destfile = fn[1]
        else:
            fullsrc = os.path.sep.join ((srcdir, fn))
            destfile = fn
        fulldst = os.path.sep.join ((dstdir, destfile))
        check_mkdir_label (os.path.dirname (fulldst), 0755, labelset)
        if SCRIPTMODE == SCRIPTMODE_PUBLISH:
            fullpublishdst = os.path.sep.join ((user.publish_dir (), destfile))
            check_mkdir_label (os.path.dirname (fullpublishdst), 0755, user.publish_ls())

        if (type (fn) not in (tuple, list) and fn.find("-secret") >= 0):
            print "Setting secrecy for secret file " + fn
            labelset.set_S(labelset.get_S() + user.get_tag ('etag'))
            flmo.set_label2 (O=flmo.get_label (flume.LABEL_O) + user.get_tag ('etag').toCapabilities ())
            flmo.set_label2 (S=labelset.get_S ())
        
        if should_copy (fullsrc, fulldst, src_interpose=False):
            print "Installing %s" % fulldst
            copy_file (fullsrc, fulldst, labelset, src_interpose=False, write_helper=True)
        if SCRIPTMODE == SCRIPTMODE_PUBLISH:
            if should_copy (fulldst, fullpublishdst):
                print "Publishing %s" % fullpublishdst
                user.publish_file (dstdir, destfile)
    reset_labels ()


def setup_declassifiers (un, pw, extratags=[], instances=[], assignments=[],
                         srcdir=None, script_files=None, static_files=None):
    # Install and configure declassifiers
    u = User (un)
    for instancename in instances:
        u.add_capability ('itag')
        u.add_capability ('wtag')
        if u.make_aclinstance (instancename):
            print "Making ACL instance %s for %s" % (instancename, un)

    for tagname, instancename in assignments:
        if u.set_aclinstance (tagname, instancename):
            print "Assigning tag %s to ACL instance %s" % (tagname, instancename)

    reset_labels ()

def setup_integrity_filters (filters):
    for u1, u2 in filters:
        u1 = User.object_withkey (u1)
        u1.make_filter (u2)

def syncdb_applications (apps):
    tools = User ('djangotools')
    calendar = User ('calendarapp')
    sys.path.append (tools.script_loc ())
    from syncdb import do_syncdb

    for devel, dat in apps.items ():
        if dat['syncdb']:
            before = sys.modules.keys ()
            projname = devel # The project names happen to be the same as the developer's username...
            s = do_syncdb (devel, projname)
            after = sys.modules.keys ()

            for m in set (after) - set (before):
                sys.modules.pop (m)
    sys.path.pop ()

def setup_photoapp (photoapp_data):

    # import and setup django
    tools = User ('djangotools')
    sys.path.append (tools.script_loc ())
    from w5djangoutil import setup_django_path_and_environ, append_to_path
    setup_django_path_and_environ ('photoapp', 'photoapp')

    # import photoapp functions
    append_to_path ('photoapp')
    from photoapp.views import experiment_newalbum, experiment_newphoto


    for username, albumconfig in photoapp_data:
        u = User.object_withkey (username)
        u.add_capability (u.script_tagname ())

        for albumname, files in albumconfig:
            if experiment_newalbum (username, albumname):
                print "Creating new album %s for user %s" % (albumname, username)
            for src, fname, tags in files:
                file_dat = read_file (src, interpose=False)
                
                map (u.add_capability, tags)
                if experiment_newphoto (username, albumname, fname, file_dat, tags):
                    print "Installing user %s file %s to album %s" % (username, fname, albumname)
        # Close connections since the preceding operations open a new
        # DB connection for different I labels and O labels.
        dbapi.close_all_conns ()
        reset_labels ()

    sys.path.pop ()

def print_appdata (all_apps, appname=None):
    if appname:
        apps = {appname: all_apps[appname]}
    else:
        apps = all_apps
    
    for devel, dat in apps.items ():
        d = User (devel)

        path = os.path.join (dat['fullscript'])
        srcdir = dat['srcdir']
        
        pypath = ':'.join ([all_apps[d2]['srcdir'] for d1, d2 in integrity_filters if d1==devel] +
                           [dat['srcdir']])
        
        print "%s %s %s %s" % (devel, path, srcdir, pypath)
        
def clean_users (user_data):
    import shutil
    
    for e in user_data:
        u = User (e[0])
        if not u.exists ():
            break
        scriptdir = u.script_dir ()
        
        files = [os.path.sep.join (('/disk', USER, scriptdir, f)) for f in os.listdir (scriptdir)]

        if SCRIPTMODE == SCRIPTMODE_PUBLISH:
            pubdir = u.publish_dir ()
            files.extend ([os.path.sep.join (('/disk', USER, pubdir, f)) for f in os.listdir (pubdir)])
        
        flmo.set_libc_interposing (False)
        for f in files:
            print "Removing %s" % (f,)
            if os.path.isfile (f) or os.path.islink (f):
                os.unlink (f)
            else:
                shutil.rmtree (f)
        flmo.set_libc_interposing (True)

def usage ():
    sys.stderr.write ("usage: %s [clean] [experiment]\n" % sys.argv[0])
    sys.stderr.write ("       %s -appdata <appname>\n" % sys.argv[0])
    sys.exit (1)

if __name__ == "__main__":
    argv = list (sys.argv)
    argv.pop (0)

    cln_users = False
    inst_users = True
    experiment = False
    printapps = False

    args = list (argv)
    while len (args) > 0:
        a = args.pop (0)
        if a == 'clean':
            cln_users = True
            inst_users = False
        elif a == 'experiment':
            experiment = True
        elif a == '-appdata':
            printapps = True
            inst_users = False
            appname = args.pop (0)
        else:
            usage ()

    if printapps and (inst_users or cln_users):
        usage ()

    lsd.acquire_capabilities ()

    User.create_tables ()
    App.create_tables ()

    if experiment:
        setup_data = setup_data_experiment
    else:
        setup_data = setup_data_debug

    if cln_users:
        clean_users (setup_data['users'])
    if inst_users:
        for e in setup_data['users']:
            create_user (*e)

        for e in setup_data['users']:
            install_files (*e)

        register_apps (setup_data['apps'])

        for e in setup_data['users']:
            setup_declassifiers (*e)

        setup_acls (setup_data['acls'])
        setup_integrity_filters (setup_data['filters'])
        syncdb_applications (setup_data['apps'])
#        setup_photoapp (setup_data['photoapp_data'])

    if printapps:
        print_appdata (setup_data['apps'], appname)
