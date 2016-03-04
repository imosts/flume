import flume, wikicode
import flume.flmos as flmo
import cStringIO as StringIO
import cgi, os, os.path, sys
from wikicode.db.user import User, devel_from_env
from wikicode.errors import *
from wikicode.util import file_exists
from wikicode.const import *

def regular_spawn (ls, argv, env):
    """ Makes sockets for standard streams and returns standard
    streams.  (makes spawn look like the forksrv api)"""

    (stdin_fd, stdin_h)   = flmo.socketpair ()
    (stdout_fd, stdout_h) = flmo.socketpair ()
    (stderr_fd, stderr_h) = flmo.socketpair ()
    fds = [stdin_fd, stdout_fd, stderr_fd]
    # Set endpoint labels so we can read from child.
    for fd in fds:
        flmo.set_fd_label (flume.LABEL_S, fd, ls.get_S())
        flmo.set_fd_label (flume.LABEL_I, fd, ls.get_I())

    ch = flmo.spawn (argv[0], argv, env=env, confined=True,
                     claim=[stdin_h, stdout_h, stderr_h],
                     labelset=ls)

    fin = os.fdopen (stdin_fd, 'w')
    fout = os.fdopen (stdout_fd, 'r')
    ferr = os.fdopen (stderr_fd, 'r')
    return fin, fout, ferr

forksrvs = {}
def fork_spawn (ls, argv, env, frksrv_ls):
    """
    Returns standard streams.
    Assume argv[2] == executable python script
    """
    cmd = argv[2]

    srv = forksrvs.get (cmd)
    if srv is None:
        import flume.frksrv as frk        
        srv = frk.ForkServerIface ()
        devel = devel_from_env (env=env) # preserve developer info
        srv.launch (cmd, frksrv_env=wikicode.untrusted_env (None, env, devel), frksrv_ls=frksrv_ls)
        forksrvs[cmd] = srv

    # Remove non-string items from env, because we can't serialize them.
    removeme = []
    for k, v in env.items ():
        if type (v) != str:
            removeme.append (k)
    for k in removeme:
        del env[k]

    fin, fout, ferr = srv.call (ls=ls, env=env)

    #srv.shutdown ()

    return fin, fout, ferr

def spawn_child (ls, argv, env=None, send_stdin=None, rpc_conn_type=None,
                 profile=False, frksrv=False, frksrv_ls=None):
    if not file_exists (argv[0], True):
        raise WCError, 'Tried to launch %s, but could not stat file' % argv[0]

    if not env:
        env = os.environ.copy ()

    if rpc_conn_type:
        (rpc_fd, rpc_h) = flmo.socketpair ()
        env[RPC_TAG_ENV] = str (rpc_h.armor32 ())
        flmo.set_fd_label (flume.LABEL_S, rpc_fd, ls.get_S())
        flmo.set_fd_label (flume.LABEL_I, rpc_fd, ls.get_I())
    
    #wikicode.dbg ('spawning %s' % (argv,))
    #wikicode.dbg ('launcher label is %s' % flmo.get_labelset ())
    #wikicode.dbg ('child label is %s' % ls)
    #wikicode.dbg ('child environment %s' % env)

    if (frksrv):
        fin, fout, ferr = fork_spawn (ls, argv, env, frksrv_ls)
    else:
        fin, fout, ferr = regular_spawn (ls, argv, env)

    # send form information to child (XXX should also be async)
    if send_stdin:
        fin.write (send_stdin)
    fin.close ()
    
    if rpc_conn_type:
        rpc_conn = rpc_conn_type (ls, rpc_fd)
        rpc_conn.run ()

    out = fout.read ()
    err = ferr.read ()
    fout.close ()
    ferr.close ()

    if frksrv:
        status = 0
    else:
        (pid, status, visible) = flmo.waitpid ()

    if rpc_conn_type:
        return out, err, status, rpc_conn
    else:
        return out, err, status
        
