# Django settings for mysite project.

import DBV, os
try:
    pyvers = os.environ['PYVERS']
except KeyError:
    import sys
    pyvers = '%d.%d' % (sys.version_info[0], sys.version_info[1])

dbname, user, pw, sockname, sockdir = DBV.default_db_user_pw ()
    
DEBUG = True
TEMPLATE_DEBUG = DEBUG

ADMINS = (
    # ('Your Name', 'your_email@domain.com'),
)

MANAGERS = ADMINS

DATABASE_ENGINE = 'flumedb'    # 'postgresql_psycopg2', 'postgresql', 'mysql', 'sqlite3' or 'ado_mssql'.
DATABASE_NAME = dbname         # Or path to database file if using sqlite3.
DATABASE_USER = user           # Not used with sqlite3.
DATABASE_PASSWORD = pw         # Not used with sqlite3.
DATABASE_HOST = ''             # Set to empty string for localhost. Not used with sqlite3.
DATABASE_PORT = ''             # Set to empty string for default. Not used with sqlite3.
DATABASE_TIMEOUT = 3

REDIRECT_WITH_HOST = False

# Local time zone for this installation. Choices can be found here:
# http://www.postgresql.org/docs/8.1/static/datetime-keywords.html#DATETIME-TIMEZONE-SET-TABLE
# although not all variations may be possible on all operating systems.
# If running in a Windows environment this must be set to the same as your
# system time zone.
TIME_ZONE = 'America/Chicago'

# Language code for this installation. All choices can be found here:
# http://www.w3.org/TR/REC-html40/struct/dirlang.html#langcodes
# http://blogs.law.harvard.edu/tech/stories/storyReader$15
LANGUAGE_CODE = 'en-us'

SITE_ID = 1

# If you set this to False, Django will make some optimizations so as not
# to load the internationalization machinery.
USE_I18N = True

# Absolute path to the directory that holds media.
# Example: "/home/media/media.lawrence.com/"
MEDIA_ROOT = ''

# URL that handles the media served from MEDIA_ROOT.
# Example: "http://media.lawrence.com"
MEDIA_URL = ''

# URL prefix for admin media -- CSS, JavaScript and images. Make sure to use a
# trailing slash.
# Examples: "http://foo.com/media/", "/media/".
ADMIN_MEDIA_PREFIX = '/media/'

# Make this unique, and don't share it with anybody.
SECRET_KEY = 'mty%6ecx$t^s^$xr$dc=rzk6o1k@&yyi*%1y)4ew9*096c_3ok'

# List of callables that know how to import templates from various sources.
TEMPLATE_LOADERS = [
    'django.template.loaders.filesystem.load_template_source',
    'django.template.loaders.app_directories.load_template_source',
#     'django.template.loaders.eggs.load_template_source',
]

MIDDLEWARE_CLASSES = [
    'django.middleware.common.CommonMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.middleware.doc.XViewMiddleware',
#    'project.trusted.middleware.LabellingMiddleware',
]

ROOT_URLCONF = 'YOUR.SETTINGS.PY.MUST.POINT.TO.A.URLS.PY'

TEMPLATE_DIRS = [
    # Put strings here, like "/home/html/django_templates" or "C:/www/django/templates".
    # Always use forward slashes, even on Windows.
    # Don't forget to use absolute paths, not relative paths.
    '/disk/%s/flume/run/lib/python%s/site-packages/django/contrib/admin/templates' % (user,pyvers),
]

INSTALLED_APPS = [
#    'django.contrib.admin', # Admin needs to be an untrusted app
#    'django.contrib.auth',
    'django.contrib.sessions',
#    'django.contrib.contenttypes',
#    'django.contrib.sites',
#    'project.polls',
#    'project.trusted',
]
