import pgdb
import flume.flmos as flmo

flmo.set_libc_interposing (True)
conn = pgdb.connect ('dbname=test user=yipal password=pw host=/var/run/postgresql')
cur = conn.cursor ()
cur.execute ("select * from testtable;")
print cur.fetchall ()
