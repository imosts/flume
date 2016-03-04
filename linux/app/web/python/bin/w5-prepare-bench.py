"""
This prepare script will login users into w5 and get a (UN,GID,TPW)
set for each users in addition to a URL for the photoalbum.
"""

import os, sys
import flume.flmos as flmo
from flume.flmos import LabelSet, Label
import wikicode
from wikicode.db.user import User

def usage ():
    print sys.argv[0] + ' [-h host] [-p port] [-n num_users] [-nf] [--help]'
    print "<host> is the hostname of the web server (not the proxy host)"
    print "<port> is the apache port of the web server (not the proxy port)"
    print "-nf use non-frozen django app"
    print "Logs in <num_users> and outputs a list cookie information and photoapp URLs"
    sys.exit (-1)

# Defaults
nusers = 1000
server_name = 'hydra.lcs.mit.edu'
server_port = os.popen ('flume-cfg apacheport').read ().strip ()
frozen = True

# --------------------------------------------

# Parse args
args = sys.argv[1:]
while (len (args) > 0):
    arg = args.pop (0)
    if arg == '-h':
        server_name = args.pop (0)
    elif arg == '-p':
        server_port = args.pop (0)
    elif arg == '-n':
        nusers = int (args.pop (0))
    elif arg == '-nf':
        frozen = False
    elif arg == '--help':
        usage ()
    else:
        usage ()

# import and setup django
tools = User ('djangotools')
sys.path.append (tools.script_loc ())
from w5djangoutil import setup_django_path_and_environ, append_to_path
setup_django_path_and_environ ('photoapp', 'photoapp')

# import photoapp functions
append_to_path ('photoapp')
from photoapp.views import experiment_get_albumid

if frozen:
    script = "rundjango"
    mode = "exec"
else:
    script = "rundjango.py"
    mode = "python"

userlist = []
for i in range (nusers):
    un = 'user%d' % i
    pw = 'pw'

    u = User (un)
    u.pwlogin (pw)
    cid = u.new_context_id ()
    netloc = "%s:%s" % (server_name, server_port)

    link_ls = flmo.LabelSet (S=flmo.Label ([u.get_tag ('anon')]))

    album_id = experiment_get_albumid (un, 'album')

    base_url_exec = wikicode.W5Uri (netloc=netloc, mode='exec', jsmode=True,
                                    link_ls=link_ls, trusted=False)
    base_url_py = wikicode.W5Uri (netloc=netloc, mode='python', jsmode=True,
                                  link_ls=link_ls, trusted=False)

    album_extension = '/photoapp/%s/viewalbum/%d/' % (script, album_id)
                               
    userlist.append ({'un': un,
                      'pw': pw,
                      'gid': u.gcap.armor32 (),
                      'tpw': u.tpw,
                      'cid': cid,
                      'netloc': netloc, # Should be the host:port of the server (no cid)
                      'base_url_exec': base_url_exec.str_sans_devel (),
                      'base_url_py': base_url_py.str_sans_devel (),
                      'album_extension': album_extension
                      })

for u in userlist:
    print ' '.join ([str (u[k]) for k in ('un', 'gid', 'tpw', 'cid', 'netloc',
                                          'base_url_exec', 'base_url_py', 'album_extension')])
    
