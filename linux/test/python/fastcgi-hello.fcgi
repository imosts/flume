#!/usr/bin/python
import os, sys, time
import flume.flmos as flmo

def myapp(environ, start_response):
    start = time.time ()
    
    start_response('200 OK', [('Content-Type', 'text/plain')])

    ret = []
    ret.append ('FastCGI in Flume!\n')
    ret.append ('pythonpath %d\n' % (len (sys.path),))
    ret.append ('\n'.join (sys.path))

    ret.append ('ls %s\n' % flmo.get_labelset () )
    ret.append ('process FLUME_SOCKET %s\n' % os.environ.get('FLUME_SOCKET', "undefined"))
    ret.append ('request FLUME_SOCKET %s\n' % environ.get('FLUME_SOCKET', "undefined"))


    if False:
        # Load test database
        from wikicode.db.user import User
        alice = User.object_withkey ('alice', environ)
        tag = alice.get_tag ('etag')
        ret.append ('alice etag %s\n' % (tag,) )
        # XXX Fix this so that we connect and disconnect from the DB.!!

    if False:
        flmo.set_libc_interposing (True)
        import DBV.dbapi as dbapi
        import DBV, psycopg2

        dbname, user, pw = DBV.default_db_user_pw ()
        conn = psycopg2.connect ('dbname=%s user=%s password=%s host=/var/run/postgresql' %
                                 (dbname, user, pw))
        cur = conn.cursor ()
        cur.execute ("SELECT username from w5_user")
        ret.append ("%s" % (cur.fetchall (),))
        cur.close ()
        conn.close ()
        flmo.set_libc_interposing (False)

    if False:
        argv = ['/usr/bin/python', '-S', '/disk/yipal/flume/run/testbin/null.py']
        ch = flmo.spawn (argv[0], argv, confined=True)
        (pid, status, visible) = flmo.waitpid (ch)

    if False:
        import DBV.dbapi as dbapi
        from wikicode.Launcher import spawn_child
        argv = ['/usr/bin/python', '-S', '/disk/yipal/flume/run/testbin/null.py']
        out, err, status = spawn_child (flmo.LabelSet (), argv)

        epi = flmo.get_endpoint_info ()
        sys.stderr.write ("endpoints %d\n%s\n"
                          % (len (epi), epi.prettyPrint ()))

        sys.stderr.write ("db connections %d\n" % len (dbapi.all_conns ()))
        ret.append (out)

    if False:
        for i in range (100):
            ret.append ('Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n')

    sys.stderr.write ("total in loop %0.3f\n" % (time.time () - start,))
    return ret

if __name__ == '__main__':
    flmo.set_libc_interposing (False)
    from wikicode.flup.fcgi_single import WSGIServer
    WSGIServer(myapp).run()
