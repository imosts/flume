#!/usr/bin/env python
# -*- coding: iso-8859-1 -*-
"""
    MoinMoin - CGI Driver Script

    @copyright: 2000-2005 by Jürgen Hermann <jh@web.de>
    @license: GNU GPL, see COPYING for details.
"""

# System path configuration

import sys

# We dont actually use these directories
sys.path.remove ('/usr/lib/python24.zip')
sys.path.remove ('/usr/lib/python2.4/plat-linux2')
sys.path.remove ('/usr/lib/python2.4/lib-tk')
sys.path.remove ('/usr/local/lib/python2.4/site-packages')

# Reorder directories, to put uncommon paths at the end of the list
sys.path.remove('INSTANCE/cgi-bin')

sys.path.append('PREFIX/lib/python2.4/site-packages')
sys.path.append('PYLIB')
sys.path.append('INSTANCE/cgi-bin')

# Path of the directory where wikiconfig.py is located.
# YOU NEED TO CHANGE THIS TO MATCH YOUR SETUP.
# sys.path.insert(0, '/path/to/wikiconfig')

# Path of the directory where farmconfig.py is located (if different).
## sys.path.insert(0, '/path/to/farmconfig')

# Debug mode - show detailed error reports
## import os
## os.environ['MOIN_DEBUG'] = '1'

# This is used to profile MoinMoin (default disabled)
hotshotProfiler = 0

# ---------------------------------------------------------------------

if hotshotProfiler:
    import hotshot
    prof = hotshot.Profile("moin.prof")
    prof.start()

from MoinMoin.request import RequestCGI
request = RequestCGI()
request.run()

if hotshotProfiler:
    prof.close()
