
import compileall

# Perform same compilation, excluding files in .svn directories.
import re
compileall.compile_dir('PREFIX/lib/python2.4/site-packages', rx=re.compile('/[.]svn'), force=True)

