#!/usr/bin/python
import cgi, os.path, sys, string, re, exceptions, errno, os
import cStringIO as StringIO
import flume, wikicode
import flume.flmos as flmo
import flume.util as flmu
from flume.labelsetdesc import LabelSetDesc
from wikicode.sanitizer import sanitize_response, sanitize_response_lite
from wikicode.db.user import User
from wikicode.spawn import spawn_child
from wikicode.errors import *
from wikicode.const import *
from wikicode.capabilities import all_env_vars
from wikicode.util import rpc_prot, rpc_connection, add_caps, cgi_to_wsgi, do_it, clear_cookies, read_cookies
from wikicode.toolbar import Toolbar
from wikicode.prepare import run_prepare
from wikicode.db.user import ADD, REMOVE

DEFAULT_TRUSTED = 'wcmain.py'
DO_SANITIZE = True

PROFILE = False

if PROFILE:
    from flume.profile import start, total, print_delta

class child_rpc_prot (rpc_prot):
    def new_cid (self):
        return self._connection.new_cid ()

    def may_read (self, ls):
        ls = flmo.LabelSet (ls, armoredraw=True)
        return self._connection.may_read (ls)

    def get_all_readable (self):
        return self._connection.get_all_readable ()

    def get_url (self, url):
        return self._connection.get_url (url)

    def send_email (self, username, msg):
        return self._connection.send_email (username, msg)

    def get_friendlist (self):
        return self._connection.get_friendlist ()

class child_rpc_connection (rpc_connection):
    prot_type = child_rpc_prot

    def __init__ (self, launcher, user, child_ls, *args):
        rpc_connection.__init__ (self, *args)
        self.launcher = launcher
        self.user = user
        self.child_ls = child_ls

    def new_cid (self):
        return self.user.new_context_id (parent_cid=self.launcher.uri.context_id ())

    def may_read (self, ls):
        # Respond with a boolean if the user is running in anon mode.
        # Otherwise return None because, this could leak ACL contents.
        if self.user.get_tag ('anon') in self.child_ls.get_S ():
            return self.launcher.user_may_read (ls)
        else:
            return None

    def get_all_readable (self):
        anon_tag = self.user.get_tag ('anon')
        gcap = self.user.get_tag ('gtag').toCapability (flume.CAPABILITY_GROUP_SELECT |
                                                        flume.HANDLE_OPT_PERSISTENT |
                                                        flume.HANDLE_OPT_GROUP)
        if (anon_tag in self.child_ls.get_S () or
            gcap in self.child_ls.get_O ()):
            return [h.val () for h in self.launcher.get_all_readable ()]
        else:
            return None

    def get_url (self, url):
        if len (self.child_ls.get_S ()) == 0:
            import urllib
            f = do_it (lambda : urllib.urlopen (url), False)
            return f.read ()
        else:
            return None

    def send_email (self, username, msg):
        u = User.object_withkey (username)
        if self.launcher.user_may_read (self.child_ls, username):
            fromaddr = "%s@w5.com" % self.user.un
            toaddr = u.get_email ()

            def foo ():
                import smtplib
                server = smtplib.SMTP('localhost')
                server.set_debuglevel(1)
                server.sendmail(fromaddr, toaddr, msg)
                server.quit()
            do_it (foo, False)

    def get_friendlist (self):
        """ return the contents of the friends ACL as a list of usernames """
        anon_tag = self.user.get_tag ('anon')
        gcap = self.user.get_tag ('gtag').toCapability (flume.CAPABILITY_GROUP_SELECT |
                                                        flume.HANDLE_OPT_PERSISTENT |
                                                        flume.HANDLE_OPT_GROUP)
        if (self.user.get_tag (FRIEND_ETAG_NAME) in self.child_ls.get_S () or
            anon_tag in self.child_ls.get_S () or
            gcap in self.child_ls.get_O ()):
            return [ r[0] for r in self.user.get_acl_entries (FRIEND_ACL_NAME) ]


class wclauncher (object):
    def __init__ (self, env, acl_cache = {}, tag_cache = {}):
        self.env = env
        self.un = None
        self.gid = None
        self.tpw = None
        self.principal = None
        self.headers = []
        self.saved_stdin = None
        self.uri = None
        self.acl_cache = acl_cache
        self.tag_cache = tag_cache

    def dbg (self, s):
        sys.stderr.write ("wclaunch.py: %s\n" % s)
        #pass

    def duplicate_stdin (self):
        if self.env.has_key ('wsgi.input'):
            self.saved_stdin = self.env['wsgi.input'].read ()
        else:
            self.saved_stdin = sys.stdin.read ()
        buf = StringIO.StringIO ()
        buf.write (self.saved_stdin)
        self.formfields = cgi.FieldStorage (fp=buf)

    def logged_in (self):
        return (self.un is not None)
        
    def start (self):
        self.duplicate_stdin ()

        # If the browser sent session info, req privs and setup principal.
        (self.un, self.gid, self.tpw) = read_cookies (self.env)

        if self.logged_in ():
            flmo.req_privs (flmo.Handle (self.gid), self.tpw)
            self.principal = User (self.un, env=self.env)

            # check that session info is valid
            cookie_gid = flmo.Handle(self.gid)
            userdb_gid = self.principal.get_tag ('gtag').toCapabilities()[0]
            if cookie_gid != userdb_gid:
                self.headers.append (clear_cookies (env=self.env))
                raise InvalidLogin ('Your cookie gid (%s) does not match the '
                                    'user database gid (%s).  The W5 admins probably cleared '
                                    'the user database and you have an old cookie.  '
                                    'Clearing your cookies...' % (repr (cookie_gid), repr (userdb_gid)))

    def user_may_transition (self, ls1, ls2):
        """ Return true if a user may transition from a page with
        labelset <ls1> to a page with labelset <ls2>"""

        # XXX We should check that linking from one application to
        # another changes the I capabilities.
        
        return ((ls1.get_S () <= ls2.get_S ()) and
                (ls1.get_O () >= ls2.get_O ()))

    def get_user_tags (self, username=None):
        if username:
            k = username
        else:
            k = self.principal.un
            
        if not self.tag_cache.has_key (k):
            u = User.object_withkey (k, env=self.env)
            self.tag_cache[k] = [x[0] for x in u.get_tags (flags=('pe', 'pr'))]
        return self.tag_cache[k]

    def acl_says_ok (self, tag, username=None):
        if username:
            recipient = username
        else:
            recipient = self.principal.un
        if (not self.acl_cache.has_key (recipient) or
            not self.acl_cache[recipient].has_key (tag)):

            if not self.acl_cache.has_key (recipient):
                self.acl_cache[recipient] = {}

            owner_id = User.get_tag_ownerid (tag, env=self.env)
            owner = User.object_withid (owner_id, env=self.env)
            owner.set_env (self.env)
            self.acl_cache[recipient][tag] = owner.get_acl_decision (tag, recipient)
        return self.acl_cache[recipient][tag]

    def user_may_read (self, ls, username=None):
        """ Make declassification decisions """
        # XXX Optimize: We should cache these results across all gateway instances.
        diff = set(ls.get_S ()) - set (self.get_user_tags (username=username))
        
        lsd = LabelSetDesc (CAPSET=['ENV: MASTERGTAG_CAP, MASTERGTAG_TOK'], env=self.env)
        lsd.acquire_capabilities ()
        for t in diff:
            if not self.acl_says_ok (t, username=username):
                return False
        return True

    def get_all_readable (self):
        readable = self.principal.get_all_readable_tags ()

        # Remember those results
        k = self.principal.un
        if not self.acl_cache.has_key (k):
            self.acl_cache[k] = {}
        for t in readable:
            self.acl_cache[k][t] = True
        # XXX We should also cache that we called get_all_readable so
        # we dont have to do it again.

        readable += self.get_user_tags ()
        return readable
            

    def handle_trusted (self, frksrv=False):
        if not self.referer_is_trusted () and self.uri.file is not None:
            raise WCError ("Untrusted apps can only link to the homepage, not to %s" % self.uri)

        # Don't need to check context ids because we're going to a
        # trusted page.
        if self.uri.context_id () is not None:
            raise WCError ("Non-empty context-id, URIs for trusted apps "
                           "should have empty context_id")

        if self.uri.file is None:
            self.uri.file = DEFAULT_TRUSTED

        script_file = os.path.sep.join ([self.env['PYTHONBIN'],
                                         wikicode.TRUSTED_WORKER_UNAME,
                                         self.uri.file])
        child_labs = flmo.get_labelset ()

        self.print_time ('before spawn')

        args = [wikicode.PYTHON, '-S', script_file]

        # use Frozen wcmain.py
        #args = [os.path.join (self.env['PYTHONBIN'], wikicode.TRUSTED_WORKER_UNAME, 'wcmain')]

        out, err, status = spawn_child (child_labs, args,
                                        env=wikicode.trusted_env(self.principal, self.env),
                                        send_stdin=self.saved_stdin, profile=PROFILE,
                                        frksrv=frksrv, frksrv_ls=flmo.get_labelset ())
        self.print_time ('after spawn')
        sys.stderr.write (err)
        self.page_ls = flmo.LabelSet ()
        return (out)

    def handle_toolbar (self):
        if not self.referer_is_trusted ():
            raise WCError ('Untrusted apps may not link to the toolbar')

        env = wikicode.trusted_env (self.principal, self.env)
        buf = StringIO.StringIO ()
        buf.write (self.saved_stdin)
        toolbar = Toolbar (stdin_obj=buf, env=env)
        self.page_ls = flmo.LabelSet ()
        out = toolbar.run ()
        #sys.stderr.write ("raw toolbar output: %s\n" % out)
        return out

    def anon_mode (self, ls):
        anon_tag = self.principal.get_tag ('anon')
        return anon_tag in ls.get_S ()

    def send_redirect (self, uri):
        return ('Status: %s\r\n' % (wikicode.HTTP_REDIR,) + 
                'Content-Type: text/html; charset=utf-8\r\n'
                'Location: %s\r\n\r\n' % (uri,))

    def referer_is_trusted (self):
        if self.referer is None:
            return False
        return self.referer.netloc == '%s:%s' % (self.env['SERVER_NAME'], self.env['SERVER_PORT'])

    def check_script_security (self, dst_ls):
        """
        If the client cannot transition to dst_ls, raise an exception.

        If the client can transition to dst_ls, but gave us a old cid,
        send new URI to which the client should redirect.

        If the client cannot transition to dst_ls, return a new ls
        that the client would be able to transition to.

        Otherwise, return None
        """
        ret_val = None
        self.print_time ("security1")
        if self.referer is None:
            raise WCError ("Requests must have referer field")

        # If the referer page was a trusted page (with referer =
        # host:port, without a context id) then accept the
        # destination context id.
        if self.referer_is_trusted ():
            self.print_time ("security1a")
            if self.uri.context_id () is None:
                raise WCError ("destination context_id should be non-null!, uri: %s" % self.uri)
            self.print_time ("security1b")

            # add in any extra tags from the context.
            context_ls, uri = self.principal.get_context (self.uri.context_id ())
            ret_val = dst_ls = wikicode.combine_forward_ls (context_ls, dst_ls)

        else:
            # Otherwise, the referer is an untrusted page.
            # The referer CID must be defined
            self.print_time ("security2")
            if self.referer.context_id () is None:
                raise WCError ("referer context_id should not be null!")
            elif self.uri.context_id () is None:
                raise WCError ("dest context_id should not be null!")

            self.print_time ("security3")
            # Check if user is allowed to read all tags in destination page.
            if not self.user_may_read (dst_ls):
                # Blackhole the context so it can't leak ACL knowledge
                cid = self.referer.context_id ()
                self.principal.context_addremove (flume.LABEL_S, ADD, cid, [self.principal.get_tag ('etag')])
                raise WCError ("You are not allowed to read data with this labelset %s" % dst_ls)

            self.print_time ("security4")
            uri_ctx = self.uri.context_id ()
            if not self.principal.context_exists (uri_ctx):
                raise WCError ("You passed an invalid CID %s" % uri_ctx)
            elif self.principal.context_pending (uri_ctx):
                # CID exists, but hasn't been used yet.
                # Remember that the referer is the parent of this new context
                self.principal.set_context (uri_ctx, parent_cid=self.referer.context_id ())
            else:
                # the dst CID exists and is being used
                if ((self.uri.js_on () != self.referer.js_on ()) or
                    (uri_ctx != self.referer.context_id ())):
                    # client tried to either
                    #  - transition from a JS page to a non-JS page (or vice-versa) with an old CID
                    #     We change CIDs so that the referer cannot read
                    #     data from the new page's DOM since a non-JS page
                    #  - transition from one CID to a different, old CID --> Redirect to a new CID
                    #     Changing from c1 to existing c2 can transfer
                    #     data from c1 to c2, and the two contexts may
                    #     have different labels.
                    self.uri.reset_context_id (self.principal, parent_cid=self.referer.context_id ()) # Set parent_cid
                    ret_val = self.uri
                else:
                    # client is linking to the same CID (thats ok,
                    # we'll update our CID labelset before this function returns)
                    pass

            self.print_time ("security5")
            if ret_val is None:
                # Figure out what the referer's LS was
                ref_ls, uri = self.principal.get_context (self.referer.context_id ())
                if not self.referer.js_on ():
                    # for non-js pages, combine the context_ls with the uri's ls1
                    ref_ls = wikicode.combine_forward_ls (ref_ls, self.referer_ls)

                # Is the transition from referer to dst legal?
                if not self.user_may_transition (ref_ls, dst_ls):
                    ret_val = dst_ls = wikicode.combine_forward_ls (ref_ls, dst_ls)

                # If the referer is a JS page, then we have to update the
                # referer's CID with new S tags.
                if self.referer.js_on ():
                    self.principal.set_context (self.referer.context_id (), dst_ls,
                                                self.uri.absolute_uri ())

        self.print_time ("security6")
        # Save the new CID's labelset, unless we're redirecting the client.
        if not isinstance (ret_val, wikicode.W5Uri):
            self.principal.set_context (self.uri.context_id (), dst_ls,
                                        self.uri.absolute_uri ())

        self.print_time ("security7")
        return ret_val

    def handle_untrusted (self, interpreter=None, frksrv=False):
        # If the user added tags, run prepare
        if self.add_ls:
            cid = self.uri.context_id ()
            etags = self.add_ls.get_S ().toList ()
            out, err, status = run_prepare (self.principal, cid, etags, self.env)
            self.principal.context_addremove (flume.LABEL_S, ADD, cid, etags)

        child_ls = self.to_ls

        # Security checks
        ret_val = self.check_script_security (child_ls)
        if isinstance (ret_val, wikicode.W5Uri):
            if self.env['REQUEST_METHOD'] == 'POST':
                raise WCError ('App gave an old CID (%s) for a POST request, '
                               'you probably need to the form to get a '
                               'fresh CID' % (self.uri.context_id (),))
            self.page_ls = self.referer_ls
            return self.send_redirect (ret_val.absolute_uri ())
        elif isinstance (ret_val, flmo.LabelSet):
            child_ls = ret_val

        # Get developer & install user filters
        developer = User (self.uri.devel, env=self.env)
        script_file = os.path.sep.join ((developer.script_loc (), self.uri.file))
        filters = []
        if wikicode.IMODE & wikicode.IMODE_APP:
            filters = self.principal.get_app_filters (devel=developer.un,
                                                      script_name=self.uri.file)
            
        if USE_DEVEL_WCAPS:
            # Provide the developer's wcap
            devel_wcap = developer.get_tag ('wtag')
            child_ls.set_O (child_ls.get_O () + devel_wcap)

            if frksrv:
                olab = flmo.Label ([devel_wcap])
                frksrv_ls = flmo.LabelSet (O=olab)
            else:
                frksrv_ls = None

        # Setup child env
        child_env = wikicode.untrusted_env (self.principal, self.env,
                                            developer, filters)

        if self.uri.js_on ():
            sanitize = sanitize_response_lite
        else:
            sanitize = sanitize_response

        # Setup child's RPC connection
        rpc_constr = lambda ls, fd: child_rpc_connection (self, self.principal,
                                                          child_ls, fd)
        # setup spawn arguments
        argv = []
        if interpreter:
            argv = interpreter
        argv.append (script_file)

        # For minimum overhead benchmark
        #argv = ['/usr/bin/nullcgi-static']
        
        out = self.run_app (child_ls, argv, child_env, self.saved_stdin,
                            rpc_constr, PROFILE, sanitize,
                            frksrv, frksrv_ls)

        # XXX If the child changed it's label, update the context_id
        # labelset here
        return (out)

    def handle_trusted_app (self, interpreter=None, frksrv=False):
        #if not self.referer_is_trusted () and self.uri.file is not None:
        #    raise WCError ("Untrusted apps can only link to the homepage, not to %s" % self.uri)

        child_ls = flmo.get_labelset ()
        
        # Get developer & install user filters
        developer = User (self.uri.devel, env=self.env)
        script_file = os.path.sep.join ((developer.script_loc (), self.uri.file))
        filters = []
        if wikicode.IMODE & wikicode.IMODE_APP:
            filters = self.principal.get_app_filters (devel=developer.un,
                                                      script_name=self.uri.file)
        if frksrv:
            frksrv_ls = flmo.get_labelset ()
        child_env = wikicode.trusted_env(self.principal, self.env, developer)
        sanitize = None
        rpc_constr = lambda ls, fd: child_rpc_connection (self, self.principal,
                                                          child_ls, fd)
        # setup spawn arguments
        argv = []
        if interpreter:
            argv = interpreter
        argv.append (script_file)
        
        return self.run_app (child_ls, argv, child_env, self.saved_stdin,
                             rpc_constr, PROFILE, sanitize,
                             frksrv, frksrv_ls)

    def run_app (self, child_ls, argv, child_env, saved_stdin,
                 rpc_constructor, profile, sanitize,
                 frksrv, frksrv_ls):

        # Launcher's capabilities
        lsd = LabelSetDesc (CAPSET=['ENV: MASTERGTAG_CAP, MASTERGTAG_TOK'],
                            env=self.env)
        lsd.acquire_capabilities ()
        oldls = flmo.get_labelset ()
        add_caps (child_ls)

        try:
            ret = spawn_child (child_ls, argv, env=child_env,
                               send_stdin=self.saved_stdin,
                               rpc_conn_type=rpc_constructor,
                               profile=profile,
                               frksrv=frksrv,
                               frksrv_ls=frksrv_ls)
            out, err, status, rpc_conn = ret
        finally:
            flmo.set_label2 (S=oldls.get_S())
            flmo.set_label2 (I=oldls.get_I())
            flmo.set_label2 (O=oldls.get_O())

        #sys.stderr.write ("raw output: %s\n" % out)
        if len (err):
            sys.stderr.write ("Child error output: [%s]\n" % err.strip ())

        if DO_SANITIZE and sanitize:
            out = sanitize (child_ls,
                            self.env, child_env,
                            out,
                            self.user_may_transition,
                            self.user_may_read)

        self.page_ls = child_ls
        return out

    def handle_static (self, ihome=False):
        to_ls = self.to_ls

        ret_val = self.check_script_security (to_ls)
        if isinstance (ret_val, wikicode.W5Uri):
            if self.env['REQUEST_METHOD'] == 'POST':
                raise WCError ('App gave an old CID (%s) for a POST request, '
                               'you probably need to the form to get a fresh CID'
                               % (self.uri.context_id (),))
            return self.send_redirect (ret_val.absolute_uri ())
        elif isinstance (ret_val, flmo.LabelSet):
            to_ls = ret_val

            print >> sys.stderr, "SELF.URI: %s" % (self.uri)
        if ihome:
            static_file = os.path.sep + os.path.join (self.uri.file, self.uri.therest)
        else:
            devel = User (self.uri.devel)
            static_file = (os.path.sep.join ((devel.script_loc (), self.uri.file)) +
                           self.uri.therest)
            self.dbg ("static file path is: %s" % static_file)

        # XXX If we convert this to FastCGI, it may be problematic
        # that Flume doesn't clean up file endpoints after we close
        # the file.  One options is to spawn a file reading helper
        # which disposes of the file endpoint after it dies.

        # Read it!
        oldls = flmo.get_labelset ()
        lsd = LabelSetDesc (CAPSET=['ENV: MASTERGTAG_CAP, MASTERGTAG_TOK'], env=self.env)
        lsd.acquire_capabilities ()
        add_caps (to_ls)
        
        icaps = []
        for t in to_ls.get_I ():
            icaps.extend (t.toCapabilities ())
        try:
            f = flmo.open (name=static_file, endpoint=to_ls)
            file_data = f.read ()
            f.close ()
        finally:
            #lsd.pop_labelset () # We can't pop the labelset, we have
            #to keep I caps because we can't close the endpoint.
            flmo.set_label2 (S=oldls.get_S())
            flmo.set_label2 (I=oldls.get_I())
            flmo.set_label2 (O=oldls.get_O() + icaps)

        filetype = os.path.splitext (static_file)[1]
        if len(filetype) == 0:
            raise WCError ("Invalid file name requested, no extension: %s" % self.uri.therest)
        filetype = filetype[1:]
        if not CONTENT_TYPES.has_key(filetype):
            raise WCError ("Static file type %s not supported" % filetype)

        self.page_ls = to_ls
        return ('Content-Type: %s\r\n\r\n' % CONTENT_TYPES[filetype] + file_data)

    def check_env_variables (self):
        for v in all_env_vars ():
            if not self.env.has_key (v):
                raise 'Environment variable %s is undefined' % v

    def prof_start (self):
        if PROFILE:
            start ()

    def print_time (self, caption):
        if PROFILE:
            print_delta (caption)

    def print_total (self, caption):
        if PROFILE:
            sys.stderr.write (caption + " %0.3f\n" % total () )

    def _get_response (self):
        self.dbg ('starting')
        self.prof_start ()
        self.check_env_variables ()

        self.start ()
        
        self.uri = wikicode.request_uri (env=self.env)
        self.referer = wikicode.referer_uri (env=self.env)
        self.target_subframe = wikicode.target_subframe (env=self.env)
        self.subframe_parent_cid = wikicode.subframe_parent_cid (env=self.env)
        self.add_ls = wikicode.add_ls (env=self.env) # From the HTTP headers
        self.referer_ls = wikicode.referer_ls (env=self.env) # From the HTTP headers
        # Just add S tags, don't "combine" because combining changes the O label
        if self.add_ls:
            self.referer_ls.set_S (self.referer_ls.get_S () + self.add_ls.get_S ())

        # by default, use the referer's ls as the next page's ls.
        self.to_ls = self.referer_ls
        if self.uri.ls2:
            self.to_ls = self.uri.ls2

        # High level security checks
        if ((self.uri.mode in wikicode.trusted_modes) and self.target_subframe):
            raise WCError ("You may not load a trusted page in a subframe (%s)!"
                           % self.uri.absolute_uri ())
        #if (self.target_subframe and
        #    (self.uri.mode not in wikicode.trusted_modes) and
        #    (self.subframe_parent_cid != self.uri.context_id ())):
        #    raise WCError ("An untrusted page may not have a subframe with a different context")
        

        if False:
            print >> sys.stderr, "REFERER_LS: %s" % (self.referer_ls)
        if False:
            print >> sys.stderr, "ADD_LS: %s" % (self.add_ls)

        try:
            handler = {W5MODE_TRUSTED_PY
                       : self.handle_trusted,
                       W5MODE_TRUSTED_PYWORKER
                       : self.handle_trusted,
                       W5MODE_TRUSTED_TOOLBAR
                       : self.handle_toolbar,
                       W5MODE_TRUSTED_PYAPP_FORK
                       : lambda : self.handle_trusted_app ([wikicode.PYTHON, '-S'], frksrv=True),
                       W5MODE_UNTRUSTED_PY
                       : lambda : self.handle_untrusted ([wikicode.PYTHON, '-S']),
                       W5MODE_UNTRUSTED_PYFORK
                       : lambda : self.handle_untrusted ([wikicode.PYTHON, '-S'], frksrv=True),
                       W5MODE_UNTRUSTED_BIN
                       : lambda : self.handle_untrusted(['/lib/ld-linux.so.2']),
#                      W5MODE_UNTRUSTED_BIN
#                       : lambda : self.handle_untrusted(),
                       W5MODE_UNTRUSTED_STATIC
                       : self.handle_static,
                       W5MODE_UNTRUSTED_STATIC_IHOME
                       : lambda : self.handle_static(ihome=True),
                       }[self.uri.mode]
        except KeyError:
            raise ValueError, 'Unexpected mode: %s' % cgi.escape (self.uri.mode, 1)

        ret = handler ()
        ret = cgi_to_wsgi (ret)

        self.dbg ('page_ls: %s' % (self.page_ls,))

        if (self.uri.mode in wikicode.trusted_modes):
            headermode = HTTPHDR_W5MODE_TRUSTED
        else:
            headermode = HTTPHDR_W5MODE_UNTRUSTED

        ret[1].append (('X-w5mode', headermode))
        ret[1].append (('X-slabel', ','.join (str (h) for h in self.page_ls.get_S ())))
        ret[1].append (('X-ilabel', ','.join (str (h) for h in self.page_ls.get_I ())))
        ret[1].append (('X-olabel', ','.join (str (h) for h in self.page_ls.get_O ())))

        if self.principal:
            slab_en = self.principal.label2englishList (self.page_ls.get_S ())
            ret[1].append (('X-slabel-en', ','.join(str (h) for h in slab_en)))

            s = ['%s:%s' % (r[0], r[1]) for r in self.principal.get_tags (flags='pe')]
            ret[1].append (('X-slabel-all-en', ','.join(s)))

        self.dbg ('headers: %s' % (ret[1],))

        self.dbg ('done')
        self.print_total ('launcher.total')

        return ret

    def get_response (self):
        if False:
            # XXX FastCGI is accumulating endpoints. Gotta eventually fix this.
            olab = flmo.get_label (flume.LABEL_O)
            print >> sys.stderr, "olabel %s" % olab
            print >> sys.stderr, "olabel size %d" % len (olab)
            print >> sys.stderr, "endpoints %d" % len (flmo.get_endpoint_info ())

        if False:
            print >> sys.stderr, "ENV %s\n" % (self.env,)


        oldls = flmo.get_labelset ()
        self.page_ls = None
        try:
            return self._get_response ()
        except Exception, e:
            return wikicode.format_error_wsgi (e, headers=self.headers)
        finally:
            flmo.set_label2 (S=oldls.get_S ())
            flmo.set_label2 (I=oldls.get_I ())
            flmo.set_label2 (O=oldls.get_O ())
            
