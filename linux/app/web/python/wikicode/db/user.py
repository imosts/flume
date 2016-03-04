"""
This module mimics the Django API so that the gateway can use the same
database tables as any other Django application.  If you change
django/django/contrib/w5/models.py, you may need to update this file as well.

"""
import flume, wikicode, os.path, os, datetime
from flume.flmos import *
import flume.util as flmu
import flume.flmos as flmo
from DBV.dbapi import get_labeled_conn
from wikicode.db.util import DBObject, DB_LSD
from wikicode.errors import *
from wikicode.const import *

ADD = '+'
REMOVE = '-'

session_duration = 60*60*24

lsd_none = DB_LSD (S=[], I=[], O=[])

lsd_i = DB_LSD (I=['ENV: MASTERI_CAP'],
                O=['ENV: MASTERW_CAP'],
                CAPSET=['ENV: MASTERI_CAP, MASTERI_TOK',
                        'ENV: MASTERW_CAP, MASTERW_TOK'])

lsd_pw = DB_LSD (S=['ENV: MASTERR_CAP'],
                 I=['ENV: MASTERI_CAP'],
                 O=['ENV: MASTERW_CAP'],
                 CAPSET=['ENV: MASTERR_CAP, MASTERR_TOK',
                         'ENV: MASTERI_CAP, MASTERI_TOK',
                         'ENV: MASTERW_CAP, MASTERW_TOK'])

tag_cache = {}
homedir_cache = {}

class User (DBObject):
    table_desc = {
        'w5_user' : ('CREATE TABLE w5_user ( id integer NOT NULL PRIMARY KEY, '
                     'username varchar(128) NOT NULL UNIQUE, editor_id integer NOT NULL)',
                     lsd_i),

        'w5_password' : ('CREATE TABLE w5_password ( user_id integer NOT NULL PRIMARY KEY, '
                         'password varchar(128) NOT NULL, g_token varchar(128) NOT NULL, email varchar(128))',
                         lsd_pw),

        'w5_tagvalue' : ('CREATE TABLE w5_tagvalue ( id integer NOT NULL PRIMARY KEY, '
                         'user_id integer NOT NULL, tagvalue bigint NOT NULL)',
                         lsd_i),

        'w5_tagname' : ('CREATE TABLE w5_tagname ( id integer NOT NULL PRIMARY KEY, '
                        'tagvalue_id integer NOT NULL, tagname varchar(128) NOT NULL UNIQUE)',
                        lsd_i),

        'w5_expprotuserdata' : ('CREATE TABLE w5_expprotuserdata ( user_id integer NOT NULL PRIMARY KEY, '
                                'email varchar(75) NOT NULL, favoritecolor varchar(64) NOT NULL )',
                                lsd_none),

        'w5_filtersetting' : ('CREATE TABLE w5_filtersetting ('
                              'id integer NOT NULL PRIMARY KEY, '
                              'user_id integer NOT NULL, '
                              'app_id integer NOT NULL, '
                              'filtername varchar(128) NOT NULL)',
                              lsd_i),

        'w5_editor_map' : ('CREATE TABLE w5_editor_map ('
                           'id integer NOT NULL PRIMARY KEY, '
                           'user_id integer NOT NULL, '
                           'app_id integer NOT NULL, '
                           'tagname varchar(128) NOT NULL)',
                           lsd_i),

        'w5_context' : ('CREATE TABLE w5_context ('
                        'user_id integer NOT NULL, '
                        'context_id varchar(16) NOT NULL, '
                        'uri varchar(512), '
                        'labelset varchar(1024), '
                        'parent_cid varchar(16), '
                        'ctime timestamptz NOT NULL) ',
                        lsd_pw),

        'w5_aclinstance' : ('CREATE TABLE w5_aclinstance ('
                            'id integer NOT NULL PRIMARY KEY, '
                            'user_id integer NOT NULL, '
                            'name varchar (128) NOT NULL)',
                            lsd_pw),

        'w5_aclentry': ('CREATE TABLE w5_aclentry ('
                        'id integer NOT NULL PRIMARY KEY, '
                        'aclinstance_id integer NOT NULL, '
                        'user_id integer NOT NULL)',
                        lsd_pw),

        'w5_aclassignment': ('CREATE TABLE w5_aclassignment ('
                             'id integer NOT NULL PRIMARY KEY, '
                             'tagvalue_id integer NOT NULL UNIQUE, '
                             'aclinstance_id integer NOT NULL)',
                             lsd_pw),

        }

    sql_createindex = ["create index w5_context_user_idx on w5_context (user_id);",
                       "create index w5_context_cid_idx on w5_context (context_id);",
                       "create index w5_context_parent_idx on w5_context (parent_cid);",
                       "create index w5_context_user_cid_idx on w5_context (user_id, context_id);"]

    db_pri_table = 'w5_user'
    db_pri_key = 'username'

    sql_get_all = ('SELECT username, id FROM %s'
                   % (db_pri_table,))

    def __init__ (self, un, id=None, homedir=None, env=os.environ):
        DBObject.__init__ (self, env)
        self.un = un.lower ()
        self.my_pri_key = self.un
        self.id = id
        self.validate_username (self.un)
        self.env = env
        self.homedir = homedir
        if homedir:
            global homedir_cache
            homedir_cache[self.un] = homedir

        lsd_i.set_env (self.env)
        lsd_pw.set_env (self.env)

    def set_env (self, env):
        self.env = env
        
    def key_transform (cls, k):
        return k.lower ()
    key_transform = classmethod (key_transform)

    def validate_username (self, un):
        if not un.isalnum ():
            raise IllegalUsername, "Illegal username '%s', must be alpha numeric"

    def homedir_ls (self):
        masteritag = DB_LSD.get_tags ('ENV: MASTERI_CAP', env=self.env)[0].toTag ()
        itag = self.get_tag ('itag')
        wtag = self.get_tag ('wtag')

        itags = [itag, masteritag]
        if SCRIPTMODE == SCRIPTMODE_PUBLISH:
            tags.append (self.get_tag ('publish'))
        
        return LabelSet (I=Label (itags), O=Label ([wtag]))

    def script_ls (self):
        itag = self.get_tag ('itag')
        wtag = self.get_tag ('wtag')
        return LabelSet (I=Label ([itag]), O=Label ([wtag]))

    if SCRIPTMODE == SCRIPTMODE_PUBLISH:
        def publish_ls (self):
            itag = self.get_tag ('publish')
            wtag = self.get_tag ('wtag')
            return LabelSet (I=Label ([itag]), O=Label ([wtag]))

        def publish_dir (self):
            return os.path.sep.join ([self.home_dir(), 'publish'])

        def publish_file (self, srcdir, filename):
            from wikicode.util import should_copy, copy_file
            src = os.path.sep.join ((srcdir, filename))
            dst = os.path.sep.join ((self.publish_dir (), filename))
            copy_file (src, dst, self.publish_ls (), read_helper=True, write_helper=True)
            return True

    def noi_ls (self):
        wtag = self.get_tag ('wtag')
        return LabelSet (O=Label ([wtag]))

    def static_ls (self):
        itag = self.get_tag ('itag')
        wtag = self.get_tag ('wtag')
        return LabelSet (I=Label ([itag]), O=Label ([wtag]))

    def filter_ls (self):
        return self.homedir_ls ()

    def home_dir (self):
        global homedir_cache
        if not homedir_cache.has_key (self.un):
            if not self.homedir:
                ls = self.homedir_ls ()
                self.homedir = os.path.sep.join ((wikicode.IHOME, ls.to_filename()))
                homedir_cache[self.un] = self.homedir
        return homedir_cache[self.un]

    def script_dir (self):
        return os.path.sep.join ([self.home_dir(), 'scripts'])

    def script_loc (self):
        if SCRIPTMODE == SCRIPTMODE_PUBLISH:
            return self.publish_dir ()
        elif SCRIPTMODE == SCRIPTMODE_ITAG:
            return self.script_dir ()
        else:
            raise ValueError ('Invalid value for SCRIPTMODE')

    def script_tagname (self):
        if SCRIPTMODE == SCRIPTMODE_PUBLISH:
            return 'publish'
        elif SCRIPTMODE == SCRIPTMODE_ITAG:
            return 'itag'
        else:
            raise ValueError ('Invalid value for SCRIPTMODE')

    def script_tag (self):
        return self.get_tag (self.script_tagname ())

    def noi_dir (self):
        return os.path.sep.join ([self.home_dir(), 'noi'])

    def static_dir (self):
        # TODO(neha): move these raw strings into variables.
        return os.path.sep.join ([self.home_dir(), 'static'])

    def filter_dir (self):
        return os.path.sep.join ([self.home_dir(), 'filters'])

    def add_capability (self, tagname, cursor=None):
        tag = self.get_tag (tagname, cursor)
        set_label2 (O=get_label(flume.LABEL_O) + tag.toCapabilities ())

    def tag_exists (self, tagname, cursor=None, env=None):
        if not env:
            env = self.env
        return self.real_tag_exists (tagname, cursor, self.un, env=env)

    def real_tag_exists (cls, tagname, cursor=None, username=None, fullname=False, env=os.environ):
        if fullname:
            tn = tagname
        else:
            tn = wikicode.compound_tagname (username, tagname)

        cursor = cls.pri_table_read_cursor (cursor, env=env)
        sql = ("SELECT true FROM w5_tagname AS tn "
               "  WHERE tn.tagname='%s' " % (tn,))
        cursor.execute (sql)
        r = cursor.fetchall ()
        if len (r) > 1:
            raise InvalidObject ('Strange, there are more than tag by '
                                 'the name %s: %s' % (tn, [x[0] for x in r]))
        if len (r) == 0:
            return False
        return True
    real_tag_exists = classmethod (real_tag_exists)

    def get_tagnames (self, tags, cursor=None):
        ret = {}
        if len (tags) > 0:
            cursor = self.pri_table_read_cursor (cursor, env=self.env)
            sql = ("SELECT tv.tagvalue, tn.tagname "
                   "  FROM w5_tagname as tn, w5_tagvalue as tv "
                   "  WHERE tn.tagvalue_id=tv.id AND (%s)"
                   % ' OR '.join (["tv.tagvalue=%d" % t.val () for t in tags]))

            cursor.execute (sql)
            rows = cursor.fetchall ()

            for r in rows:
                ret[Handle (r[0])] = r[1]
        return ret

    def get_tag (self, tagname, cursor=None, get_tv_id=False):
        return self.real_get_tag (tagname, self.un, cursor, get_tv_id=get_tv_id, env=self.env)

    def real_get_tag (cls, tagname, username=None, cursor=None,
                      fullname=False, get_tv_id=False, env=os.environ):
        if fullname:
            tn = tagname
        else:
            tn = wikicode.compound_tagname (username, tagname)
        if tag_cache.has_key (tn):
            return tag_cache[tn]

        cursor = cls.pri_table_read_cursor (cursor, env=env)
        sql = ("SELECT tv.tagvalue, tv.id "
               "  FROM w5_tagname AS tn, w5_tagvalue AS tv, w5_user AS u"
               "  WHERE tn.tagvalue_id=tv.id "
               "    AND tn.tagname='%s' "
               "    AND tv.user_id=u.id "
               % (tn,))
        cursor.execute (sql)
        r = cursor.fetchall ()

        if len (r) > 1:
            raise InvalidObject ('Strange, there are more than tag by '
                                 'the name %s: %s' % (tn, [x[0] for x in r]))
        if len (r) == 0:
            raise InvalidObject ("Could not find tag '%s'" % (tn,))

        h = Handle (r[0][0])
        tag_cache[tn] = h
        if get_tv_id:
            return r[0][1]
        else:
            return h
    real_get_tag = classmethod (real_get_tag)

    def get_tags (self, cursor=None, flags=None):
        sql = ("SELECT tv.tagvalue, tn.tagname "
               "  FROM w5_tagname AS tn, w5_tagvalue AS tv, w5_user AS u"
               "  WHERE tn.tagvalue_id=tv.id "
               "    AND tv.user_id=u.id "
               "    AND u.username='%s' " % (self.un,))
        if flags:
            if not (type (flags) == list or type (flags) == tuple):
                flags = (flags,)

            masks = []
            for f in flags:
                opt = flmu.flag2tagprefix (f)
                masks.append ("(tv.tagvalue >> 56) = %d" % (opt,))
            sql += ' AND (' + ' OR '.join (masks) + ')'

        cursor = self.pri_table_read_cursor (cursor, self.env)
        cursor.execute (sql)
        r = cursor.fetchall ()
        return [(Handle (x[0]), x[1]) for x in r]

    def get_tag_ownerid (cls, tag, cursor=None, env=None):
        """ For <tag>, return the owner's uid """
        if not env:
            env=os.environ

        sql = ("SELECT user_id FROM w5_tagvalue "
               "  WHERE w5_tagvalue.tagvalue=%d" % tag.val ())

        cursor = cls.pri_table_read_cursor (cursor, env=env)
        cursor.execute (sql)
        ret = cursor.fetchall ()
        if len (ret) == 1:
            return ret[0][0]
        elif len (ret) == 0:
            raise InvalidObject ('No tag with value %d' % tag.val ())
        else:
            raise InvalidObject ('Too many tags with value %d' % tag.val ())
    get_tag_ownerid = classmethod (get_tag_ownerid)

    def get_user_filters (self):
        filterdir = self.filter_dir ()
        return [os.path.sep.join ((filterdir, f)) for f in os.listdir (filterdir)]

    def apply_filters (self):
        # Apply filters
        for fn in self.get_user_filters ():
            flmo.apply_filter (name=fn, typ=flume.LABEL_I)

    def read_lsd_pw (self, sql):
        epls, desls, sqlprefix = lsd_pw.get_read_labeling (savels=True, env=self.env)
        conn = get_labeled_conn (epls, desls)
        try:
            cursor = conn.cursor ()
            cursor.execute (sql)
            return cursor.fetchall ()
        finally:
            conn.close ()
            lsd_pw.pop_labelset ()

    def get_email (self):
        rows = self.read_lsd_pw ("SELECT email "
                                 "  FROM w5_password "
                                 "  WHERE user_id=%d " % (self.get_id ()))
        return rows[0][0]
        
    def pwlogin (self, pw):
        """ Checks password.  If successful, returns gcap and tpw,
        else raises exception"""
        self.pw = pw
        rows = self.read_lsd_pw ("SELECT w5_password.password, w5_password.g_token, w5_user.id "
                                 "  FROM w5_user, w5_password "
                                 "  WHERE w5_user.id=w5_password.user_id "
                                 "    AND w5_user.username='%s'" % (self.un))
        try:
            correct_pw, gtok, userid = rows[0]
        except IndexError:
            correct_pw = gtok = userid = None
        
        if self.pw != correct_pw:
            raise InvalidLogin ("Incorrect username or password, (%s, %s)" % (self.un, self.pw))

        cursor = self.pri_table_read_cursor (env=self.env)
        sql = ("SELECT tv.tagvalue "
               "  FROM w5_tagvalue AS tv, w5_tagname AS tn "
               "  WHERE tv.id=tn.tagvalue_id AND tv.user_id=%d AND tn.tagname='%s'" %
               (userid, wikicode.compound_tagname (self.un, 'gtag')))
        cursor.execute (sql)
        r = cursor.fetchall ()

        self.gcap = Handle (r[0][0]).toCapabilities ()[0]
        
        #wikicode.dbg ("Logging in user %s %s %s" % (self.un, self.gcap, session_duration))

        req_privs (self.gcap, gtok)
        self.tpw = make_login (self.gcap, session_duration)
        return self.gcap, self.tpw

    def make_directories (self):
        lsd = DB_LSD (I=['ENV: MASTERI_CAP'],
                      CAPSET=['ENV: MASTERI_CAP, MASTERI_TOK'],
                      env=self.env)

        lsd.acquire_capabilities (savels=True)
        hd_ls = self.homedir_ls ()
        flmo.set_label2 (I=hd_ls.get_I())
        
        try:
            flmo.mkdir (self.home_dir (), labelset=hd_ls)
            flmo.mkdir (self.script_dir (), labelset=self.script_ls ())
            if SCRIPTMODE == SCRIPTMODE_PUBLISH:
                flmo.mkdir (self.publish_dir (), labelset=self.publish_ls ())
            flmo.mkdir (self.filter_dir (), labelset=self.filter_ls ())
            flmo.mkdir (self.noi_dir (), labelset=self.noi_ls ())
            flmo.mkdir (self.static_dir (), labelset=self.static_ls())
        finally:
            lsd.pop_labelset ()

    def _make_filter (self, find, repl):
        import flume.setuid as flms
        from wikicode.util import helper_write
        caps = [ h.toCapabilities()[0] for h in repl - find ]
        fn = os.path.sep.join ((self.filter_dir(),
                                'filter.%s.%s' % (find.freeze ().armor32 (),
                                                  repl.freeze ().armor32 ())))

        my_itag = self.get_tag ('itag')
        my_wtag = self.get_tag ('wtag')
        master_itag = DB_LSD.get_tags ('ENV: MASTERI_CAP', env=self.env)[0].toTag ()

        # XXX We should protect this with a master r tag.
        ls = flmo.LabelSet (#S=flmo.Label ([master_etag]),
                            I=flmo.Label ([master_itag, self.script_tag ()]),
                            O=flmo.Label ([my_wtag]))
        
        oldls = flmo.get_labelset ()
        flmo.set_label2 (O=oldls.get_O () + caps + my_wtag + my_itag.toCapabilities ()[0])
        flmo.set_label2 (I=oldls.get_I () + ls.get_I () + my_itag)

        write_fn = (lambda name, mode, labelset, data:
                    helper_write (name, data,
                                  proc_ls=flmo.get_labelset (),
                                  file_ls=labelset))
        
        flms.makeFilter (name=fn, find=find, replace=repl, caps=caps, labelset=ls,
                         write_fn=write_fn)
        flmo.set_label2 (I=oldls.get_I ())
        flmo.set_label2 (O=oldls.get_O ())

    def make_filters (self):
        master_itag = DB_LSD.get_tags ('ENV: MASTERI_CAP', env=self.env)[0].toTag ()
        master_etag = DB_LSD.get_tags ('ENV: MASTERE_CAP', env=self.env)[0].toTag ()
        repl_tags = [master_itag, self.script_tag ()]

        find = flmo.Label ([master_itag])
        repl = flmo.Label (repl_tags)
        self._make_filter (find, repl)

    def make_filter (self, devel):
        """ Make a filter of the form I={devel:publish} -> {devel:publish, me:publish}
        or I={devel:itag} -> {devel:itag, me:itag} """
        d = User.object_withkey (devel)
        devel_itag = d.script_tag ()
        my_itag = self.script_tag ()
        
        find = flmo.Label ([devel_itag])
        repl = flmo.Label ([devel_itag, my_itag])
        self._make_filter (find, repl)

    def _makegroup (self):
        pass

    def _maketag (self, flags, tagname, cursor):
        if not self.exists (cursor=cursor):
            raise InvalidObject ('User %s does not exist' % self.un)

        uid = self.get_id (cursor=cursor)

        name = wikicode.compound_tagname (self.un, tagname)
        if self.tag_exists (tagname):
            raise DuplicateError ("tagname '%s' already exists" % name)

        tag, caps = flmu.makeTag (flags, name)

        tvid = self.make_unique_id (cursor, 'w5_tagvalue')
        cursor.execute ("INSERT INTO w5_tagvalue (id, user_id, tagvalue) VALUES (%d, %d, %d)" %
                        (tvid, uid, tag.val ()))

        tnid = self.make_unique_id (cursor, 'w5_tagname')
        cursor.execute ("INSERT INTO w5_tagname (id, tagvalue_id, tagname) VALUES (%d, %d, '%s')" %
                        (tnid, tvid, name))

        return tag, caps

    def maketag (self, flags, tagname):
        epls, desls, sqlprefix = lsd_i.get_write_labeling (savels=True, env=self.env)
        try:
            conn = get_labeled_conn (epls, desls)
            cursor = conn.cursor ()
            tag, caps = self._maketag (flags, tagname, cursor)
            self.add_to_my_group (caps)
            self.add_to_master_group (caps, 'TAG')
            cursor.execute ('COMMIT')
            return tag, caps
        finally:
            conn.close ()
            lsd_i.pop_labelset ()

    def make_my_group (self, cursor):
        # A user's group has their integrity as well as the master integrity

        oldls = get_labelset ()
        lsd = DB_LSD (I=['ENV: MASTERI_CAP'],
                      CAPSET=['ENV: MASTERI_CAP, MASTERI_TOK'],
                      env=self.env)
        lsd.acquire_capabilities ()
        
        ls = LabelSet (I=lsd.get_label (flume.LABEL_I) + self.get_tag ('itag', cursor),
                       O=Label ([self.get_tag ('wtag', cursor).toCapabilities()[0]]))

        self.add_capability ('itag', cursor)
        self.add_capability ('wtag', cursor)
        set_label2(I=oldls.get_I() + ls.get_I())

        gname = wikicode.compound_tagname (self.un, 'gtag')
        gtag, gcap = flmu.makeGroup (gname, ls)

        tvid = self.make_unique_id (cursor, 'w5_tagvalue')
        cursor.execute ("INSERT INTO w5_tagvalue (id, user_id, tagvalue) VALUES (%d, %d, %d)" %
                        (tvid, self.get_id (cursor), gtag.val ()))
        tnid = self.make_unique_id (cursor, 'w5_tagname')
        cursor.execute ("INSERT INTO w5_tagname (id, tagvalue_id, tagname) VALUES (%d, %d, '%s')" %
                        (tnid, tvid, gname))

        # leave the newly created gcap in our O label
        set_label2 (I=oldls.get_I ())
        set_label2 (O=oldls.get_O () + gcap)
        return gtag, gcap

    def add_to_my_group (self, caps, cursor=None):
        if type (caps) != list:
            caps = [caps]

        oldls = get_labelset ()
        lsd = DB_LSD (I=['ENV: MASTERI_CAP'],
                      CAPSET=['ENV: MASTERI_CAP, MASTERI_TOK',
                              'ENV: MASTERGTAG_CAP, MASTERGTAG_TOK',
                              'ENV: MASTERGGRP_CAP, MASTERGGRP_TOK'],
                      env=self.env)
        lsd.acquire_capabilities (savels=True)
        try:
            # Add gtag and immediately get rid of MASTERGGRP because
            # searching it overloads IDD
            mastergrp_tag = DB_LSD.get_tags ('ENV: MASTERGGRP_CAP', env=self.env)[0]
            self.add_capability ('gtag', cursor)
            flmo.set_label2 (O=flmo.get_label (flume.LABEL_O) - mastergrp_tag)

            self.add_capability ('itag', cursor)
            self.add_capability ('wtag', cursor)
            set_label2(I=oldls.get_I() + lsd.get_label (flume.LABEL_I) + self.get_tag ('itag'))

            gtag = self.get_tag ('gtag', cursor)
            add_to_group (gtag, Label (caps))
        finally:
            lsd.pop_labelset ()
        
    def add_to_master_group (self, caps, which):
        if type (caps) != list:
            caps = [caps]

        # Add the user's caps to the master group.
        lsd = DB_LSD (I=['ENV: MASTERI_CAP'],
                      CAPSET=['ENV: MASTERI_CAP, MASTERI_TOK',
                              'ENV: MASTERW_CAP, MASTERW_TOK',
                              'ENV: MASTERG%s_CAP, MASTERG%s_TOK' % (which, which),
                              ],
                      env=self.env)
        lsd.acquire_capabilities (savels=True)
        lsd.set_my_label (flume.LABEL_I)
        add_to_group (DB_LSD.get_tags ('ENV: MASTERG%s_CAP' % (which,),
                                       env=self.env)[0].toTag (),
                      Label(caps))
        lsd.pop_labelset ()
        
    def create_data (self, pw, epud):
        """ Create the underlying data for this User """

        # Create an entry for the user.
        epls, desls, sqlpreifx = lsd_i.get_write_labeling (env=self.env)
        conn = get_labeled_conn (epls, desls)
        cursor = conn.cursor ()
        cursor.execute ("BEGIN")
        if self.exists (cursor):
            cursor.execute ("ABORT")
            raise DuplicateError ("username %s already exists" % self.un)

        userid = self.make_unique_id (cursor, 'w5_user')
        cursor.execute ("INSERT INTO w5_user (id, username, editor_id) "
                        "  VALUES (%d, '%s', %d)" % (userid, self.un, userid))

        transfer_user = []
        transfer_master = []
        tags = [('etag', 'pe', True),
                ('anon', 'pe', True),
                ('itag', 'pi', True),
                ('wtag', 'pw', True),
                ('rtag', 'pr', True)]

        if SCRIPTMODE == SCRIPTMODE_PUBLISH:
            tags.append (('publish', 'pi', False))

        for tagname, flags, grant_user in tags:
            tag, caps = self._maketag (flags, tagname, cursor)
            if grant_user:
                transfer_user.extend (caps)
            transfer_master.extend (caps)

        # Make the user's group.
        # Add the user's caps to the user's group.
        # Add the user's caps to the master group of individual user capabilities.
        gtag, gcap = self.make_my_group (cursor)
        self.add_to_my_group (transfer_user, cursor)
        self.add_to_master_group (transfer_master, 'TAG')

        # Add the user's group cap to the master group of user capability sub-groups.
        self.add_to_master_group ([gcap], 'GRP')

        # Commit up to here, because we need to use a different
        # connection label for the password.
        cursor.execute ("COMMIT")
        cursor.close ()
        conn.close ()

        epls, desls, sqlprefix = lsd_pw.get_write_labeling (savels=True, env=self.env)
        conn = get_labeled_conn (epls, desls)
        cursor = conn.cursor ()
        cursor.execute ("BEGIN")
        cursor.execute ("SELECT true FROM w5_user WHERE id=%d AND username='%s'" %
                        (userid, self.un))
        r = cursor.fetchall()
        if len (r) != 1:
            cursor.execute ("ABORT")
            raise Exception ("Something happened to user %s in the middle of creation 1!" % self.un)

        # Save the user's password and token info
        tok = make_login (gcap)
        wikicode.dbg ("Made login for %s %s" % (gcap, tok))
        cursor.execute ("INSERT INTO w5_password (user_id, password, g_token, email) VALUES (%d, '%s', '%s', 'yipal@localhost')"%
                        (userid, pw, tok))
        cursor.execute ("COMMIT")
        cursor.close ()
        conn.close ()
        lsd_pw.pop_labelset ()

        self.make_directories ()
        self.make_filters ()

        #conn = get_labeled_conn (LabelSet())
        #cursor = conn.cursor ()
        #cursor.execute ("SELECT true FROM w5_user WHERE id=%d AND username='%s'" %
        #                (userid, self.un))
        #if len (cursor.fetchall()) != 1:
        #    cursor.execute ("ABORT")
        #    raise Exception ("Something happened to user %s in the middle of creation 2!" % self.un)
        
        #cursor.execute ("INSERT INTO w5_expprotuserdata (user_id, email, favoritecolor) "
        #                " VALUES (%d, '%s', '%s')" %
        #                (userid, epud['email'], epud['favoritecolor']))
        #cursor.execute ('COMMIT')
        #cursor.close ()

    def save_vals (self):
        raise NotImplementedError, 'please use create_data for now'

    def set_app_filters (self, app_id, filters=[], cursor=None):
        epls, desls, sqlpreifx = lsd_i.get_write_labeling (savels=True, env=self.env)
        try:
            conn = get_labeled_conn (epls, desls)
            cursor = conn.cursor ()

            sql = ("DELETE FROM w5_filtersetting "
                   "  WHERE user_id=%d AND app_id=%d"
                   % (self.get_id (), app_id))
            cursor.execute (sql)

            for fn in filters:
                filter_id = self.make_unique_id (cursor, 'w5_filtersetting')
                sql = ("INSERT INTO w5_filtersetting (id, user_id, app_id, filtername) "
                       " VALUES (%d, %d, %d, '%s')"
                       % (filter_id, self.get_id (), app_id, fn))
                cursor.execute (sql)
            cursor.execute ('COMMIT')
            return None

        finally:
            conn.close ()
            lsd_i.pop_labelset ()

    def get_app_filters (self, app_id=None, devel=None, script_name=None, cursor=None):
        if app_id:
            assert (devel is None and script_name is None), "bad args"

            cursor = self.pri_table_read_cursor (cursor, env=self.env)
            sql = ("SELECT filtername FROM w5_filtersetting"
                   "  WHERE user_id=%d AND app_id=%d"
                   % (self.get_id (), app_id))
            cursor.execute (sql)
            ret = cursor.fetchall ()
            return [row[0] for row in ret]

        else:
            assert app_id is None, "bad args"

            cursor = self.pri_table_read_cursor (cursor, env=self.env)
            sql = ("SELECT filt.filtername FROM w5_user AS u, w5_app AS app, w5_filtersetting AS filt"
                   "  WHERE u.username='%s' "
                   "    AND u.id=app.user_id "
                   "    AND app.scriptname='%s' "
                   "    AND app.id=filt.app_id" % (devel, script_name))
            cursor.execute (sql)
            ret = cursor.fetchall ()
            return [row[0] for row in ret]

    def set_editor_map (self, app_id, itagnames):
        epls, desls, sqlpreifx = lsd_i.get_write_labeling (savels=True, env=self.env)
        try:
            conn = get_labeled_conn (epls, desls)
            cursor = conn.cursor ()

            sql = ("DELETE FROM w5_editor_map "
                   "  WHERE user_id=%d "
                   "    AND app_id=%d " % (self.get_id (), app_id))
            cursor.execute (sql)

            for tagname in itagnames:
                choice_id = self.make_unique_id (cursor, 'w5_editor_map')
                sql = ("INSERT INTO w5_editor_map (id, user_id, app_id, tagname) "
                       " VALUES (%d, %d, %d, '%s')"
                       % (choice_id, self.get_id (), app_id, tagname))
                cursor.execute (sql)

            cursor.execute ('COMMIT')
            return None

        finally:
            conn.close ()
            lsd_i.pop_labelset ()

    def set_editor_id (self, editor_id, cursor=None):
        epls, desls, sqlpreifx = lsd_i.get_write_labeling (savels=True, env=self.env)
        try:
            conn = get_labeled_conn (epls, desls)
            cursor = conn.cursor ()

            sql = ("UPDATE w5_user "
                   "  SET editor_id=%d"
                   "  WHERE id=%d; COMMIT" % (editor_id, self.get_id ()))
            cursor.execute (sql)
            return None

        finally:
            conn.close ()
            lsd_i.pop_labelset ()

    def get_editor_id (self, cursor=None):
        cursor = self.pri_table_read_cursor (cursor, env=self.env)
        sql = ("SELECT editor_id FROM w5_user WHERE id=%d" % self.get_id ())
        cursor.execute (sql)
        ret = cursor.fetchall ()
        return ret[0][0]

    def get_editor_map (self, cursor=None):
        cursor = self.pri_table_read_cursor (cursor, env=self.env)
        sql = ("SELECT m.app_id, m.tagname "
               "  FROM w5_user as u, w5_editor_map as m "
               "  WHERE u.id=%d AND m.user_id=u.editor_id"
               % self.get_id ())
        cursor.execute (sql)
        ret = cursor.fetchall ()

        mapping = {}
        for app_id, tagname in ret:
            if mapping.has_key (app_id):
                mapping[app_id].append (tagname)
            else:
                mapping[app_id] = [tagname]
        return mapping

# --------- Deal with Contexts -----------
    def new_context_id (self, parent_cid=None):
        for i in range (3):
            new_cid = flume.random_str (4)
            if new_cid in wikicode.RESERVED_CIDS:
                continue
            if self.context_exists (new_cid):
                continue
            
            self._insert_context (new_cid, parent_cid)
            return new_cid
            
        raise WCError ("Could not allcoate cid!")

    def _insert_context (self, context_id, parent_cid):
        epls, desls, sqlprefix = lsd_pw.get_write_labeling (savels=True, env=self.env)
        conn = get_labeled_conn (epls, desls)
        try:
            cursor = conn.cursor ()
            sql = ("INSERT INTO w5_context (user_id, context_id, parent_cid, ctime) "
                   "  VALUES (%d, '%s', '%s', '%s'); "
                   "COMMIT"
                   % (self.get_id (), context_id, parent_cid, datetime.datetime.now ()))
            cursor.execute (sql)
            conn.commit ()
        finally:
            conn.close ()
            lsd_pw.pop_labelset ()
        

    def set_context (self, context_id, labelset=None, uri=None, parent_cid=None):
        """ Overwrites any existing context_id """

        if labelset:
            # If setting the labelset, make sure that the labelset is
            # smaller than all of my children.
            rows = self.read_lsd_pw ("SELECT context_id, labelset FROM w5_context "
                                     "  WHERE user_id=%d AND parent_cid='%s'"
                                     % (self.get_id (), context_id))
            for row in rows:
                if row[1]:
                    ls = wikicode.decode_labelset (row[1])
                    if labelset > ls:
                        raise WCExtensionError ("Application tried to set context (%s)"
                                                " labelset to %s, but has child (%s) with"
                                                " labelset %s." %
                                                (context_id, labelset, row[0], row[1]))

        
        epls, desls, sqlprefix = lsd_pw.get_write_labeling (savels=True, env=self.env)
        conn = get_labeled_conn (epls, desls)
        try:
            cursor = conn.cursor ()

            set_vars = ["ctime='%s'" % (datetime.datetime.now (),)]
            if labelset:
                set_vars.append ("labelset='%s'" % (wikicode.encode_labelset (labelset),))
            if uri:
                set_vars.append ("uri='%s'" % (uri,))
            if parent_cid:
                set_vars.append ("parent_cid='%s'" % (parent_cid,))
            set_vars = ', '.join (set_vars)
            
            sql = ("UPDATE w5_context SET %s"
                   "  WHERE user_id=%d AND context_id='%s'; "
                   % (set_vars, self.get_id (), context_id))
            cursor.execute (sql)
            if cursor.rowcount == 0:
                raise InvalidObject ("no match for user %d cid %s" % (self.get_id (), context_id))
            assert cursor.rowcount == 1, "Strange, there should be only one match, but it matched %d" % cursor.rowcount

            conn.commit ()
        finally:
            conn.close ()
            lsd_pw.pop_labelset ()

    def get_context (self, context_id):
        rows = self.read_lsd_pw ("SELECT labelset, uri FROM w5_context "
                                 "  WHERE user_id=%d AND context_id='%s'"
                                 % (self.get_id (), context_id))
        try:
            if rows[0] == (None, None):
                return rows[0]
            ls = wikicode.decode_labelset (rows[0][0])
            uri = rows[0][1]
            return ls, uri
        except IndexError:
            raise InvalidObject ('Context ID %s for user %d does not exist',
                                 context_id, self.get_id ())

    def context_exists (self, context_id):
        # Returns True if the context id exists in the table, even if
        # it's pending or being used
        try:
            self.get_context (context_id)
            return True
        except InvalidObject:
            return False

    def context_pending (self, context_id):
        # Returns True if the context id exists and is pending
        ls, uri = self.get_context (context_id)
        return (ls is None and uri is None)

    def context_addremove (self, typ, mode, cid, tags):
        """ Add or remove tags from the context label """
        # XXX This should probably be in a transaction
        ls, uri = self.get_context (cid)
        l = ls.get_label (typ)
        if mode == ADD:
            l += tags
        elif mode == REMOVE:
            l -= tags
        else:
            raise ValueError ("unsupported mode %s" % mode)
        ls.set_label (typ, l)
        self.set_context (cid, ls, uri)

    def get_newest_context_ids (self, limit=1):
        rows = self.read_lsd_pw ("SELECT context_id FROM w5_context "
                                 "  WHERE user_id=%d "
                                 "  ORDER BY ctime DESC "
                                 "  LIMIT %d"
                                 % (self.get_id (env=self.env), limit))
        return [row[0] for row in rows]
# ----------------------------------------

    def label2englishList (self, lab, cursor=None):
        m = self.get_tagnames (lab, cursor)
        v = []
        for tag in lab:
            if m.has_key (tag):
                v.append (m[tag])
            else:
                v.append (tag)
        return v

    def label2english (self, lab, cursor=None):
        v = self.label2englishList (lab, cursor)
        return '{%s}' % ', '.join (str(v1) for v1 in v)

    def labelset2english (self, labelset):
        return str (dict ([(k, self.label2english (v)) for (k, v) in labelset.toDict ().items ()]))

    def make_aclinstance (self, instance_name):
        try:
            self.get_aclinstance (instance_name)
            return False
        except InvalidObject:
            pass

        epls, desls, sqlprefix = lsd_pw.get_write_labeling (savels=True, env=self.env)
        conn = get_labeled_conn (epls, desls)
        try:
            cursor = conn.cursor ()
            instanceid = self.make_unique_id (cursor, 'w5_aclinstance')
            sql = ("INSERT INTO w5_aclinstance (id, user_id, name) "
                   "  VALUES (%d, %d, '%s'); COMMIT"
                   % (instanceid, self.get_id (), instance_name))
            cursor.execute (sql)
            return True
        finally:
            conn.close ()
            lsd_pw.pop_labelset ()

    def user2id (self, user):
        if isinstance (user, User):
            return user.get_id ()
        elif type (user) is int:
            return user
        elif type (user) is str:
            return User.object_withkey (user).get_id ()
        else:
            raise TypeError ("Invalid recipient type")

    def add_to_aclinstance (self, instance_name, recipient):
        instance_id = self.get_aclinstance (instancename=instance_name, get_id=True)
        recp = self.user2id (recipient)

        epls, desls, sqlprefix = lsd_pw.get_write_labeling (savels=True, env=self.env)
        conn = get_labeled_conn (epls, desls)
        try:
            cursor = conn.cursor ()
            sql = ("SELECT True FROM w5_aclentry AS e "
                   "  WHERE e.aclinstance_id=%d AND e.user_id=%d"
                   % (instance_id, recp))
            cursor.execute (sql)
            ret = cursor.fetchall ()
            if len (ret) > 0:
                return False

            entry_id = self.make_unique_id (cursor, 'w5_aclentry')
            sql = ("INSERT INTO w5_aclentry (id, aclinstance_id, user_id) "
                   "  VALUES (%d, %d, %d); COMMIT"
                   % (entry_id, instance_id, recp))
            cursor.execute (sql)
            return True
        finally:
            conn.close ()
            lsd_pw.pop_labelset ()

    def remove_aclentry (self, entry_id):
        epls, desls, sqlprefix = lsd_pw.get_write_labeling (savels=True, env=self.env)
        conn = get_labeled_conn (epls, desls)
        try:
            cursor = conn.cursor ()
            sql = ("DELETE FROM w5_aclentry WHERE ID=%d; COMMIT"
                   % entry_id)
            cursor.execute (sql)
        finally:
            conn.close ()
            lsd_pw.pop_labelset ()

    def set_aclinstance (self, tagname, instancename):
        """ Assign an ACL instance to a tag """
        tag_id = self.get_tag (tagname, get_tv_id=True)
        instance_id = self.get_aclinstance (instancename=instancename, get_id=True)

        epls, desls, sqlprefix = lsd_pw.get_write_labeling (savels=True, env=self.env)
        conn = get_labeled_conn (epls, desls)
        try:
            cursor = conn.cursor ()
            cursor.execute ("SELECT aclinstance_id FROM w5_aclassignment "
                            "WHERE tagvalue_id=%d" % tag_id)
            rows = cursor.fetchall ()
            if len (rows) == 1 and rows[0][0] == instance_id:
                return False
            elif len (rows) == 1:
                cursor.execute ("DELETE FROM w5_aclassignment "
                                "WHERE tagvalue_id=%d" % tag_id)

            if instancename:
                assignment_id = self.make_unique_id (cursor, 'w5_aclassignment')
                sql = ("INSERT INTO w5_aclassignment "
                       "(id, tagvalue_id, aclinstance_id) "
                       "  VALUES (%d, %d, %d); COMMIT"
                       % (assignment_id, tag_id, instance_id))
            else:
                sql = "COMMIT"

            cursor.execute (sql)
            return True
        finally:
            conn.close ()
            lsd_pw.pop_labelset ()

    def get_aclinstance (self, instancename=None, get_id=False):
        """ Geta list of ACL instances, check if the ACL instance
        exists, or get the ID of the instances """
        sql = ('SELECT name, id FROM w5_aclinstance '
               '  WHERE user_id=%d' % self.get_id ())
        if instancename:
            sql += " AND name='%s'" % instancename
        
        rows = self.read_lsd_pw (sql)
        if instancename:
            if len (rows) == 1:
                if get_id:
                    return rows[0][1]
            else:
                raise InvalidObject ()
        else:
            if get_id:
                return [row[1] for row in rows]
            else:
                return [row[0] for row in rows]

    def get_aclassignment (self, tag):
        """ Return which ACL instance is assigned to <tag> """
        rows = self.read_lsd_pw ('SELECT i.name, a.aclinstance_id '
                                 '  FROM w5_tagvalue AS tv, w5_aclassignment AS a, w5_aclinstance AS i'
                                 '  WHERE tv.tagvalue=%d AND a.tagvalue_id=tv.id AND a.aclinstance_id=i.id'
                                 % tag.val ())
        if len(rows) > 0:
            return rows[0]
        raise InvalidObject ('No ACL instance for tag %s' % tag)

    def get_acl_decision (self, tag, recipient):
        """ Returns True if <self> is willing to reveal <tag> to <recipient> """

        sql = ("SELECT true "
               "  FROM w5_tagvalue AS tv, "
               "       w5_aclassignment AS a, "
               "       w5_aclentry AS e, "
               "       w5_user AS u "
               "  WHERE %d=tv.tagvalue AND tv.id=a.tagvalue_id "
               "    AND a.aclinstance_id=e.aclinstance_id "
               % tag.val ())

        if isinstance (recipient, User):
            sql += " AND e.user_id=%d " % recipient.get_id ()
        elif type (recipient) is int:
            sql += " AND e.user_id=%d " % recipient
        elif type (recipient) is str:
            sql += " AND e.user_id=u.id AND u.username='%s'" % recipient
        else:
            raise TypeError ("Invalid recipient type")

        rows = self.read_lsd_pw (sql)
        return len (rows) > 0

    def get_acl_entries (self, aclname):
        sql = ("SELECT u.username, e.id "
               "  FROM w5_user AS u, w5_aclentry AS e, w5_aclinstance AS i"
               "  WHERE i.user_id=%d AND i.name='%s' "
               "    AND i.id=e.aclinstance_id AND e.user_id=u.id"
               % (self.get_id (), aclname))
        rows = self.read_lsd_pw (sql)
        return rows

    def get_all_readable_tags (self):
        sql = ("SELECT t.tagvalue "
               "  FROM w5_aclentry AS e, w5_aclinstance AS i, "
               "       w5_aclassignment AS a, w5_tagvalue AS t "
               "  WHERE e.user_id=%d AND "
               "        i.id=e.aclinstance_id AND "
               "        a.aclinstance_id=i.id AND "
               "        a.tagvalue_id=t.id" % self.get_id ())
        rows = self.read_lsd_pw (sql)
        return [flmo.Handle (r[0]) for r in rows]

user_cache = {}
def _from_env (username_env, homedir_env, env=os.environ):
    un = env.get (username_env)
    homedir = env.get (homedir_env)
    if un is None or homedir is None:
        return None

    user_cache[un] = User (un, homedir=homedir)
    return user_cache[un]

def client_from_env (env=os.environ):
    return _from_env (wikicode.CLIENT_UN_ENV, wikicode.CLIENT_HOMEDIR_ENV, env=env)
def devel_from_env (env=os.environ):
    return _from_env (wikicode.DEVEL_UN_ENV, wikicode.DEVEL_HOMEDIR_ENV, env=env)
