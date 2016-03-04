from djangotools.default_settings import *
from wikicode.db.user import User
import os, wikicode

developer = os.environ[wikicode.DEVEL_UN_ENV]
d = User (developer)

projname = developer
TEMPLATE_DIRS.append (os.path.sep.join ((d.script_loc (), projname, 'templates')))

INSTALLED_APPS.append ('django.contrib.w5')
INSTALLED_APPS.append (projname)

ROOT_URLCONF = projname + '.urls'




