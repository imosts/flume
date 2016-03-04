
"""
frksrv.py

    A forking server that demonstrates how to build a Web server with the
    fork, rather than spawn, model.

    To use, the 'master' creates an instance of the ForkServerIface
    using the filename of the ForkServer implementation.  The master
    calls 'ForkServer.call' which causes the forkserver to fork a new
    child.  The master communicates directly with the child using
    args, environment, and standard streams.

"""

import flume.flmos as flmo
import flume.util as flmu
import flume
import sys
import os
import cStringIO as StringIO
import cPickle as pickle
import traceback

class Child (object):
    def __init__ (self, child_ctl_tok, ls):
        self._child_ctl_tok = child_ctl_tok
        self._ls = ls

    def run (self):
        try:
            self.open_socket ()
            self.set_labels ()
            self.handle_forksrv_input ()
            rc = self.serve (self.args)
        except Exception, e:
            s = traceback.format_exception(sys.exc_type,sys.exc_value, sys.exc_traceback)
            flmo.flume_debug_msg ("Error in forked child: %s" % s)

        # If we don't explicitly close these we get an EBADF error
        # when this child exits.
        sys.stdin.close ()
        sys.stdout.close ()
        sys.stderr.close ()        

        sys.exit (rc)

    def open_socket (self):
        self._infd = flmo.claim (self._child_ctl_tok)
        self._infh = os.fdopen (self._infd, "r")

    def set_labels (self):
        self._ls.apply ()

    def handle_forksrv_input (self):
        pass_args = pickle.load (self._infh)
        self._infh.close () # close so we can get fd = 0 for stdin
        fds = [flmo.claim (h) for h in pass_args['claim']]

        sys.stdin = os.fdopen (fds[0], 'r')
        sys.stdout = os.fdopen (fds[1], 'w')
        sys.stderr = os.fdopen (fds[2], 'w')

        self.set_os_env (pass_args['env'])
        self.args = pass_args['args']

    def set_os_env (self, env):
        remove = set (os.environ.items ()) - set (env.items ())
        for k, v in remove:
            del os.environ[k]

        add = set (env.items ()) - set (os.environ.items ())
        for k, v in add:
            os.environ[k] = v

    def serve (self, args):
        raise NotImpelementedError, "abstract virtual method called"

    @classmethod
    def close_fds (cls):
        """ Close all fds that the child opened during import phase """
        # XXX We should change the API so that the application
        # specific code subclasses the ForkServer rather than
        # subclassing the Child class.  Then we could make this method
        # part of the ForkServer class, and it wouldn't have to be a
        # classmethod in the Child that needs to know what files get
        # opened during the imports in client_code.main ().
        pass
    
class RequestError (Exception):
    def __init__ (self, value):
        self._value = value
    def __str__ (self):
        return repr (self._value)

class ForkServer:
    """A server the implements the basic of the Flume ForkServer concept.
    For every incoming request, the server will fork, set up labels, and
    then run the code passed in."""

    # BE CAREFUL, Any prints to stderr will hang the fork server if
    # you run with spawner debugging turned off.  We should figure out
    # how to fix this.  Maybe replaced sys.stderr with a StringIO.

    def __init__ (self, cli):
        self._child_klass = cli
        self._child_klass.close_fds ()
        self._close_fds = self.get_open_std_fds ()

    def get_open_std_fds (self):
        open_fds = []
        leave_alone = [flmo.myctlsock ()]

        for fd in [x.fileno () for x in [sys.stdin, sys.stdout, sys.stderr]]:
            if fd not in (leave_alone):
                try:
                    os.fstat (fd)
                    open_fds.append (fd)
                except OSError:
                    pass
        return open_fds

    def start (self, token):
        fd = flmo.claim (token, "fork server listen handle")
        self._close_fds.append (fd)
        
        token = None
        fh = os.fdopen (fd, "r")
        go = True
        while go:
            line = fh.readline ()
            if len (line) == 0:
                go = False
            else:
                line = line.strip ()
                self.fork_new (line)

    def parse (self, x):
        """Expect a line of the form:
        
              <handle>,<labelset>

        Where the handle and labelset are both the armored raw data of
        those Flume objects in the sender's world."""

        try:
            parts = x.split (',')
            objects = [flmo.Handle, flmo.LabelSet]

            return tuple ([ objects[i] (flmo.RawData ().dearmor (d)) 
                            for (i,d) in enumerate (parts) ])
        except IndexError, e:
            raise RequestError, "not enough fields found"
        except ValueError, e:
            raise RequestError, "bad values in request"
        except flume.RawError, e:
            raise RequestError, "bad raw fields"

    def fork_new (self, params):
        try:
            (child_ctl_tok, ls) = self.parse (params)
        except RequestError, e:
            sys.stderr.write ("Bad request; aborting: %s\n" % str (e))
            return False

        close_fds = list (self._close_fds)
        chld = flmo.fork (close_fds, True)
        if chld == 0:
            self._child_klass (child_ctl_tok, ls).run ()
            sys.exit (0)

        elif chld < 0:
            sys.stderr.write ("Oh shit! Fork failed :(\n")
            return False

        child_ctl_tok = None
        ls = None

        return True

class ForkServerIface:
    """A convenient interface to a fork server.  Can use some work,
    but we'll use it for now.  The instance of this class remains in
    the master's process.  The master uses it to create and destroy
    the forkserver.  """

    def __init__ (self):
        self._fh = None

    def shutdown (self):
        self._fh.close ()
        flmo.waitpid (h=self._ch)

    def launch (self, path, frksrv_env=None, frksrv_ls=None):
        (srvfd, h) = flmo.socketpair ('master to forkserver')
        self._fh = os.fdopen (srvfd, "w")

        if frksrv_ls is None:
            frksrv_ls = flmo.LabelSet ()

        args = [ sys.executable, path, h.armor32 () ]
        self._ch = flmo.spawn (prog=args[0], argv=args,
                               env=frksrv_env, confined=False,
                               labelset=frksrv_ls)

    def call (self, ls=None, args=[], env=os.environ):
        """ Returns a tuple of file handles for std streams connected
        to the new child """

        if ls is None:
            ls = flmo.get_labelset ()

        # Setup a socket on which we can talk to the new child
        (child_fd, h) = flmo.socketpair ('child_ctl')
        ls.apply_ep (child_fd)

        # Tell fork server to fork a new child with claim socket <h>
        # and labelset <ls>
        args2 = ','.join ([ x.toRaw ().armor () for x in [ h, ls ] ])
        self._fh.write (args2 + "\n")
        self._fh.flush ()


        # Setup standard streams for the child
        socknames = (('stdin2', 'w'), ('stdout2', 'r'), ('stderr2', 'r'))
        streams = [flmo.socketpair (n[0]) for n in socknames]
        map (ls.apply_ep, [p[0] for p in streams])
        fds = [p[0] for p in streams]
        fds_h = [p[1] for p in streams]
        modes = [n[1] for n in socknames]

        std_streams = [os.fdopen (fd, m) for fd, m in zip (fds, modes)]

        # Send arguments to the new child
        pass_args = { 'args'   : args,
                      'env'    : env,
                      'claim'  : [h.armor32 () for h in fds_h],
                      }

        tmp_file = StringIO.StringIO ()
        pickle.dump (pass_args, tmp_file)
        child_ctl = os.fdopen (child_fd, 'w')
        child_ctl.write (tmp_file.getvalue ())
        child_ctl.close ()

        return std_streams
        
