import wikicode, sys, os.path
from wikicode.db.user import User
import flume.flmos as flmo

def do_syncdb (devel_username, projname):
    class helper (object):
        def __init__ (self):
            self.s = ''
        def write (self, s):
            self.s += s

    h = helper ()
    oldpath = list (sys.path)

    # Setup Flume-Django environment # If this is running as
    # user=djangotools, then djantools is already in the path, and
    # this will end up adding djangotools to the sys.path a second
    # time.  But it also adds django.zip which might not be in the
    # path.
    from w5djangoutil import setup_django_path_and_environ
    setup_django_path_and_environ (devel_username, projname)

    # Redirect django's output to this cgi program and then run syncdb.
    from django.core.management import syncdb, set_output
    set_output (h)
    syncdb ()

    sys.path = oldpath
    return h.s

class django_tools_syncdb (wikicode.extension):
    def write (self, s):
        self.append_to_page (s)

    def run (self):
        self.append_to_page ("<h1>Django Syncdb</h1>\n")

        if not self.logged_in ():
            self.append_to_page ('You must be logged in to run syncdb')
            self.send_page ()
            return

        # The project names happen to be the same as the developer's username...
        projname = self.get_developer ().un
        self.send_page ('<p>Output:<BR><pre>%s</pre>\n' % do_syncdb (self.un, projname))

if __name__ == '__main__':
    wikicode.run_extension (django_tools_syncdb)
