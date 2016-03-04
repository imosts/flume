import sys, os, time
import flume
import flume.flmos as flmo

def usage ():
    print '%s {client|server} [sockfile]' % sys.argv[0]
    sys.exit (1)

if len (sys.argv) < 2:
    usage ()

sockfile = '/var/run/postgresql/testsock'
if len (sys.argv) > 2:
    sockfile = sys.argv[2]

if sys.argv[1] == 'server':

    try:
        l = flmo.stat_file (sockfile)
        flmo.unlink (sockfile)
    except OSError, e:
        import errno
        if e.errno != errno.ENOENT:
            raise

    srv_fd = flmo.unixsocket (sockfile, flmo.LabelSet ())
    print 'server: listen fd is %d' % srv_fd

    flmo.listen (srv_fd, 5)

    while (True):
        print 'server: waiting for clients'
        clnt_fd = flmo.accept (srv_fd)
        print 'server: a client connected on fd %d' % clnt_fd
        os.close (clnt_fd)
        print 'server: disconnected from client on fd %d' % clnt_fd

elif sys.argv[1] == 'client':
    from flume.profile import start, total, print_delta
    start ()
    for i in range (2000):
        fd = flmo.unixsocket_connect (sockfile);
        print ('client: #%d connected to server, ep label is S=%s I=%s'
               % (i, flmo.get_fd_label (flume.LABEL_S, fd), flmo.get_fd_label (flume.LABEL_I, fd)))
        os.close (fd);
        print_delta ('done')
    print "total %f " % total ()

else:
  usage ()

    
