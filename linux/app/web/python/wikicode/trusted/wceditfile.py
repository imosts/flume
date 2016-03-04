import cgi, wikicode, os, os.path, flume
import flume.flmos as flmo
from wikicode.errors import *

class editfile (wikicode.extension):
    def output_form (self, filename, text, msg=''):
        self.send_page ("<h2>Write a script</h2>\n"
                        "<form action=%s method=post>\n"
                        "<input type=text name=fname value='%s'>"
                        "<input type=submit name=submit value=Read>\n"
                        "<input type=submit name=submit value=Save><BR>\n"
                        "<textarea name=txarea rows=\"20\" cols=\"80\">%s</textarea><BR>\n"
                        "<input type=hidden name=action value=upload>\n"
                        "</form>\n"
                        "<p>MSG: %s"
                        % (self.request_uri, filename, cgi.escape(text), msg))

    def run (self):
        self.dbg ('self.request_uri = %s' % self.request_uri)

        if not self.logged_in ():
            raise WCError, 'You must be logged in to edit files'
        
        if (self.form.has_key('submit')):
            submit = self.form['submit'].value
            fname = self.form['fname'].value
            fpath = os.path.sep.join ([self.get_principal ().script_dir (), fname])
            ls = self.get_principal ().script_ls ()
        
            if (submit == 'Read'):
                f = open (fpath, 'r')
                s = f.read ()
                f.close ()
                self.output_form (fname, s, 'Read file OK')
        
            elif (submit == 'Save'):
                self.dbg ('fname is %s' % fname)
                self.dbg ('self.ls is %s' % self.ls)
                self.dbg ('ls is %s' % ls)
                self.dbg ('get_labelset returns %s' % flmo.get_labelset ())

                # Why do we need to set our I label here?  Shouldn't
                # the endpoint label be enough?
                flmo.set_label2 (I=self.ls.get_I () + ls.get_I (),
                                 O=self.ls.get_O () + ls.get_O ())

                f = flmo.open (fpath, 'cwt', mode=0644, labelset=ls, endpoint=ls)
                f.write (self.form['txarea'].value)
                f.close ()

                flmo.set_label2 (I=self.ls.get_I (), O=self.ls.get_O ())
                
                self.output_form (fname, self.form['txarea'].value, 'Saved file OK')
            
            else:
                self.output_form ('', '')
        
        else:
            self.dbg ('wceditfile.py: No command\n');
            self.output_form ('', '')
        
if __name__ == '__main__':
    wikicode.run_extension (editfile)
