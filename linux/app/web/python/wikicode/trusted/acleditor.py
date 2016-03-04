import sys, wikicode
import flume.flmos as flmo
import flume
from wikicode.db.user import User, devel_from_env
from wikicode.db.util import DBObject, DB_LSD
from wikicode import TRUSTED_WORKER_UNAME
from wikicode.const import *

class ACLEditor (wikicode.extension):
    def __init__ (self, *args):
        wikicode.extension.__init__ (self, *args)
        self.tagval = None

    def my_uri (self, args=None):
        if not args:
            args = {}
        args['tagval'] = self.tagval
        uri = wikicode.W5Uri (mode=W5MODE_TRUSTED_PYWORKER, devel=TRUSTED_WORKER_UNAME,
                              file='acleditor.py', args=args, trusted=True)
        return str (uri)

    def output_one_acl (self, aclname):
        entries = self.get_principal ().get_acl_entries (aclname)
        self.append_to_page ('<table border=1>')
        self.append_to_page ('<tr><td><b>%s</b></td><td>%d Entries</td></tr>'
                             % (aclname, len (entries)))

        for name, entry_id in entries:
            self.append_to_page ('<tr>')
            self.append_to_page ('<td>%s</td>' % name)
            self.append_to_page ('<td><a href="%s">Remove</a></td>'
                                 % self.my_uri ({'action': 'remove', 'entry_id': entry_id}))
            self.append_to_page ('</tr>\n')
        self.append_to_page ('</table>')

        self.append_to_page ('<form action="%s" method=post>\n' % self.my_uri ())
        self.append_to_page ('<input type=text name=name>\n')
        self.append_to_page ('<input type=hidden name=action value=add>\n')
        self.append_to_page ('<input type=hidden name=aclname value="%s">\n' % aclname)
        self.append_to_page ('<input type=submit name=submit value="Add ACL Entry">\n')
        self.append_to_page ('</form>\n')

    def output_acls (self):
        for aclname in self.get_principal ().get_aclinstance ():
            self.output_one_acl (aclname)

    def output_page (self):
        self.append_to_page ('<h1>ACL Editor</h1>')
        self.append_to_page ('<form action="%s" method=POST>\n'
                             '<input type=hidden name=action value=make_aclinstance>\n'
                             '<input type=text name=aclname>\n'
                             '<input type=submit name=submit value="Create ACL">\n'
                             '</form>\n' % self.my_uri ())
        self.output_acls ()

    def removeentry (self, entry_id):
        self.get_principal ().remove_aclentry (entry_id)
        self.output_redirect ('Success!', self.my_uri ())

    def addentry (self, aclname, newfriend):
        self.get_principal ().add_to_aclinstance (aclname, newfriend)
        self.output_redirect ('Success!', self.my_uri ())

    def make_acl (self, aclname):
        self.get_principal ().make_aclinstance (aclname)
        self.output_redirect ('Success!', self.my_uri ())

    def run (self):
        if not self.logged_in ():
            self.append_to_page ('<h1>ACL Editor</h1>')
            self.send_page ('You must be logged in to use ACL Editor')
            return

        action = None
        if self.form.has_key ('action'):
            action = self.form['action'].value

        if action == 'remove':
            if self.form.has_key ('entry_id'):
                try:
                    entry_id = int(self.form['entry_id'].value)
                    self.removeentry (entry_id)
                except ValueError:
                    self.append_to_page ('<h1>ACL Editor</h1>')
                    self.append_to_page ('Form error, invalid entry_id')
            else:
                self.append_to_page ('<h1>ACL Editor</h1>')
                self.append_to_page ('Form error, no entry_id')

        elif action == 'add':
            if (self.form.has_key ('aclname') and self.form.has_key ('name')):
                aclname = self.form['aclname'].value
                newname = self.form['name'].value
                self.addentry (aclname, newname)
            else:
                self.append_to_page ('<h1>ACL Editor</h1>')
                self.append_to_page ('Form error, no aclname or name')

        elif action == 'make_aclinstance':
            name = self.form['aclname'].value
            self.make_acl (name)
            
        else:
            self.output_page ()
        self.send_page ()

if __name__ == "__main__":
    wikicode.run_extension (ACLEditor)

