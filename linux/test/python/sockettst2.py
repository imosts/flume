"""
# Running this test:

# Make the tags:
# flumepython /disk/$USER/flume/run/testbin/sockettst2.py maketags
group tag tester group (0x30000000000277d) cap tester group (0x630000000000277d) token mrners7wavtz4izw66s54y269f2ujhw2
e tag tester e tag (0x50000000000277e) cap tester e tag (0x450000000000277e) token 8nte87wwsmi7wr6vg2rirptqtw9ercdb

# Run the server
# flumepython /disk/$USER/flume/run/testbin/sockettst2.py server 0x630000000000277d mrners7wavtz4izw66s54y269f2ujhw2

# Run the client confined
# flumepython /disk/$USER/flume/run/testbin/spawn_confined.py `which python` /disk/$USER/flume/run/testbin/sockettst2.py client 0x50000000000277e 0x450000000000277e 8nte87wwsmi7wr6vg2rirptqtw9ercdb
"""

import sys, os, string, flume
import flume.flmos as flmo
import flume.util as flmu

sockfile = '/var/run/foo/bar'

def usage ():
    print '%s maketags' % sys.argv[0]
    print '%s server group_cap group_tok' % sys.argv[0]
    print '%s client e_tag e_cap e_tok' % sys.argv[0]
    sys.exit (1)

def get_caps ():
    # get group capabilities
    group_cap = flmo.Handle (string.atoi (sys.argv[2], 16))
    group_tok = sys.argv[3]
    flmo.req_privs (group_cap, group_tok)


def del_sockfile (sockfile):
    try:
        l = flmo.stat_file (sockfile)
        flmo.unlink (sockfile)
    except OSError, e:
        import errno
        if e.errno != errno.ENOENT:
            raise

def listen (sockfile, ls):
    flmo.set_label (flume.LABEL_I, ls.get_I())
    srv_fd = flmo.unixsocket (sockfile, ls)
    flmo.set_label (flume.LABEL_I)

    print 'server: listen fd is %d on %s' % (srv_fd, sockfile)
    print 'server: ls is %s' % flmo.get_labelset()

    flmo.listen (srv_fd, 1000)

    while (True):
        clnt_fd = flmo.accept (srv_fd)
        print 'server: a client connected on fd %d' % clnt_fd
        print 'server: endpoint slabel: %s' % flmo.get_fd_label (flume.LABEL_S, clnt_fd)
        print 'server: endpoint ilabel: %s' % flmo.get_fd_label (flume.LABEL_I, clnt_fd)
        
        os.close (clnt_fd)
        print 'server: disconnected from client on fd %d' % clnt_fd

if sys.argv[1] == 'eserver':
    del_sockfile (sockfile)
    get_caps ()
    listen (sockfile, flmo.LabelSet ())

elif sys.argv[1] == 'iserver':
    del_sockfile (sockfile)
    get_caps ()

    o = flmo.get_label (flume.LABEL_O)
    o += flmo.Handle(0x2900000000002787)
    flmo.set_label (flume.LABEL_O, o)

    i = flmo.get_label (flume.LABEL_I)
    i += flmo.Handle(0x900000000002787)
    #flmo.set_label (flume.LABEL_I, i)
    
    print "server: ls %s" % flmo.get_labelset ()
    listen (sockfile, flmo.LabelSet (I=flmo.Label([flmo.Handle(0x900000000002787)])))

elif sys.argv[1] == 'eclient':

    # get E capabilities
    e_tag = flmo.Handle (string.atoi (sys.argv[2], 16))
    e_cap = flmo.Handle (string.atoi (sys.argv[3], 16))
    e_tok = sys.argv[4]
    flmo.req_privs (e_cap, e_tok)

    # set S label
    flmo.set_label (flume.LABEL_S, flmo.Label([e_tag]))

    # set O label
    flmo.set_label (flume.LABEL_O)

    print 'client: ls is %s' % flmo.get_labelset()
  
    for i in range (1):
        fd = flmo.unixsocket_connect (sockfile);
        
        print 'client: connected on fd %d' % fd

        # The following line causes an exception
        # I think there is an RM bug where the client does not get an endpoint on this fd.
        #print 'client: endpoint S label %s' % (i, flmo.get_fd_label (flume.LABEL_S, fd))
        
        os.close (fd);

elif sys.argv[1] == 'iclient':
    # get I capabilities
    tag = flmo.Handle (string.atoi (sys.argv[2], 16))
    cap = flmo.Handle (string.atoi (sys.argv[3], 16))
    tok = sys.argv[4]
    flmo.req_privs (cap, tok)

    # set I label
    flmo.set_label (flume.LABEL_I, flmo.Label([tag]))

    # set O label
    #flmo.set_label (flume.LABEL_O)

    print 'client: ls is %s' % flmo.get_labelset()
  
    for i in range (1):
        fd = flmo.unixsocket_connect (sockfile);
        print 'client: connected on fd %d' % fd
        #print 'client: endpoint label: %s' % flmo.get_fd_label (flume.LABEL_I, fd)
        #print 'client: info [%s]' % flmo.get_endpoint_info ().prettyPrint ()
        os.close (fd);

elif sys.argv[1] == 'maketags':

    # Make a group for the server to own
    group_tag, group_cap = flmu.makeGroup ("tester group", ls=flmo.LabelSet ())
    group_tok = flmo.make_login (group_cap)
    print "group tag %s cap %s token %s" % (group_tag, group_cap, group_tok)
    
    # Make an E tag for the client to put in S
    e_tag, e_caps = flmu.makeTag ('pe', 'tester e tag')
    e_tok = flmo.make_login (e_caps[0])
    print "e tag %s cap %s token %s" % (e_tag, e_caps[0], e_tok)
    flmo.add_to_group (group_tag, e_caps)

    # Make an I tag for the client to use.
    i_tag, i_caps = flmu.makeTag ('pi', 'tester i tag')
    i_tok = flmo.make_login (i_caps[0])
    print "i tag %s cap %s token %s" % (i_tag, i_caps[0], i_tok)
    flmo.add_to_group (group_tag, i_caps)
    
else:
  usage ()

    
