import wikicode, DBV, os, sys
import flume.flmos as flmo

class FancyHello (wikicode.extension):
    def run (self):
        self.append_to_page ("<h2>Hello World</h2>\n")
        
        self.append_to_page ("<p>My labelset is %s\n" % flmo.get_labelset ())
        self.append_to_page ("<p>Cookies available to Javascript: \n")
        self.append_to_page ("<script type='text/javascript'>document.write (document.cookie)</script>\n\n")
        self.append_to_page ("<p>Python path: <BR>%s" % '<BR>\n'.join (sys.path))

        conn = DBV.dbapi.LabeledDBConn ()
        cursor = conn.cursor ()
        
        cursor.execute ("SELECT username FROM w5_user ")
        r = cursor.fetchall ()

        self.append_to_page ("<h2>Userlist read from the DB</h2>")
        self.append_to_page ('<BR>\n'.join ([row[0] for row in r]))

        self.append_to_page ('<h2>Environment</h2>')
        e = os.environ.keys ()
        e.sort ()
        self.append_to_page ('<BR>\n'.join ( ['%s  --  %s' % (k, os.environ[k]) for k in e]))
        
        self.append_to_page ("<p><iframe src=http://pdos.lcs.mit.edu/></iframe></p>")
        self.append_to_page ("<a href=http://pdos.lcs.mit.edu>Link to outside</a>")
        
        self.send_page ()

if __name__ == '__main__':
    wikicode.run_extension (FancyHello)
