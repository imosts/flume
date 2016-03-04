import sys, os.path
import flume.flmos as flmo
from flume.profile import start, print_delta 

start ()

prefix = os.path.dirname (sys.argv[0])
argv =  [ sys.executable, prefix + "/null.py" ]
print_delta ("before spawn")

ch = flmo.spawn (prog=argv[0], argv=argv, confined=False)
print_delta ("after spawn")

(pid, status, visible) = flmo.waitpid ()
print_delta ("after wait")



    
