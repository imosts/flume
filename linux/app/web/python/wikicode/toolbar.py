import wikicode, os, flume
import flume.flmos as flmo
from wikicode.util import getformlist
from wikicode.db.user import ADD, REMOVE
from wikicode.prepare import run_prepare
from wikicode.const import *

class Toolbar (wikicode.extension):

    def handle_show (self, msg=None):
        s = ['<h2>W5 Toolbar</h2>']

        if msg:
            s.append ("<p>Msg: <pre>%s</pre>\n" % msg)

        cids = self.get_principal ().get_newest_context_ids (limit=10)
        s.append ('<p>Recent contexts and their labels:')
        s.append ('<table border=1>')
        for cid in cids:
            ls, uri = self.get_principal ().get_context (cid)
            s.append ('<tr>')
            s.append ('<td><tt>%s</tt></td>' % cid)
            if ls:
                s.append ('<td><tt>S: %s<BR>I: %s<BR>O: %s</tt></td>'
                          % (self.get_principal ().label2english (ls.get_S ()),
                             self.get_principal ().label2english (ls.get_I ()),
                             self.get_principal ().label2english (ls.get_O ()),
                             ))

                s.append ('<td><tt><form action=/%s method=get>' % W5MODE_TRUSTED_TOOLBAR)
                s.append ('<input type=hidden name=action value=addetag>')
                s.append ('<input type=hidden name=cid value="%s">' % cid)

                tags = self.get_principal ().get_tags (flags=('pe', 'pr'))
                for tag, name in tags:
                    if tag in ls.get_S ():
                        checked = ' checked '
                    else:
                        checked = ''
                    s.append ('<input type=checkbox name="etags" value="%d"%s>%s<BR>'
                              % (tag.val (), checked, name))


                s.append ('<input type=submit name=submit value="Add E Tag"></form>')
                s.append ('<form action=/%s method=get>' 
                          '<input type=hidden name=cid value="%s">'
                          '<input type=hidden name=action value=removeanon>'
                          '<input type=submit name=submit value="Remove Anon">'
                          '</form>' % (W5MODE_TRUSTED_TOOLBAR, cid))

                s.append ('</tt></td>')

            else:
                s.append ('<td>Uninitialized</td><td>&nbsp;</td>')
            s.append ('</tr>')
                                  
        s.append ('</table>')
        self.append_to_page ('\n'.join (s))

    def handle_addetag (self, cid, etags):
        #self.dbg ("adding to cid %s, etags %s" % (cid, etags))
        etags = [flmo.Handle (int (v)) for v in etags]

        # tell the app to "prepare" for new s tags
        out, err, status = run_prepare (self.get_principal (), cid, etags, self.env)

        self.get_principal ().context_addremove (flume.LABEL_S, ADD, cid, etags)
        args = ''
        if len (out) > 0:
            args = '?msg=%s' % out
        self.output_redirect ('done', '/%s%s' % (W5MODE_TRUSTED_TOOLBAR, args))

    def handle_removeanon (self, cid):
        anon_tag = self.get_principal ().get_tag ('anon')
        self.get_principal ().context_addremove (flume.LABEL_S, REMOVE, cid, [anon_tag])
        self.handle_show ()
        
    def run (self):
        action = 'show'
        msg = ''

        if self.form.has_key ('action'):
            action = self.form['action'].value
        if self.form.has_key ('msg'):
            msg = self.form['msg'].value

        if action == 'show':
            self.handle_show (msg=msg)
        elif action == 'addetag':
            cid = self.form['cid'].value
            etags = getformlist (self.form, 'etags')
            self.handle_addetag (cid, etags)
        elif action == 'removeanon':
            cid = self.form['cid'].value
            self.handle_removeanon (cid)
        else:
            raise ValueError, 'Unexpected action: %s' % cgi.escape (action, 1)

        return self.get_output ()


