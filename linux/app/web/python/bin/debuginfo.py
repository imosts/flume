#!/usr/bin/python

import os
print "Content-type: text/html\r\n\r\n"

print "<h1>W5 Debug info</h2>"

print "<h2>Tags</h2>"
print "<pre>"
for k, v in os.environ.items ():
    if k.startswith ('MASTER') and k.endswith ('CAP'):
        print "%s = %s" % (k, v)
print "</pre>"

print "<h2>Cookies</h2>"
print "<script type='text/javascript'>document.write (document.cookie)</script>"

print "<h2>Environment</h2>"
print "<pre>"
for k, v in os.environ.items ():
    print "%s = %s" % (k, v)
print "</pre>"


