import sys, os
from wikicode.db.user import User
from django.core.management import setup_environ as setup_environ_orig

def setup_environ_wrapper (devel, projname):
    """
    Django is always invoked with a particular project/application in
    mind.  <devel> is the username of the developer who wrote that
    project/appliation.
    
    """
    
    # Add the developer's project directory to the python path
    devel = User (devel)
    projectdir = os.path.sep.join ((devel.script_loc (), projname))
    sys.path.append (projectdir)

    import settings
    setup_environ_orig (settings, projectdir)

