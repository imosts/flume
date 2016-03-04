#!/usr/bin/python

import os

print "Content-type: text/html\r\n\r\n"

print "Environment:\n"
print "<pre>"
for k in os.envrion.keys ():
print "</pre>"


