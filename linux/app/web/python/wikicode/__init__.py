# Libraries useful for wikicode extensions.
# Parent class for anything that spits out html

import cgi, sys, os, os.path, flume, re
import flume.flmos as flmo
from wikicode.db.user import User, client_from_env, devel_from_env
from wikicode.errors import *
from wikicode.util import to_rpc_proxy, cached_re, str2label
from Cookie import SimpleCookie
from wikicode.const import *


if IMODE & IMODE_APP:
    from DBV.dbapi import add_filters

class extension:
    PROFILE = False

    def __init__ (self, stdin_obj=None, env=os.environ):
        # Useful stuff for most wikicode extensions:
        self.form = cgi.FieldStorage (fp=stdin_obj, environ=env)
        self.ls = flmo.get_labelset ()
        self.env = env

        for var, env in (('un', CLIENT_UN_ENV),
                         ('request_uri', 'REQUEST_URI')):
            if self.env.has_key (env):
                setattr (self, var, self.env[env])
            else:
                setattr (self, var, None)

        # For internal use
        self._principal = None
        self._developer = None
        self._headers = ()
        self._page_contents = []
        if self.env.has_key (RPC_TAG_ENV):
            self._rpc_fd, self._rpc_proxy = to_rpc_proxy (self.env[RPC_TAG_ENV])
        else:
            self._rpc_fd, self._rpc_proxy = None, None

        if IMODE & IMODE_APP:
            # apply filters
            apply_app_filters ()
            if self.get_developer ():
                self.get_developer ().apply_filters ()
                add_filters (self.get_developer ().get_user_filters ())

    def logged_in (self):
        return (self.un is not None)

    def anon_mode (self):
        anon_tag = self.get_principal ().get_tag ('anon')
        return anon_tag in self.get_label (flume.LABEL_S)

    def get_principal (self):
        if not self._principal:
            self._principal = client_from_env (self.env)
            self._principal.set_env (self.env)
        return self._principal

    def get_developer (self):
        if not self._developer:
            self._developer = devel_from_env (self.env)
        return self._developer

    #def read_tags (self):
    #    """
    #    This will try to read the tags file which is protected by the
    #    user's export tag, so the extension will need to run with
    #    _e_tag.
    #    """
    #    self.get_principal ().readTags ()

    def get_output (self, s=''):
        out = [x + '\r\n' for x in self._headers]
        out.append ('Content-Type: text/html\r\n\r\n')
        out.extend (self._page_contents)
        out.append (s)
        return ''.join (out)

    def send_page (self, s=''):
        sys.stdout.write (self.get_output (s))

    def output_redirect (self, msg, uri, delay=0):
        self.append_header ('Status: ' + HTTP_REDIR)
        self.append_header ('Location: %s' % uri)

    def append_header (self, h):
        self._headers += (h,)

    def append_to_page (self, s):
        self._page_contents.append (s)

    #def img_src (uri, link_ls=None):
    #    return ('<IMG SRC=\"%s\">' % cgi.escape (uri, 1))

    def dbg (self, s):
        sys.stderr.write ('%s\n' % s)
        sys.stderr.flush ()

    def print_time (self, caption):
        if self.PROFILE:
            from flume.profile import print_delta
            print_delta (caption)

    def run (self):
        pass

def run_extension (ext_class):
    if ext_class.PROFILE:
        from flume.profile import start, print_total
        start ()

    try:
        ext = ext_class ()
        ext.run ()
    except Exception, e:
        format_error (e)
        
    if ext_class.PROFILE:
        print_total ('total worker time')

class W5Uri (object):
    def __init__ (self, uri=None, env=os.environ,
                  netloc=None, mode=None, jsmode=False,
                  devel=None, file=None, link_ls=None,
                  therest=None, args=None, trusted=True):
        self.env = env
        if uri:
            for v in ('netloc', 'mode', 'jsmode', 'ls2',
                      'devel', 'file', 'therest', 'args'):
                setattr (self, v, None)
            self.parse_labeled_uri (uri)
            if self.netloc is None and netloc:
                self.netloc = netloc

            if self.ls2 and len (self.ls2) > 0:
                self.ls2 = decode_labelset (self.ls2)
        else:
            self.netloc = netloc
            self.mode = mode
            if jsmode:
                self.jsmode = JS_MODE_ON
            else:
                self.jsmode = JS_MODE_OFF
            if link_ls:
                self.ls2 = link_ls.clone ()
            else:
                self.ls2 = None
            self.devel = devel
            self.file = file
            self.therest = therest
            self.args = args

        if self.netloc is None:
            if trusted:
                self.netloc = self.env['SERVER_NAME'] + ':' + self.env['SERVER_PORT']
            else:
                self.netloc = self.env['HTTP_HOST']
        self.trusted = trusted
        
    def parse_labeled_uri (self, uri):
        import urlparse
        u = urlparse.urlparse (uri)
        path = u[2]
        v = path.split ('/')

        if len(v) < 2:
            raise ValueError, ('No page by the path: %s URI %s' % (path, uri))
        if v[0] != '':
            raise ValueError, ('Illegal path: %s, %s' % (v[0], path))

        if v[1] not in legal_modes:
            raise ValueError, ('Illegal mode: %s, uri: %s' % (v[1], uri))
        self.mode = v[1]

        if self.mode in script_modes + static_modes:
            m = cached_re (url_rx).match (path)
            if not m:
                raise ValueError, ('Illegal path: %s re' % path)

            self.jsmode, self.ls2, self.devel, self.file = m.groups ()[1:5]
            self.therest = m.groups ()[6]
            if illegal_script_name (self.file):
                raise ValueError, ('Invalid filename: %s' % self.file)
            if self.therest and illegal_therest (self.therest):
                raise ValueError, ('Invalid URL remainder: %s' % self.therest)

        if u[1] != '':
            self.netloc = u[1]

    def ls2_str (self):
        if self.ls2:
            return URL_LABEL_CHANGE + encode_labelset (self.ls2)
        else:
            return URL_LABEL_CHANGE

    def context_id (self):
        m = cached_re (r'^(\w+)%s$' % get_zone_suffix (self.env)).match (self.netloc)
        if m:
            return m.group (1)
        return None

    def reset_context_id (self, user=None, newcid=None, parent_cid=None):
        if newcid is None:
            newcid = user.new_context_id (parent_cid)
        self.netloc = '%s%s' % (newcid, get_zone_suffix(self.env))

    def js_on (self):
        if self.jsmode == JS_MODE_ON:
            return True
        return False

    def path_info (self):
        # Return what would be in the PATH_INFO env variable (everything after the "mode")
        uri = ''
        if self.devel:
            uri += '/%s/%s/%s/%s' % (self.jsmode, self.ls2_str (), self.devel, self.file)
        if self.therest:
            uri += '/' + self.therest
        return uri

    def __str__ (self):
        uri = '/%s%s' % (self.mode, self.path_info ())
        if self.args:
            uri += '?' + '&'.join ([k+'='+str(self.args[k]) for k in self.args.keys () ])
        return uri

    def str_sans_devel (self):
        return '/%s/%s/%s' % (self.mode, self.jsmode, self.ls2_str ())
        
    def absolute_uri (self):
        return 'http://%s%s' % (self.netloc, str(self))

# Helper functions:
def cond_exec (target_ls, target_exec):
    """
    Execute <target_exec> if the user is allowed to see target_ls.
    <target_exec> is a tuple like this (executable, arg1, arg2, arg3)
    Running <target_exec> will generate the HTML to include into the HTML output.
    During spawn, the GW will check that the page can transition from ls2 to target_ls.
    """
    assert type (target_exec) is tuple, 'target_exec must be a tuple'
    return ('<COND_EXEC labelset="%s" %s>'
            % (encode_labelset (target_ls),
               ' '.join (['exec="%s"' % cgi.escape (a, True) for a in target_exec])))

def cond_inc (target_ls, include_text):
    """
    Include <include_text> if the user is allowed to see target_ls.
    """
    return ('<COND_INC labelset=\'%s\' include=\'%s\'>'
            % (encode_labelset (target_ls), cgi.escape (include_text)))

def encode_labelset (ls):
    if RAW_URLS:
        return ','.join ([l.toRaw ().armor () for l in (ls.get_S(), ls.get_I(), ls.get_O())])
    else:
        return ','.join ([l.freeze().armor32 () for l in (ls.get_S(), ls.get_I(), ls.get_O())]) # 
    
def decode_labelset (s):
    v = s.split (',')
    if len (v) != 3:
        raise ValueError, ('Invalid labelset %s' % cgi.escape (s))
    if RAW_URLS:
        (s, i, o) = [flmo.Label (flmo.RawData (dat=x, armored=True)) for x in v]
    else:
        (s, i, o) = [flmo.Handle(x).thaw () for x in v]
    return flmo.LabelSet (S=s, I=i, O=o)

def illegal_script_name (s):
    for needle in invalid_script_filenames:
        if (s.find (needle) != -1):
            return True
    return False

def illegal_therest (s):
    for needle in invalid_therest_filename:
        if (s.find (needle) != -1):
            return True
    return False
    

def dbg (s):
    sys.stderr.write ("%s\n" % s)
    #pass

def format_error (e, headers=[]):
    import traceback
    sys.stdout.write (''.join ([x + '\r\n' for x in headers]))
    sys.stdout.write ('Content-Type: text/html\r\n\r\n')
    sys.stdout.write ('<pre>%s</pre>\n' % cgi.escape(traceback.format_exc (), 1))
    traceback.print_exc(file=sys.stderr)

def format_error_wsgi (e, headers=[]):
    import traceback

    h = [(a[0], a[1]) for a in map (lambda s: s.split (':', 1), headers) ]
    
    return ('200 OK',
            [('Content-Type', 'text/html')] + h,
            '<pre>%s</pre>\n' % cgi.escape(traceback.format_exc (), 1))

def compound_tagname (user, tagname):
    return '%s:%s' % (user, tagname)

def tagname_suffix (tagname):
    return tagname.partition(':')[2]

def tagname_prefix (tagname):
    return tagname.partition (':')[0]

def get_uid (user=None, env=os.environ):
    if not user:
        try:
            user = env[CLIENT_UN_ENV]
        except KeyError:
            raise WCError ("Client not logged in, dont know which userid to return")

    u = User (user)
    return u.get_id ()

def get_devel_un (env=os.environ):
    return env[DEVEL_UN_ENV]

escapecodes = {
    'lt': '<',
    'gt': '>',
    'amp': '&',
    'quot': '"',
    'nbsp': ' ',
}

def ent2chr(m):
    #m = {
    
    code = m.group(1)
    if code[0] == '#':
        code = code[1:]
        if code.isdigit():
            code = int(code)
        else:
            code = int(code[1:], 16)
        if code<256:
            return chr(code)
    if escapecodes.has_key (code.lower()):
        return escapecodes[code.lower()]
    else:
        return '?' #XXX unichr(code).encode('utf-16le') ??

def unescape (s):
    rxo = cached_re (r'\&(\#x?[0-9a-f]+|%s);' % '|'.join (escapecodes.keys()), re.IGNORECASE)
    return rxo.sub(ent2chr, s)

def make_cookie (mapping, cookie_life=24, env=os.environ):
    import time

    maxage = int (3600 * cookie_life)
    expires = time.time () + maxage
    output = []
    for name, value in (mapping.items ()):
        c = SimpleCookie ()
        c[name] = value
        c[name]['max-age'] = maxage
        c[name]['expires'] = expires
        c[name]['path'] = '/'
        c[name]['domain'] = env['SERVER_NAME']
        output.append (c.output () + '; HttpOnly')
    return '\r\n'.join (output)

def apply_app_filters (env=os.environ):
    if env.has_key (APP_FILTERS_ENV):
        sys.stderr.write ("Installing user imposed app filters: %s\n"
                          % env[APP_FILTERS_ENV])
        filters = env[APP_FILTERS_ENV].split (',')
        for fn in filters:
            flmo.apply_filter (fn, flume.LABEL_I)
        add_filters (filters)

def request_uri (env=os.environ):
    return W5Uri (env=env, uri=env['REQUEST_URI'], netloc=env['HTTP_HOST'])

def referer_uri (env=os.environ):
    if env.has_key ('HTTP_REFERER'):
        return W5Uri (env=env, uri=env['HTTP_REFERER'])
    else:
        return None

def referer_ls (env=os.environ):
    """ Return the referer ls, combined with any new S tags that the
    toolbar added"""

    d = {}
    for v, t in (('HTTP_X_REFERRER_SLABEL', 'S'),
                 ('HTTP_X_REFERRER_ILABEL', 'I'),
                 ('HTTP_X_REFERRER_OLABEL', 'O')):
        if env.has_key (v):
            d[t] = str2label (env[v])
    return flmo.LabelSet (d)

def add_ls (env=os.environ):
    # Get any tags the user added
    add_stags = env.get ('HTTP_X_ADD_STAGS')
    if add_stags:
        slab = str2label (add_stags)
        return flmo.LabelSet (S=slab)
    return None

def target_subframe (env=os.environ):
    v = env.get ('HTTP_X_TARGET_ISSUBFRAME')
    if v == IS_SUBFRAME_TRUE:
        return True
    elif v == IS_SUBFRAME_FALSE:
        return False
    else:
        return None

def subframe_parent_cid (env=os.environ):
    return env.get ('HTTP_X_SUBFRAME_PARENT_CID', None)

def _env_add_devel (env, devel):
    if devel:
        env[DEVEL_UN_ENV] = devel.un
        env[DEVEL_HOMEDIR_ENV] = devel.home_dir ()
    else:
        if DEVEL_UN_ENV in env: del env[DEVEL_UN_ENV]
        if DEVEL_HOMEDIR_ENV in env: del env[DEVEL_HOMEDIR_ENV]


def trusted_env (user, env, devel=None):
    env = env.copy ()
    if user:
        env[CLIENT_UN_ENV] = user.un
        env[CLIENT_HOMEDIR_ENV] = user.home_dir ()
    else:
        if CLIENT_UN_ENV in env: env.pop (CLIENT_UN_ENV)
        if CLIENT_HOMEDIR_ENV in env: env.pop (CLIENT_HOMEDIR_ENV)

    _env_add_devel (env, devel)
    return env

def untrusted_env (user, env, devel=None, filters=[]):
    env = trusted_env (user, env)
    if env.has_key ('HTTP_COOKIE'):
        env.pop ('HTTP_COOKIE')
    for k in [k1 for k1 in env.keys () if k1.endswith ('_TOK') or k1.endswith ('_PW')]:
        env.pop (k)

    _env_add_devel (env, devel)

    if len(filters) > 0:
        env[APP_FILTERS_ENV] = ','.join (filters)
    else:
        if APP_FILTERS_ENV in env: del env[APP_FILTERS_ENV]
        
    return env

def combine_forward_ls (ls1, ls2):
    """
    ls1 is trying to transition to ls2.  If ls1 is able to
    transition to ls2, return ls2.  Otherwise, return a new ls
    based on ls2, except that ls1 is able to transition to the new
    ls.
    """
    if ls1 is None:
        return ls2
    if ls2 is None:
        return ls1
    
    ret = flmo.LabelSet ()
    ret.set_S (ls2.get_S () + ls1.get_S ())
    ret.set_I (ls1.get_I ())
    ret.set_O (flmo.Label (set (ls2.get_O ()) & set (ls1.get_O ())))
    return ret

def get_zone_suffix (env):
    return '.' + env.get ("BFLOW_ZONE_SUFFIX", env['SERVER_NAME'].rsplit ('.', 1)[0])
