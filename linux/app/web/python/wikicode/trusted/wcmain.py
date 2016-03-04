_PROFILE=False

if _PROFILE:
    import time, sys
    _true_start = time.time ()
    sys.stderr.write ('wcmain true start %0.3f %0.3f\n' % (0, _true_start))

import wikicode, flume, sys, os, DBV, cgi
import flume.flmos as flmo
from flume.flmos import LabelSet, Label
from wikicode.db.user import User
from wikicode.db.app import App
from wikicode.db.util import DB_LSD
from wikicode.errors import *
from wikicode.const import *
from wikicode.util import check_mkdir_label, getformlist, set_cookies, clear_cookies
from wikicode import TRUSTED_WORKER_UNAME, W5Uri


show_check_boxes = False
show_editor = False

class main (wikicode.extension):
    PROFILE = _PROFILE
    
    def send_upload_form (self):
        page = ("<h2>Write a script</h2>\n"
                "<form action=/%s method=post>\n"
                "<input type=text name=fname><BR>\n"
                "<textarea name=txarea rows=\"20\" cols=\"80\">"
                "</textarea><BR>\n"
                "<input type=submit name=submit value=Submit>\n"
                "<input type=hidden name=action value=upload>\n"
                "</form>" % W5MODE_TRUSTED_PY)
        self.send_page (page)
    
    def send_logincreate_form (self, form):
        page = ("<h2>Login</h2>\n"
                "<form action=%s method=post>\n"
                "<table>"
                "<tr><td>Username:</td><td>"
                "<input type=text name=username size=20 value='alice'></td></tr>\n"
                "<tr><td>Password:</td><td>"
                "<input type=text name=password size=20 value='pw'></td></tr>\n"
                "</table>"
                "<input type=submit name=submit value=Login>\n"
                "<input type=hidden name=action value=logincreate>\n"
                "</form>\n" % form)
        
        page += ("<h2>Create a new user</h2>\n"
                 "<p>Enter your username and password to create a new account</p>\n"
                 "<form action=%s method=post>\n"
                 "<table>"
                 "<tr><td>Username:</td><td>"
                 "<input type=text name=username size=20 value='testuser2'></td></tr>\n"
                 "<tr><td>Password:</td><td>"
                 "<input type=text name=password size=20 value='pw'></td></tr>\n"
                 "</table>"
                 "<input type=submit name=submit value=Create>\n"
                 "<input type=hidden name=action value=logincreate>\n"
                 "</form>\n" % form)
        self.send_page (page)

    def app_table (self):
        
        user_wtag = self.get_principal ().get_tag ('wtag')
        apps = [a for a in App.objects ()]
        editor_map = self.get_principal ().get_editor_map ()
        current_editor = self.get_principal ().get_editor_id ()

        s = []
        if show_editor:
            s.append ('<form action=/%s>Use editor:<select name=editorid>' % W5MODE_TRUSTED_PY)
            users = [u for u in User.objects ()]
            users.sort (key=lambda u: u.un)
            for u in users:
                selected = ''
                if u.get_id () == current_editor:
                    selected = ' selected '
                s.append ('<option value=%d%s>%s' % (u.get_id (), selected, u.un))
            s.append ('</select>')
            s.append ('<input type=hidden name=action value=change_editor>')
            s.append ('<input type=submit name=submit value=Save></form>')

        s.append ('<table border=1>')
        s.append ('<tr><td>App</td><td>&nbsp;</td>')
        if show_check_boxes:
            for a in apps:
                s.append ('<td>%s_I</td>' % (a.appname,))
            for a in apps:
                s.append ('<td>%s_W</td>' % (a.appname,))
        s.append ('</tr>')
        
        for app in apps:
            devel = User.object_withkey (app.developer)
            choice = []
            if editor_map.has_key (app.get_id ()):
                choice = editor_map[app.get_id ()]

            s.append ('<tr><form action=/%s>\n<td>%s</td>' % (W5MODE_TRUSTED_PY, app.appname))
            s.append ('<td><input type=hidden name=action value=runapp>')
            s.append ('<input type=hidden name=appid value=%d>' % app.get_id ())
            if show_editor:
                s.append ('<input type=submit name=save value="Save As Editor">')
            s.append ('<input type=submit name=run value="Run Anonymous">')
            s.append ('<input type=submit name=runupload value="Run Uploader"></td>')

            if show_check_boxes:
                for a in apps:
                    devel2 = User.object_withkey (a.developer)
                    checked = ''
                    if app.appname == a.appname:
                        checked = ' checked '
                    elif (wikicode.compound_tagname (devel2.un, devel2.script_tagname ()) in choice):
                        checked = ' checked '

                    s.append ('<td><input type=checkbox name="itags" value="%s:%s"%s></td>'
                              % (a.developer, devel2.script_tagname (), checked))

                # wcaps
                for a in apps:
                    checked = ''
                    if app.appname == a.appname:
                        checked = ' checked '
                    s.append ('<td><input type=checkbox name="wtags" value="%s:wtag_app_%s"%s></td>'
                              % (self.get_principal ().un, a.developer, checked))

            s.append ('</form></tr>')

        s.append ('</table>')
        return '\n'.join (s)

    def script_row (self, mode, devel, f, desc):
        user_wtag = self.get_principal ().get_tag ('wtag')

        l = [desc]
        if mode == W5MODE_TRUSTED_PYWORKER:
            uri = W5Uri (mode=mode, devel=devel, file=f, trusted=True)
            l.append ('<A HREF=\"%s\">%s</A>' % (uri, 'with_gcap'))
        else:
            d = User.object_withkey (devel)
            uri = W5Uri (mode=mode, devel=devel, file=f, link_ls=flmo.LabelSet (), trusted=False)
            uri.reset_context_id (user=self.get_principal ())
            l.append ('<a href="%s">Run it</a>' % uri.absolute_uri ())

        return '<tr>%s</tr>' % ('\n'.join (['<td>%s</td>' % s for s in l]))

    def list_scripts_in_dir (self, devel, dirname):
        files = os.listdir (dirname)
        files.sort ()


        s = '<table border=1>'
        for f in files:
            if devel == TRUSTED_WORKER_UNAME:
                mode = W5MODE_TRUSTED_PYWORKER
            elif f.endswith ('.py'):
                mode = W5MODE_UNTRUSTED_PY
            else:
                mode = W5MODE_UNTRUSTED_BIN
            
            if os.path.isdir (os.path.sep.join ((dirname, f))):
                s += '<tr><td>%s</td><td>Directory</td>' % f
            else:
                s += self.script_row (mode, devel, f, f)
        return s + '</table>'


    def print_static_files_in_dir (self, devel, mode, dirname):

        if devel == "blog":
            s = '<table border=1>'
            user_wtag = self.get_principal ().get_tag ('wtag')

            static_file_dir = dirname + "/blog/static/blog"
            files = os.listdir (static_file_dir)

            for f in files:
                l = [f]
                linkls = flmo.stat_file (os.path.join (static_file_dir, f))
                linkls.set_I ()
                d = User.object_withkey (devel)
                uri = W5Uri (mode=mode, devel=devel, file="blog", 
                             link_ls=linkls, 
                             therest=dirname+"/blog/static/blog/%s" % f, trusted=False, jsmode=True)
                uri.reset_context_id (user=self.get_principal ())
                l.append ('<a href="%s">Run it</a>' % uri.absolute_uri ())
                s+= '<tr>%s</tr>' % ('\n'.join (['<td>%s</td>' % s for s in l]))
            return s + '</table>'
        return ''

    def send_control_panel (self):
        page = ['<h2>W5 Start Page</h2>']
        page += 'Welcome <b>%s</b> [<a href=%s?action=logout>Logout</a>]  ' % (self.un, self.request_uri)
        page += '<a href="/%s">Start toolbar</a>' % W5MODE_TRUSTED_TOOLBAR
        #page += '<p>Your homedir: <tt>%s</tt><BR>' % (self.get_principal ().home_dir ())
        #page += 'Your scriptdir: <tt>%s</tt><BR>' % (self.get_principal ().script_dir ())

        # Actions
        page += '<h3>W5 Utilities</h3>\n'
        page += self.list_scripts_in_dir (TRUSTED_WORKER_UNAME,
                                          '/disk/%s/flume/run/pybin/%s'
                                          % (os.environ['USER'], TRUSTED_WORKER_UNAME))
        
        page += '<h3>Registered Applications</h3>\n'
        page += self.app_table ()

        page += '<h3>Static links</h3>\n'
        page += self.print_static_files_in_dir (self.un, W5MODE_UNTRUSTED_STATIC_IHOME, self.get_principal().static_dir())
        
        page += '<p><h3>Your Scripts</h3>\n'
        page += self.list_scripts_in_dir (self.un, self.get_principal ().script_dir ())

        # E tags
        page += '<h3>Your E tags</h3>'
        page += 'Create new E tag: '
        page += '<form action="/%s" method=post>' % W5MODE_TRUSTED_PY
        page += '<input type=text name=tagname size=20 value="foo">'
        page += '<input type=submit name=submit value="Create">'
        page += '<input type=hidden name=action value=create_etag>'
        page += '</form>'
        page += '\n\n'

        page += '<table border=1>\n'
        acls = self.get_principal ().get_aclinstance ()

        for tag, name in self.get_principal ().get_tags (flags='pe'):
            page += '<tr>'
            page += '<td>%s</td><td><tt>%s</tt></td>\n' % (tag, name)

            page += '<form action="/%s" method=POST>\n' % W5MODE_TRUSTED_PY
            page += '<td><input type=hidden name=action value=assign_acl>\n'
            page += '<input type=hidden name=tagname value="%s">\n' % wikicode.tagname_suffix (name)
            page += '<select name="aclname">\n'

            try:
                assigned_aclname, assignment_id = self.get_principal ().get_aclassignment (tag)
            except InvalidObject:
                assigned_aclname = None

            options = []
            selected = False
            for n in acls:
                extra = ''
                if assigned_aclname and assigned_aclname == n:
                    selected = True
                    extra = 'selected="selected"'
                options.append ('<option value="%s" %s>%s' % (n, extra, n))

            if selected:
                options.insert (0, '<option value="0">None')
            else:
                options.insert (0, '<option value="0" selected="selected">None')

            page += '\n'.join (options)
            page += '</select></td>'
            page += '<td><input type=submit name=submit value="Save"></td>'
            page += '</form>'
            page += '</tr>\n\n'
        page += '</table>\n\n'

        page += '<h3>Your W tags</h3>'
        page += '<table border=1>'
        for tag, name in self.get_principal ().get_tags (flags='pw'):
            page += '<tr><td>%s</td><td>%s</td></tr>' % (name, tag)
        page += '</table>'

        self.send_page (''.join (page))

    def handle_runapp (self, appid, itagnames, wtagnames, upload=False):
        app = App.object_withid (appid)

        therest = None
        if upload:
            therest = 'upload'

        if app.mode not in trusted_modes:
            devel = User.object_withkey (app.developer)
            user = self.get_principal ()

            # Setup S label
            slab = flmo.Label ()
            if not upload:
                slab += user.get_tag ('anon')

            # Setup I label
            ilab = flmo.Label ()
            if wikicode.IMODE & wikicode.IMODE_APP:
                new_i = []
                for t in itagnames:
                    owner = wikicode.tagname_prefix (t)
                    h = User.real_get_tag (t, fullname=True)
                    if owner == devel.un:
                        ilab += h
                    else:
                        # The user is adding an additional integrity relation
                        new_i.append (h)

            # Setup O label
            olab = flmo.Label ()
            if show_check_boxes:
                otagnames = wtagnames
            elif USE_USER_WCAPS:
                otagnames = [wikicode.compound_tagname (user.un, 'wtag_app_%s' % app.developer)]
            else:
                otagnames = []

            for t in otagnames:
                try:
                    h = User.real_get_tag (t, fullname=True)
                    olab += h
                except InvalidObject:
                    tagname = wikicode.tagname_suffix (t)
                    tag, caps = user.maketag ('pw', tagname)
                    olab += tag

            # Run the app with the user's and app's endorsement capability
            if wikicode.IMODE & wikicode.IMODE_USER:
                olab += user.script_tag ().toCapabilities ()[0]

            # Make the URL
            ls = flmo.LabelSet (S=slab, I=ilab, O=olab)
            uri = W5Uri (mode=app.mode, devel=app.developer, file=app.scriptname,
                         jsmode=False, therest=therest, link_ls=ls, trusted=False)

            # Allocate a new context_id
            uri.reset_context_id (user)

            # Figure out filters and save them, so wlaunch gets the right filter files.
            if wikicode.IMODE & wikicode.IMODE_APP:
                devel_itag = devel.script_tag ()
                filters = []
                for itag in new_i:
                    # make filter {new_i} -> {new_i, devel:publish}
                    import flume.setuid as flms

                    find = flmo.Label ([itag])
                    repl = flmo.Label ([itag, devel_itag])
                    caps = devel_itag.toCapabilities ()

                    ls = flmo.LabelSet (I=flmo.Label ([devel_itag]))
                    fn = os.path.join ('/ihome', ls.to_filename (),
                                       'filter.%s.%s' % (find.freeze ().armor32 (),
                                                         repl.freeze ().armor32 ()))

                    lsd = DB_LSD (CAPSET=['ENV: MASTERGTAG_CAP, MASTERGTAG_TOK'])
                    lsd.acquire_capabilities (savels=True)
                    flmo.set_label2 (O=flmo.get_label (flume.LABEL_O) + caps)
                    flmo.set_label2 (I=flmo.get_label (flume.LABEL_I) + ls.get_I ())

                    check_mkdir_label (os.path.dirname (fn), 0755, ls)

                    flms.makeFilter (name=fn, find=find, replace=repl, caps=caps, labelset=ls)
                    lsd.pop_labelset ()

                    filters.append (fn)

                # Save filter settings
                self.get_principal ().set_app_filters (appid, filters)
        else:
            # Support trusted "apps"
            uri = W5Uri (mode=app.mode, devel=app.developer, file=app.scriptname,
                         jsmode=False, therest=therest, link_ls=flmo.get_labelset (),
                         trusted=True)

        self.output_redirect ("Starting app...", uri.absolute_uri () + "/")
        self.send_page ()

    def handle_save_editor_map (self, appid, itagnames):
        app = App.object_withid (appid)

        self.dbg ("developer is %s" % app.developer)
        
        tagnames = [tn for tn in itagnames if not tn.startswith (app.developer + ':')]

        self.get_principal ().set_editor_map (appid, tagnames)
        self.output_redirect ("Done", "/%s" % W5MODE_TRUSTED_PY)
        self.send_page ()

    def handle_change_editor (self, editor_id):
        self.get_principal ().set_editor_id (editor_id)
        self.output_redirect ("Done", "/%s" % W5MODE_TRUSTED_PY)
        self.send_page ()

    def handle_upload (self):
        if not self.logged_in ():
            self.send_page ("Error, you must be logged in to upload")
            return
            
        fname = self.formfields['fname'].value
        text = self.formfields['txarea'].value

        if wikicode.illegal_filename (fname):
            raise ValueError, "Illegal file name: %s" % cgi.escape (fname, 1)

        scripts_ls = LabelSet (I=Label([self.get_principal ().get_subi_tag(wikicode.CODE_INTEGRITY_FNAME)]),
                               O=Label([self.get_principal ()._w_tag]))

        flmo.set_label (flume.LABEL_I, scripts_ls.get_I ())

        # write the script file
        scriptfile = os.path.sep.join ([self.get_principal ().script_dir (), fname])
        flmo.writefile (scriptfile, text, 0644, scripts_ls)
        self.send_page ('Success!')

    def handle_create (self, un, pw):
        u = User (un)
        u.create_data (pw, {'email': 'foo@foo.com', 'favoritecolor': 'blue'})
        u.pwlogin (pw)

        self.append_header (set_cookies (un, u.gcap.armor32(), u.tpw))
        (self.un, self.gid, self.tpw) = (un, u.gcap, u.tpw)

        self.output_redirect ("You're logged in", "/%s" % W5MODE_TRUSTED_PY)
        self.send_page ()

    def handle_create_etag (self, tagname):
        self.get_principal ().maketag ('pe', tagname)
        self.output_redirect ("done", "/%s" % W5MODE_TRUSTED_PY)
        self.send_page ()

    def handle_login (self, un, pw, uri):
        u = User (un)
        u.pwlogin (pw)

        self.append_header (set_cookies (un, u.gcap.armor32(), u.tpw))
        (self.un, self.gid, self.tpw) = (un, u.gcap, u.tpw)

        self.output_redirect ("You're logged in", uri)
        self.send_page ()

    def handle_logout (self):
        self.append_header (clear_cookies ())
        self.output_redirect ('Logged out!', '/%s' % W5MODE_TRUSTED_PY)
        self.send_page ()

    def handle_assign_acl (self, tagname, aclname):
        self.get_principal ().set_aclinstance (tagname, aclname)
        self.output_redirect ('Done!', '/%s' % W5MODE_TRUSTED_PY)
        self.send_page ()

    def run (self):
        """
        Handles controlpanel and logincreate
        """
        submit = action = None

        if self.form.has_key ('submit'):
            submit = self.form['submit'].value
        if self.form.has_key ('action'):
            action = self.form['action'].value
        else:
            if self.logged_in ():
                action = 'control'
            else:
                action = 'logincreate'

        # Dispatch on action
        if action == 'control':
            self.send_control_panel ()

        elif action == 'uploadform':
            self.send_upload_form ()

        elif action == 'upload':
            if submit and submit != 'Submit':
                raise ValueError, 'Invalid submit value %s' % cgi.escape(submit, 1)
            self.handle_upload ()

        elif action == 'logincreate':
            if submit and submit == 'Create':
                un = self.form['username'].value
                pw = self.form['password'].value
                self.handle_create (un, pw)
            elif submit and submit == 'Login':
                un = self.form['username'].value
                pw = self.form['password'].value
                self.handle_login (un, pw, self.request_uri)
            elif submit:
                raise ValueError, 'Invalid submit value %s' % cgi.escape(submit, 1)
            else:
                self.send_logincreate_form ('/%s' % W5MODE_TRUSTED_PY)

        elif action == 'logout':
            self.handle_logout ()

        elif action == 'create_etag':
            tagname = self.form['tagname'].value
            self.handle_create_etag (tagname)

        elif action == 'runapp':
            appid = int (self.form['appid'].value)
            itagnames = []
            wtagnames = []
            if show_check_boxes:
                itagnames = getformlist (self.form, 'itags')
                wtagnames = getformlist (self.form, 'wtags')
            
            if self.form.has_key ('run'):
                self.handle_runapp (appid, itagnames, wtagnames)
            elif self.form.has_key ('runupload'):
                self.handle_runapp (appid, itagnames, wtagnames, upload=True)
            elif self.form.has_key ('save'):
                self.handle_save_editor_map (appid, itagnames)

        elif action == 'change_editor':
            self.handle_change_editor (int (self.form['editorid'].value))

        elif action == 'assign_acl':
            tagname = self.form['tagname'].value
            aclname = self.form['aclname'].value
            if aclname == '0':
                aclname = None
            self.handle_assign_acl (tagname, aclname)

        else:
            raise ValueError, 'Unexpected action: %s' % cgi.escape (action, 1)

        if self.PROFILE:
            now = time.time ()
            sys.stderr.write ('wcmain true total %0.3f %0.3f\n' % (now-_true_start, now))

if __name__ == '__main__':
    wikicode.run_extension (main)
