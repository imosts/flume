import os, pg, sys, flume, traceback
import DBV
import flume.flmos as flmo
import flume.util as flmu
import flume.setuid as flms
from flume.labelsetdesc import LabelSetDesc

# To run this test:
# `flume-cfg bin`/flume-python /disk/$USER/flume/run/pybin/dbv.py 4000 18.26.4.76 5432
# `flume-cfg bin`/flume-python /disk/$USER/flume/run/testbin/dbvtst.py

def usage ():
    print 'usage: %s [-dbname name] [-user user] [-pw pw] [testnames...]' % (sys.argv[0])
    sys.exit (1)

testing = None
def dotest (name):
    if testing is None:
        return True
    else:
        if name in testing:
            testing.remove (name)
            return True
        return False

def query (q, expected=None, verify=True, conn=None):
    if conn:
        c = conn
    else:
        c = conn_emptylabel
    
    if (verify and
        type(expected) is type(Exception) and
        issubclass (expected, Exception)):
        try:
            c.query (q)
        except expected, e:
            return
        except Exception, e:
            raise Exception, ("Got exception %s, expected %s" %
                              (repr(e), expected))
        else:
            raise Exception, ("Got no exception, expected exception %s" %
                              (expected,))

    r = c.query (q)
    if verify:
        if r:
            r = r.getresult ()
        if expected != r:
            raise Exception, "Got %s, expected %s" % (r, expected)
    else:
        return r

def create_join_data ():
    query ("CREATE TABLE depts (deptid integer, deptname varchar);", None)
    query ("INSERT INTO depts (deptid, deptname) VALUES (31, 'sales');", None)
    query ("INSERT INTO depts (deptid, deptname) VALUES (33, 'engineering');", None)
    query ("INSERT INTO depts (deptid, deptname) VALUES (34, 'clerical');", None)
    query ("INSERT INTO depts (deptid, deptname) VALUES (35, 'marketing');", None)
    
    query ("CREATE TABLE emps (lname varchar, deptid integer);", None)
    query ("INSERT INTO emps (lname, deptid) VALUES ('rafferty', 31);", None)
    query ("INSERT INTO emps (lname, deptid) VALUES ('jones', 33);", None)
    query ("INSERT INTO emps (lname, deptid) VALUES ('steinberg', 33);", None)
    query ("INSERT INTO emps (lname, deptid) VALUES ('robinson', 34);", None)
    query ("INSERT INTO emps (lname, deptid) VALUES ('smith', 34);", None)
    query ("INSERT INTO emps (lname, deptid) VALUES ('jasper', 36);", None)

def remove_join_data (verify=True):
    query ("DROP TABLE depts;", None, verify)
    query ("DROP TABLE emps;", None, verify)

# Parse arguments
args = sys.argv[1:]
args, dbname, user, pw, sname, sdir = DBV.parse_args_or_default (args)
if len (args) > 0:
    testing = args
        
flmo.set_libc_interposing (True)
conn_emptylabel = pg.connect (dbname, user=user, passwd=pw)
flmo.setepopt(conn_emptylabel.fileno(), fix=True)

if dotest ('basic'):
    try:
        query ("CREATE TABLE table1 (name varchar);", None)
        query ("CREATE TABLE table2 (name varchar, slabelid varchar)",
               pg.ProgrammingError)
        query ("CREATE TABLE table3 (id INTEGER, d TIMESTAMPTZ, dt DATE)", None)

        query ("SELECT * FROM table1;", [])
        query ("INSERT INTO table1 (name) VALUES ('alice');", None)
        query ("INSERT INTO table1 (name) VALUES ('bob');", None)
        
        query ("SELECT name FROM table1", [('alice',), ('bob',)])
        query ("SELECT t.name from table1 as t", [('alice',), ('bob',)])
        query ("SELECT name FROM table1 ORDER BY name DESC", [('bob',), ('alice',)])
        query ("SELECT name FROM table1 ORDER BY xmin", pg.ProgrammingError)
        query ("SELECT name, xmin FROM table1", pg.ProgrammingError)
        query ("SELECT name FROM table1 LIMIT 1", [('alice',)])
        query ("SELECT name FROM table1 WHERE name LIKE 'al%'", [('alice',)])
        query ("SELECT name FROM table1 WHERE name LIKE 'b_b'", [('bob',)])
        query ("SELECT name FROM table1 WHERE name ILIKE 'Al%'", [('alice',)])
        query ("SELECT name FROM table1 WHERE name ILIKE 'B_b'", [('bob',)])

        # Test multiple statements per query
        query ("INSERT INTO table1 (name) VALUES ('foo'); INSERT INTO table1 (name) VALUES ('bar')", None)
        query ("SELECT name FROM table1 ORDER BY name ASC", [('alice',), ('bar',), ('bob',), ('foo',)])

        # Test string parsing
        query ("INSERT INTO table1 (name) VALUES ('Foo bar')", None)
        query ("INSERT INTO table1 (name) VALUES ('What''s up?')", None)
        # FlumeDB doesn't support the following syntax although SQL does.
        # If we need it, we'll add it.
        #query ("INSERT INTO table1 (name) VALUES ('string1'\n'string2')", None)

        # Test insert NULL
        query ("INSERT INTO table1 (name) VALUES (NULL)", None)

        # Test date/time
        query ("INSERT INTO table3 (id, d) VALUES (1, '2007-12-31 11:54:01.947049')", None)
        query ("SELECT * FROM table3 WHERE EXTRACT('month' FROM table3.dt) = '12'", [])

        query ("DROP TABLE table1;", None)
        query ("DROP TABLE table3;", None)

        # Test begin/abort keywords
        query ("BEGIN", None)
        query ("ABORT", None)
        query ("BEGIN", None)
        query ("ROLLBACK", None)

    except Exception, e:
        print "FAIL: basic"
        traceback.print_exc (file=sys.stdout)
        query ("DROP TABLE table1;", verify=False)
        query ("DROP TABLE table2;", verify=False)
        query ("DROP TABLE table3;", verify=False)
    else:
        print "PASS: basic"
        

if dotest ('primarykey'):
    try:
        query ("CREATE TABLE table1 (id integer NOT NULL)", None)
        query ("CREATE TABLE table2 (id integer UNIQUE)", None)
        query ("CREATE TABLE table3 (id integer PRIMARY KEY)", None)
        query ("CREATE TABLE table4 (id integer NOT NULL,"
               "name varchar UNIQUE)", None)
        query ("CREATE TABLE table5 (id integer PRIMARY KEY,"
               "name varchar UNIQUE)", None)

        # Test table constraints
        query ("CREATE TABLE table6 (id integer, name varchar,"
               "UNIQUE (id, name))", None)

        query ("CREATE TABLE table7 (id integer, name varchar, "
               "PRIMARY KEY (id, name))", None)

        # Test unique constraint
        query ("INSERT INTO table2 (id) VALUES (1)", None)
        query ("INSERT INTO table2 (id) VALUES (1)", pg.ProgrammingError)

        # Test non-null constraint
        query ("INSERT INTO table4 (name) VALUES ('alice')", pg.ProgrammingError)
        query ("INSERT INTO table4 (id, name) VALUES (1, 'alice')", None)

    except Exception, e:
        print "FAIL: primarykey"
        traceback.print_exc (file=sys.stdout)
    else:
        print "PASS: primarykey"

    query ("DROP TABLE table1;", verify=False)
    query ("DROP TABLE table2;", verify=False)
    query ("DROP TABLE table3;", verify=False)
    query ("DROP TABLE table4;", verify=False)
    query ("DROP TABLE table5;", verify=False)
    query ("DROP TABLE table6;", verify=False)
    query ("DROP TABLE table7;", verify=False)

if dotest ('specialcase'):
    try:
        query ("CREATE TABLE table1 (foo varchar)", None)
        query ("CREATE TABLE table2 (foo varchar)", None)
        query ("CREATE TABLE table3 (foo varchar)", None)
        r = query ("SPECIALCASE gettablelist", verify=False)
        r = r.getresult ()
        for i in r:
            if len (i) != 1:
                raise Exception, "return tuple too large"
        r = [x[0] for x in r]
        for i in ('table1', 'table2', 'table3'):
            if i not in r:
                raise Exception, ("could not find %s in result %s" %
                                  (i, r))
    except Exception, e:
        print "FAIL: specialcase"
        traceback.print_exc (file=sys.stdout)
    else:
        print "PASS: specialcase"

    query ("DROP TABLE table1", verify=False)
    query ("DROP TABLE table2", verify=False)
    query ("DROP TABLE table3", verify=False)

if dotest ('foreignkey'):
    try:
        # Test foreign keys
        query ("CREATE TABLE table1 "
               "  (name varchar, nameid integer UNIQUE)", None)
        query ("CREATE TABLE table2 "
               "  (foo varchar, nameid integer UNIQUE, "
               "  FOREIGN KEY (nameid) "
               "    REFERENCES table1 (nameid))", None)

        # XXX The following queries should work but there's a bug in
        # DBV (for the first query) which causes table1's table labels
        # to disappear even though the DB does does not drop table1.
        #query ("DROP TABLE table1", pg.ProgrammingError)
        #query ("DROP TABLE table2", None)
        #query ("DROP TABLE table1", None)
    except Exception, e:
        print "FAIL: foreignkey"
        traceback.print_exc (file=sys.stdout)
    else:
        print "PASS: foriegnkey"
        query ("DROP TABLE table2", verify=False)
        query ("DROP TABLE table1", verify=False)

if dotest ('innerjoin'):
    try:
        create_join_data ()

        query ("SELECT emps.lname, emps.deptid, "
               "       depts.deptname, depts.deptid "
               "FROM emps, depts WHERE emps.xmin = depts.deptid "
               "ORDER BY emps.lname ASC;", pg.ProgrammingError)

        query ("SELECT emps.lname, emps.deptid, "
               "       depts.deptname, depts.deptid "
               "FROM emps, depts WHERE emps.deptid = depts.deptid "
               "ORDER BY emps.lname ASC;",
               [('jones',     33, 'engineering', 33),
                ('rafferty',  31, 'sales',       31),
                ('robinson',  34, 'clerical',    34),
                ('smith',     34, 'clerical',    34),
                ('steinberg', 33, 'engineering', 33)])

        query ("SELECT emps.lname, emps.deptid, "
               "       depts.deptname, depts.deptid "
               "FROM emps INNER JOIN depts ON emps.deptid = depts.deptid "
               "ORDER BY emps.lname ASC;",
               [('jones',     33, 'engineering', 33),
                ('rafferty',  31, 'sales',       31),
                ('robinson',  34, 'clerical',    34),
                ('smith',     34, 'clerical',    34),
                ('steinberg', 33, 'engineering', 33)])

        query ("SELECT emps.lname, emps.deptid, "
               "       zzz.deptname, zzz.deptid "
               "FROM emps INNER JOIN depts AS zzz ON emps.deptid = zzz.deptid "
               "ORDER BY emps.lname ASC;",
               [('jones',     33, 'engineering', 33),
                ('rafferty',  31, 'sales',       31),
                ('robinson',  34, 'clerical',    34),
                ('smith',     34, 'clerical',    34),
                ('steinberg', 33, 'engineering', 33)])

    except Exception, e:
        print "FAIL: innerjoin"
        traceback.print_exc (file=sys.stdout)
    else:
        print "PASS: innerjoin"

    remove_join_data (False)

if dotest ('leftjoin'):
    try:
        create_join_data ()
        query ("SELECT emps.lname, emps.deptid, "
               "       depts.deptname, depts.deptid "
               "FROM emps "
               "LEFT JOIN depts ON emps.deptid = depts.xmin "
               "ORDER BY emps.lname ASC;", pg.ProgrammingError)

        query ("SELECT emps.lname, emps.deptid, "
               "       depts.deptname, depts.deptid "
               "FROM emps "
               "LEFT JOIN depts ON emps.deptid = depts.deptid "
               "ORDER BY emps.lname ASC;",
               [('jasper',    36, None,          None),
                ('jones',     33, 'engineering', 33),
                ('rafferty',  31, 'sales',       31),
                ('robinson',  34, 'clerical',    34),
                ('smith',     34, 'clerical',    34),
                ('steinberg', 33, 'engineering', 33)])

        query ("SELECT emps.lname, emps.deptid, "
               "       depts.deptname, depts.deptid "
               "FROM emps "
               "LEFT OUTER JOIN depts ON emps.deptid = depts.deptid "
               "ORDER BY emps.lname ASC;",
               [('jasper',    36, None,          None),
                ('jones',     33, 'engineering', 33),
                ('rafferty',  31, 'sales',       31),
                ('robinson',  34, 'clerical',    34),
                ('smith',     34, 'clerical',    34),
                ('steinberg', 33, 'engineering', 33)])

    except Exception, e:
        print "FAIL: leftjoin"
        traceback.print_exc (file=sys.stdout)
    else:
        print "PASS: leftjoin"

    remove_join_data (False)

if dotest ('index'):
    try:
        query ("CREATE TABLE table1 (name varchar, id integer)", None)
        query ("CREATE INDEX table1_idx ON table1 (name, id)", None)
    except Exception, e:
        print "FAIL: index"
        traceback.print_exc (file=sys.stdout)
    else:
        print "PASS: index"
    query ("DROP TABLE table1", verify=False)

if dotest ('slabel'):
    # Setup a high S DB endpoint.
    #stag, scaps = flmu.makeTag ('e', 'dbg test s tag')

    lsd = LabelSetDesc (S=['ENV: MASTERE_CAP'],
                        CAPSET=['ENV: MASTERE_CAP, MASTERE_TOK'])
    lsd.acquire_capabilities ()
    lsd.set_my_label (flume.LABEL_S)

    conn_s = pg.connect (dbname, user=user, passwd=pw)
    flmo.setepopt(conn_s.fileno(), fix=True)
    flmo.set_label2 (S=None)

    try:
        query ("CREATE TABLE table1 (name varchar UNIQUE, id integer)", None)
        query ("INSERT INTO table1 (name, id) VALUES ('secret', 1)", None, conn=conn_s)
        query ("SELECT name, id FROM table1 WHERE name='secret'", [('secret', 1)], conn=conn_s)
        query ("SELECT name, id FROM table1 WHERE name='secret'", [])

        # Insert something with the larger S label, even though this
        # client (S={}) should not learn any secrets with the larger S
        # label.
        des_ls = flmo.LabelSet (S=lsd.get_label (flume.LABEL_S))
        query ("DESLS '%s'; INSERT INTO table1 (name, id) VALUES ('secret', 2)"
               % des_ls.toRaw().armor (), pg.ProgrammingError)

        # Doing the same insert with the high S connection should give
        # us a collision error
        #
        # XXX This test and the previous one have produce same error,
        # we should fix this test so we can tell what the actual error
        # is.
        des_ls = flmo.LabelSet (S=lsd.get_label (flume.LABEL_S))
        query ("DESLS '%s'; INSERT INTO table1 (name, id) VALUES ('secret', 2)"
               % des_ls.toRaw().armor (), pg.ProgrammingError, conn=conn_s)
        
    except Exception, e:
        print "FAIL: slabel"
        traceback.print_exc (file=sys.stdout)
    else:
        print "PASS: slabel"

    query ("DROP TABLE table1", verify=False)

def setup_masteri_data ():
    # Get master I to perform the test.
    lsd = LabelSetDesc (I=['ENV: MASTERI_CAP'],
                        CAPSET=['ENV: MASTERI_CAP, MASTERI_TOK'])
    lsd.acquire_capabilities ()

    # Connect with our I label set to I={MASTERI_TAG} so the endpoint labels are setup right.
    lsd.set_my_label (flume.LABEL_I)
    conn_i = pg.connect (dbname, user=user, passwd=pw)
    flmo.setepopt(conn_i.fileno(), fix=True)
    flmo.set_label2 (I=None)

    # Use the high integrity connection to perform high integrity create, insert, drop
    query ("CREATE TABLE table1 (name varchar, id integer)", None, conn=conn_i)
    query ("INSERT INTO table1 (name, id) VALUES ('alice', 1)", None, conn=conn_i)
    return conn_i, lsd

if dotest ('ilabel'):
    myitag, myicaps = flmu.makeTag ('i', 'dbg test i tag')
    try:
        conn_i, lsd = setup_masteri_data ()
        bigilabel = lsd.get_label (flume.LABEL_I) + myitag
        bigils = flmo.LabelSet (I=bigilabel)
    
        # Test discretionary DESLS.  Add an extra I tag to DESLS,
        # which should prevent the DB from returning 'alice'
        query ("DESLS '%s'; SELECT name FROM table1 WHERE id=1"
               % bigils.toRaw (). armor (), [], conn=conn_i)

        # Test per-row discretionary I tag restriction
        ilab = lsd.get_label (flume.LABEL_I)
        assert len (ilab) == 1
        query ("SELECT name FROM table1 "
               "  WHERE table1 ITAGEQ %s" % ilab[0].val (), [('alice',)])
        query ("SELECT name FROM table1 "
               "  WHERE table1 ITAGEQ %s" % myitag.val (), [])

        query ("DROP TABLE table1", None, conn=conn_i)
        conn_i.close ()
    except Exception, e:
        print "FAIL: ilabel"
        traceback.print_exc (file=sys.stdout)
    else:
        print "PASS: ilabel"

if dotest ('olabel'):
    # Get master W to perform the test.
    old_o = flmo.get_label (flume.LABEL_O)
    
    lsd = LabelSetDesc (O=['ENV: MASTERW_CAP'],
                        CAPSET=['ENV: MASTERW_CAP, MASTERW_TOK'])
    lsd.acquire_capabilities ()
    olabel = lsd.get_label (flume.LABEL_O)
    des_ls = flmo.LabelSet (O=olabel)

    try:
        # Show our W capability to the DB
        cos = flmo.CapabilityOpSet ([flmo.CapabilityOp (olabel[0], flume.CAPABILITY_SHOW)])
        flmo.send_capabilities (conn_emptylabel.fileno (), cos)

        query ("DESLS '%s'; MYOLABEL '%s'"
               % (des_ls.toRaw ().armor (), olabel.toRaw().armor()), pg.ProgrammingError)
        query ("DESLS '%s'; MYOLABEL '%s'; CREATE TABLE table1 (name varchar, id integer)"
               % (des_ls.toRaw ().armor (), olabel.toRaw().armor()), None)
        query ("DESLS '%s'; MYOLABEL '%s'; INSERT INTO table1 (name, id) VALUES ('alice', 1)"
               % (des_ls.toRaw ().armor (), olabel.toRaw().armor()), None)
        query ("DESLS '%s'; MYOLABEL '%s'; UPDATE table1 SET name='alice2' WHERE id=1"
               % (des_ls.toRaw ().armor (), olabel.toRaw().armor()), None)

        # fails without MYOLABEL, but does not report an error, DB just doesn't do the UPDATE
        query ("UPDATE table1 SET name='alice3' WHERE id=1", None)
        query ("SELECT name FROM table1 WHERE id=1", [('alice2',)])
        

        # XXX The following update should fail without proper
        # capabilities, but it does not.  This is because the DBV
        # verifies the EP capabilities for this query, but the fact
        # that we dropped capabilities just before does not carry over
        # to the DBV's verification, and the DBV thinks the client
        # still has O={wcap+}.

        # XXX Actually, the query itself will not throw an exceptions,
        # the DB just doesn't execute it because the way DBV works, it
        # does not check and update in a single transaction.  One day,
        # we should fix the DB so that it can return raise an error
        # rather than saying it did not perform the update.

        #flmo.set_label2 (O=old_o)
        #query ("MYOLABEL '%s'; UPDATE table1 SET name='alice4' WHERE id=1"
        #       % olabel.toRaw().armor(), None)
        #query ("SELECT name FROM table1 WHERE id=1", [('alice2',)])

        lsd.acquire_capabilities ()
        query ("MYOLABEL '%s'; DROP TABLE table1" % olabel.toRaw().armor(), None)
        
    except Exception, e:
        print "FAIL: olabel"
        traceback.print_exc (file=sys.stdout)
    else:
        print "PASS: olabel"

if dotest ('desls'):
    try:
        # Create a table with an S label
        lsd = LabelSetDesc (S=['ENV: MASTERE_CAP'],
                            CAPSET=['ENV: MASTERE_CAP, MASTERE_TOK'])
        lsd.acquire_capabilities ()
        query ("DESLS '%s'; CREATE TABLE table1 (name varchar, id integer)" %
               lsd.get_file_labelset ().toRaw ().armor (), None)
        query ("DROP TABLE table1", None)

        # Try to create a table with an I label, this should fail
        # even though we have MASTERI_CAP, because we don't put it in MYOLABEL
        lsd = LabelSetDesc (I=['ENV: MASTERI_CAP'],
                            CAPSET=['ENV: MASTERI_CAP, MASTERI_TOK'])
        lsd.acquire_capabilities ()
        query ("DESLS '%s'; CREATE TABLE table1 (name varchar, id integer)" %
               lsd.get_file_labelset ().toRaw ().armor (), pg.ProgrammingError)

    except Exception, e:
        print "FAIL: desls"
        traceback.print_exc (file=sys.stdout)
    else:
        print "PASS: desls"

if dotest ('filter'):
    # In this test, we create an I tag (itag) and install a filter
    # that replaces {masteri} -> {masteri, itag}

    # Insert master integrity data ('alice', 1)
    conn_master, lsd = setup_masteri_data ()

    # Make a new I tag and add it to mastergtag
    masteretag = LabelSetDesc.get_tags ('ENV: MASTERE_CAP')[0].toTag ()
    masteritag = LabelSetDesc.get_tags ('ENV: MASTERI_CAP')[0].toTag ()
    mastergtag = LabelSetDesc.get_tags ('ENV: MASTERGTAG_CAP')[0].toTag ()

    myitag, mycaps = flmu.makeTag ('pi', 'test i tag')

    lsdg = LabelSetDesc (I=['ENV: MASTERI_CAP'],
                         CAPSET=['ENV: MASTERI_CAP, MASTERI_TOK',
                                 'ENV: MASTERGTAG_CAP, MASTERGTAG_TOK'])
    lsdg.acquire_capabilities (savels=True)
    lsdg.set_my_label (flume.LABEL_I)
    flmo.add_to_group (mastergtag, flmo.Label (mycaps))
    lsdg.pop_labelset ()

    # Make the filter
    find = flmo.Label ([masteritag])
    repl = flmo.Label ([masteritag, myitag])
    caps = [ mycaps[0] ]

    lsdir = flmo.LabelSet (I=flmo.Label ([myitag]))
    lsfile = flmo.LabelSet (I=flmo.Label ([myitag]))

    dirname = os.path.sep.join (('/ihome', lsdir.to_filename ()))
    filename = os.path.sep.join ((dirname, 'filter.%s.%s' % (masteritag.armor32 (), myitag.armor32 ())))

    oldi = flmo.get_label (flume.LABEL_I)
    flmo.set_label2 (I=oldi + lsdir.get_I ())
    flmo.mkdir (dirname, labelset=lsdir)
    flms.makeFilter (name=filename, find=find, replace=repl, caps=caps, labelset=lsfile)

    # Apply the filter
    flmo.apply_filter (name=filename, typ=flume.LABEL_I)

    # Connect to the DB (I={masteri}) with our I label (I={myitag}) to
    # test the socket filter.
    conn_myi = pg.connect (dbname, user=user, passwd=pw)
    flmo.setepopt(conn_myi.fileno(), fix=True)
    
    try:
        # Try reading without filter, should return nothing.
        query ("SELECT name FROM table1 WHERE id=1", [], conn=conn_myi)
        
        # Try to read data with filter I={masteri}, which should be changed to I={myitag}
        query ("FILTER '%s'; SELECT name FROM table1 WHERE id=1" % filename, [('alice',)], conn=conn_myi)
        
    except Exception, e:
        print "FAIL: filter"
        traceback.print_exc (file=sys.stdout)
    else:
        print "PASS: filter"

    query ("DROP TABLE table1", None, conn=conn_master)
    conn_myi.close ()
    conn_master.close ()

if testing and len (testing) > 0:
    print "Could not find tests %s" % (testing,)
    sys.exit (1)

print "DONE"
sys.exit (0)
