import DBV, pg
import DBV.sqlparser
import DBV.util
import DBV.security
import DBV.translator
import flume.flmos as flmo
from DBV.semantics import *


if __name__ == '__main__':

    #query = "SELECT x FROM bla alias WHERE uid=1234 and (foo=222 or bar=333)"
    #query = "SELECT DISTINCT pno FROM sp a WHERE pno IN (SELECT pno FROM sp b WHERE a.sno <> b.sno)"
    #query = "SELECT a.name FROM foo, bar b WHERE uid=3;"
    #query = "SELECT * FROM foo a, bar b WHERE uid=3 ORDER BY name ASC;"
    #query = 'CREATE TABLE bla1 (col1 integer, col2 varchar);'
    #query = 'CREATE TABLE bla1 (col1 integer, col2 varchar); CREATE TABLE bla2 (col1 integer)'
    #query = 'INSERT INTO xx (name, name2) VALUES (\'Foo\', 4+5+6+7)'
    #query = 'INSERT INTO xx (name, name2) SELECT * FROM bla;'
    #query = 'UPDATE xx set name=\'Alex\', username=\'yipal\' where uid=3'
    query = 'DELETE FROM xxx WHERE name=\'Alex\''

    parser = DBV.sqlparser.SQLParser ()
    conn = pg.connect ('test', 'sweat.lcs.mit.edu', 5432, user='yipal', passwd='pw')
    try:
        parsetree = parser.parse (query)
        print 'Orig Query: %s' % str (parsetree)
        print 'Pretty:\n%s' % parsetree.prettyformat()

        empty = flmo.Label ()
        testlabel = flmo.Label ( [flmo.Handle(123)] )
        testlabel2 = flmo.Label ( [flmo.Handle(456), flmo.Handle(789)] )

        desired_ls = flmo.LabelSet (S=empty, I=empty, O=empty)
        client_ls = flmo.LabelSet (S=empty, I=empty, O=empty)
        
        DBV.security.handle_query (parsetree, conn, client_ls, desired_ls)
        DBV.translator.handle_query (parsetree, conn, None, None, client_ls, desired_ls)

    except DBV.ParseError, e:
        print 'Malformed Query: %s' % e

    except DBV.SecurityViolation, e:
        print 'Security violation: %s' % e
        

