import sys, asyncore, flmkvs.server

def usage ():
    print '%s [sockfile]' % sys.argv[0]
    sys.exit (1)

if __name__ == "__main__":
    sockfile = flmkvs.default_sockfile
    if len (sys.argv) > 2:
        sockfile = sys.argv[2]

    server = flmkvs.server.kvs_server (sockfile)
    server.start ()

