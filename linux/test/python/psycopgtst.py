import psycopg2, DBV
import flume.flmos as flmo
from flume.profile import start, total, print_delta

start ()

dbname, user, pw = DBV.default_db_user_pw ()

flmo.set_libc_interposing (True)

conn = psycopg2.connect ('dbname=%s user=%s password=%s '
                         'host=/var/run/postgresql' % (dbname, user, pw))
print_delta ("connect")
cur = conn.cursor ()
print_delta ("cursor")

cur.execute ("create table table1 (name varchar)")
print_delta ("create")

cur.execute ("insert into table1 (name) values ('alice')")
print_delta ("insert")

r = cur.execute ("update table1 set name='bob' where name='alice'")
print_delta ("update")

print "modified %d rows" % cur.rowcount

cur.execute ("select name from table1")
print_delta ("select")

print cur.fetchall ()
print_delta ("fetch")


cur.execute ("drop table table1")
print_delta ("drop")

cur.execute ("commit")
print_delta ("commit")

cur.close ()
print_delta ("cursor_close")

conn.close ()
print_delta ("conn_close")

print "total %f" % total ()
