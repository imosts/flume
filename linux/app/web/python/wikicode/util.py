import os.path, asyncore, errno, socket, flume, re, wikicode, cgi, sys
import flume.flmos as flmo
from asynchat import fifo
from wikicode.errors import *
from wikicode.const import *
from Cookie import SimpleCookie

FILE_HELPER = '/disk/%s/flume/run/bin/filehelper-static' % os.environ['USER']

# ------- RPC stuff ----------------
sys.path.insert (0, '/var/lib/python-support/python2.5')
from medusa.rpc_client import rpc_connection, fastrpc_proxy
from medusa.rpc_server import fastrpc_channel
sys.path.pop (0)

class GW_RPC_Client (rpc_connection):
    def __init__ (self, _sock):
        self.socket = _sock

def to_rpc_proxy (rpc_fdh):
    fd = flmo.claim (rpc_fdh, "gw rpc socket")
    sock = socket.fromfd (fd, socket.AF_UNIX, socket.SOCK_STREAM)
    os.close (fd)
    rpc_conn = GW_RPC_Client (sock)
    return sock.fileno (), fastrpc_proxy (rpc_conn)

class rpc_channel (fastrpc_channel):
    def __init__ (self, root, conn, map):
        self.root = root
        self.addr = 'rpc_connection'
        self.ac_in_buffer = ''
        self.ac_out_buffer = ''
        self.producer_fifo = fifo()
        asyncore.dispatcher.__init__ (self, conn, map)
        self.pstate = self.STATE_LENGTH
        self.set_terminator (8)
        self.buffer = []
        self.done_cb = None

    def initiate_send (self):
        fastrpc_channel.initiate_send (self)
        if not self.writable () and self.done_cb:
            self.done_cb ()
            self.done_cb = None

    def set_done_cb (self, cb):
        assert self.done_cb is None
        self.done_cb = cb

class rpc_prot (object):
    """ An rpc interface for children to talk to the launcher"""
    def __init__ (self, connection):
        self._connection = connection

class rpc_connection (object):
    prot_type = rpc_prot
    def __init__ (self, fd):
        self.dc_ok = False

        self.sock_map = {} # use our own map so we can run multiple asyncore loops
        self.sock = socket.fromfd (fd, socket.AF_UNIX, socket.SOCK_STREAM)
        os.close (fd) # Because fromfd duplicates fd
        self.rpc_chan = None

    def run (self):
        server_obj = self.prot_type (self)
        self.rpc_chan = rpc_channel (server_obj, self.sock, self.sock_map)
        asyncore.loop (map=self.sock_map)
# -----------------------------------

rx_cache = {}
def cached_re (*args):
    key = args
    if not rx_cache.has_key (key):
        rx_cache[key] = re.compile (*args)
    return rx_cache[key]
# -----------------------------------

def do_it (fn, interpose):
    orig_interpose = flmo.get_libc_interposing ()
    if interpose != orig_interpose:
        flmo.set_libc_interposing (interpose)
    try:
        return fn ()
    finally:
        if interpose != orig_interpose:
            flmo.set_libc_interposing (orig_interpose)

def file_exists (fn, interpose):
    return do_it (lambda : os.path.exists (fn), interpose)

def _stat (filename, interpose):
    return do_it (lambda : os.stat (filename), interpose)

def read_file (filename, interpose=True):
    def fn (interpose):
        f = open (filename, 'r')
        data = f.read ()
        f.close ()
        return data
    return do_it (lambda : fn (interpose), interpose)

def should_copy (src, dst, src_interpose=True, dst_interpose=True):
    """ return True if <dst> does not exist or is older than <src> """
    srcres = _stat (src, src_interpose)
    try:
        dstres = _stat (dst, dst_interpose)
    except OSError, e:
        if e.errno != errno.ENOENT:
            raise
        return True
    return srcres.st_mtime > dstres.st_mtime

def copy_file (src, dst, file_ls, src_interpose=True, dst_interpose=True,
               read_helper=False, write_helper=False):
    orig_interpose = flmo.get_libc_interposing ()

    # Read the file
    if read_helper and src_interpose:
        data = helper_read (src)
    else:
        data = read_file (src, src_interpose)

    def _get_dirls ():
        return flmo.stat_file (os.path.dirname (dst))

    # Write the file
    if write_helper and dst_interpose:
        oldls = flmo.get_labelset ()
        dirls = _get_dirls ()
        flmo.set_label2 (S=dirls.get_S())
        flmo.set_label2 (I=dirls.get_I())
        dirls.set_O (flmo.get_label(flume.LABEL_O))
        helper_write (dst, data, proc_ls=dirls, file_ls=file_ls)
        flmo.set_label2 (S=oldls.get_S ())
        flmo.set_label2 (I=oldls.get_I ())

    elif dst_interpose:
        oldls = flmo.get_labelset ()
        dirls = _get_dirls ()
        flmo.set_label2 (S=dirls.get_S())
        flmo.set_label2 (I=dirls.get_I())

        f = flmo.open (dst, 'wct', 0755, labelset=file_ls, endpoint=file_ls)
        f.write (data)
        f.close ()

        flmo.set_label2 (S=oldls.get_S ())
        flmo.set_label2 (I=oldls.get_I ())
    else:
        flmo.set_libc_interposing (dst_interpose)
        f = open (dst, 'wct', 0755)
        f.write (data)
        f.close ()
        flmo.set_libc_interposing (orig_interpose)

def check_mkdir_label (name, mode, dirls):
    if name == '':
        return


    oldls = flmo.get_labelset ()
    # Make the parent
    parent = os.path.dirname (name)
    if not os.path.exists (parent):
        check_mkdir_label (parent, mode, dirls)

    # Set our labels so we can check if the dir exists, and then mkdir if necessary
    flmo.set_label2 (S=oldls.get_S() + dirls.get_S ())
    flmo.set_label2 (I=oldls.get_I () + dirls.get_I ())
    if not os.path.exists (name):
        #print "mkdir %s with %s myls %s" % (name, dirls, flmo.get_labelset ())
        flmo.mkdir (name, mode, dirls)
    flmo.set_label2 (S=oldls.get_S())
    flmo.set_label2 (I=oldls.get_I ())


def getformlist (form, varname):
    if type (form[varname]) in (tuple, list):
        return [x.value for x in form[varname]]
    else:
        return [form[varname].value,]

def get_additional_caps (my_ls, target_ls, typs="SIO"):
    add_o = []

    for typ in (typs):
        lab = target_ls.toDict ()[typ]
        for tag in lab:
            if (tag not in my_ls.toDict ()[typ] and
                set (tag.toCapabilities ()) <= my_ls.get_O ().toSet ()):
                add_o.extend (tag.toCapabilities ())
    return add_o

def add_caps (ls):
    """ Adds any capabilities needed to have a child with labelset = <ls> """
    add_o = get_additional_caps (flmo.get_labelset (), ls)
    flmo.set_label2 (O=flmo.get_label (flume.LABEL_O) + add_o)


header_rxx = r'^(\S+):\s+(.*)$'
def parse_headers (headers):
    """ Return a dictionary of HTTP header values """

    current_val = None
    hlist = []
    for line in headers.splitlines ():
        m = cached_re (header_rxx).match (line)
        if m:
            if current_val:
                hlist.append ((key, current_val))
                
            key = m.group (1).lower ()
            current_val = m.group (2)
        else:
            subline_rxx = r'^\s+(.*)$'
            m2 = cached_re (subline_rxx).match (line)
            if m2:
                current_val += ' %s' % (m.group (2),)
            else:
                raise WCExtensionError ("Error in headers line = '%s'" % cgi.escape (line))

    if current_val:
        hlist.append ((key, current_val))
    return hlist

def parse_content_type (value):
    'text/html; charset=utf-8'
    a = [s.strip () for s in value.split (';')]
    if len (a) < 1:
        raise WCExtensionError ("Invalid content-type: '%s'" % (value))

    typ = a[0].lower ()
    params = {}
    for s in a[1:]:
        k, v = s.split ('=', 1)
        params [k.strip ().lower ()] = v.strip ().lower ()
    return typ, params


def parse_response (s):
    response_rxx = (r'^(.*?)\r\n\r\n(.*)$', re.DOTALL)
    m = cached_re (*response_rxx).match (s)
    if m is None or len (m.groups ()) < 2:
        raise WCExtensionError, 'Invalid HTTP response from extension: [%s]' % s

    hlist = parse_headers (m.group (1))
    return m.group (1), m.group (2), hlist

def cgi_to_wsgi (s):
    allheaders, content, hlist = parse_response (s)
    try:
        status_idx = [h[0] for h in hlist].index ('status')
        respcode = hlist[status_idx][1]
        hlist.pop (status_idx)
    except ValueError:
        respcode = HTTP_OK
    return respcode, hlist, [content]


def spawn_helper (argv, proc_ls=None, env=None):
    (stdin_fd, stdin_h)   = flmo.socketpair ()
    (stdout_fd, stdout_h) = flmo.socketpair ()
    (stderr_fd, stderr_h) = flmo.socketpair ()

    if proc_ls:
        for fd in (stdin_fd, stdout_fd, stderr_fd):
            flmo.set_fd_label (flume.LABEL_S, fd, proc_ls.get_S())
            flmo.set_fd_label (flume.LABEL_I, fd, proc_ls.get_I())

    ch = flmo.spawn (argv[0], argv, env=env, confined=True,
                      claim=[stdin_h, stdout_h, stderr_h],
                      labelset=proc_ls)

    fin = os.fdopen (stdin_fd, 'w')
    fout = os.fdopen (stdout_fd, 'r')
    ferr = os.fdopen (stderr_fd, 'r')
    return ch, fin, fout, ferr

def helper_read (path):
    try:
        # I dont know why this fails sometimes, but it does
        ls = flmo.stat_file (path)
        ls.set_O (None)
    except OSError:
        ls = None
        
    #print "helper_read %s spawning ls %s" % (path, flmo.get_labelset ())
    argv = [FILE_HELPER, 'read', path]
    ch, fin, fout, ferr = spawn_helper (argv)

    #print "helper_read child is pid %s" % ch

    dat = fout.read ()
    map (lambda f: f.close (), (fin, fout, ferr))

    (pid, status, visible) = flmo.waitpid ()
    #print "helper_read %s returned %d" % (path, status)
    
    if status:
        raise OSError ("could not read file %s, %d" % (path, status))
    return dat

def helper_write (path, dat, proc_ls=None, file_ls=None):
    if os.path.exists (path):
        pathls = flmo.stat_file (path)
        oldls = flmo.get_labelset ()
        flmo.set_label2 (S=pathls.get_S ())
        flmo.set_label2 (I=pathls.get_I ())
        flmo.unlink (path)
        flmo.set_label2 (I=oldls.get_I ())
        flmo.set_label2 (S=oldls.get_S ())


    if not file_ls:
        if proc_ls:
            file_ls = proc_ls
        else:
            file_ls = flmo.get_labelset ()
    
    argv = [FILE_HELPER, 'write', path]
    argv += [file_ls.get_S ().freeze ().armor32 (),
             file_ls.get_I ().freeze ().armor32 (),
             file_ls.get_O ().freeze ().armor32()]
    
    ch, fin, fout, ferr = spawn_helper (argv, proc_ls)
    fin.write (dat)
    map (lambda f: f.close (), (fin, fout, ferr))

    (pid, status, visible) = flmo.waitpid ()
    #print "write returned %d %s %s" % (status, path, proc_ls)
    
    #assert os.path.exists (path)
    if status:
        raise OSError ("could not write file %s, %d" % (path, status))

def str2label (s):
    """ String tags are hexidecimal tag values """
    tags_str = s.strip ().strip ('[]').split (',')
    tags = [flmo.Handle (int (t, 16)) for t in tags_str if t != '']
    return flmo.Label (tags)

def set_cookies (un, gid, tpw, cookie_life=DEF_COOKIE_LIFE, env=os.environ):
    mapping = {COOKIE_UN_ENV: un,
               COOKIE_GID_ENV: gid,
               COOKIE_TPW_ENV: tpw }
    return wikicode.make_cookie (mapping, cookie_life, env)

def clear_cookies (env=os.environ):
    return set_cookies ('', '', '', 0, env)

def read_cookies (env=None):
    if env is None:
        env = os.environ

    try:
        cook = SimpleCookie(env['HTTP_COOKIE'])
        un = cook[COOKIE_UN_ENV].value
        gid = cook[COOKIE_GID_ENV].value
        tpw = cook[COOKIE_TPW_ENV].value

    except KeyError:
        un = gid = tpw = None
    return (un, gid, tpw)


