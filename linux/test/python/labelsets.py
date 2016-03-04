
import flume.flmos as flmo
import flume.util as flmu
import flume as flm

def makefile (ls):
    fn = ls.to_filename ()
    print "Labselset: %s"  % ls
    print " -> filename: %s" % fn
    d = "/ihome/" + fn
    print "Mkdir: %s" % d
    flmo.mkdir (d, 0777, ls)
    f = d + "/foo"
    flmo.writefile (f, "hi dawg\n", 0644, ls)
    print "readfile: %s" % f
    
    print open (f, "r").readlines ()
    
    print "Label on file: %s" %  flmo.stat_file (f)

i,_ = flmu.makeTag ("ip", "foo")
s,_ = flmu.makeTag ("ep", "foo")
_,w = flmu.makeTag ("wp", "foo")

ls = flmo.LabelSet (S = flmo.Label ([s]),
                   I = flmo.Label ([i]),
                   O = flmo.Label (w) )


flmo.set_label (flm.LABEL_I, ls.get_I())
flmo.set_label (flm.LABEL_S, ls.get_S ())

makefile (ls)
flmo.set_label (flm.LABEL_I)
ls.set_I ()
makefile (ls)
ls.set_O ()
makefile (ls)
flmo.set_label (flm.LABEL_S)
ls.set_S ()
makefile (ls)
