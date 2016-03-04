import os, os.path, wikicode
from wikicode.util import *
from wikicode.const import *

# Experiment Variables:
EXP_NUSERS = 1000
EXP_NPUB_PHOTOS = 8
EXP_NFR_PHOTOS = 2


FILELIST_FILENAME = 'filelist'

SRCDIR = os.popen ('flume-cfg srcdir').read ().strip ()
PYVERS  = os.popen ('flume-cfg pyvers').read ().strip ()
PW = 'pw'

def install_filelist (dirname, packagename, install_list):
    # Install a set of files.  The files are listed in
    # <dirname>/filelist and the install tuple will be appended to
    # <install_list>.
    files = read_file (os.path.join (dirname, FILELIST_FILENAME),
                       interpose=False).splitlines ()
    src_files = [os.path.join (dirname, 'lib/python%s/site-packages/%s'
                               % (PYVERS, packagename), f)
                 for f in files]
    
    for src, dst in zip (src_files, files):
        install_list.append ((src, dst))

# Setup Applications:
user_root = os.path.join (SRCDIR, 'app', 'web', 'python', 'wikicode')

app_common = os.path.join (user_root, 'app-common')
w5djangoutil = os.path.join (app_common, 'w5djangoutil.py')
rundjango = os.path.join (app_common, 'rundjango.py')
forkdjango = os.path.join (app_common, 'forkdjango.py')
settingspy = os.path.join (app_common, 'settings.py')

djangotools_dir = os.path.join (user_root, 'django-tools')
djangotools_files = [
    'main.py',
    'syncdb.py',
    (w5djangoutil, 'w5djangoutil.py'),
    'djangotools/__init__.py',
    'djangotools/default_settings.py',
    'djangotools/util.py',
    ]
if USE_DJANGOZIP:
    djangotools_files.append ((os.path.join (SRCDIR, '../django/build/install/django.zip'), 'django.zip'))
else:
    install_filelist (os.path.join (SRCDIR, '../django/build/install'), '', djangotools_files)

blog_dir = os.path.join (user_root, 'blog')
blog_files = [
    (rundjango, 'rundjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    'blog/__init__.py',
    'blog/models.py',
    (settingspy, 'blog/settings.py'),
    'blog/urls.py',
    'blog/views.py',
    'blog/templates/index.html',
    'blog/templates/upload.html',
    'blog/templates/newblog.html',
    'blog/templates/newpost.html',
    'blog/templates/search.html',
    'blog/templates/viewblog.html',
    ]
blog_static_files = (
    'blog/static/The_BLOG.jpg',
    'blog/static/blog/widgets.html',
    'blog/static/blog/widgets-secret.html',
    )

photoapp_dir = os.path.join (user_root, 'photoapp')
photoapp_files = [
    (rundjango, 'rundjango.py'),
    (forkdjango, 'forkdjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    'photoapp/__init__.py',
    (settingspy, 'photoapp/settings.py'),
    'photoapp/urls.py',
    'photoapp/models.py',
    'photoapp/views.py',
    'photoapp/templates/index.html',
    'photoapp/templates/newphoto.html',
    'photoapp/templates/newalbum.html',
    'photoapp/templates/upload.html',
    'photoapp/templates/viewalbum.html',
    'photoapp/templates/slideshow.html',
    ]

calendarapp_dir = os.path.join (user_root, 'calendarapp')
calendarapp_files = (
    (rundjango, 'rundjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    (settingspy, 'calendarapp/settings.py'),
    'calendarapp/urls.py',
    'calendarapp/__init__.py',
    'calendarapp/models.py',
    'calendarapp/views.py',
    'calendarapp/templates/event_detail.html',
    'calendarapp/templates/project_detail.html',
    'calendarapp/templates/schedule_cal.html',
    'calendarapp/templates/month_cal.html',
    'calendarapp/templates/upload.html',
    'calendarapp/templates/newevent.html',
    'calendarapp/templatetags/__init__.py',
    'calendarapp/templatetags/schedule_cal.py',
    )

newcalendarapp_dir = os.path.join (user_root, 'newcalendarapp')
newcalendarapp_files = (
    (rundjango, 'rundjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    (settingspy, 'newcalendarapp/settings.py'),
    'newcalendarapp/urls.py',
    'newcalendarapp/__init__.py',
    'newcalendarapp/models.py',
    'newcalendarapp/views.py',
    'newcalendarapp/templates/event_detail.html',
    'newcalendarapp/templates/project_detail.html',
    'newcalendarapp/templates/schedule_cal.html',
    'newcalendarapp/templates/month_cal.html',
    'newcalendarapp/templates/upload.html',
    'newcalendarapp/templates/newevent.html',
    'newcalendarapp/templatetags/__init__.py',
    'newcalendarapp/templatetags/schedule_cal.py',
    )


photoedit_dir = os.path.join (user_root, 'photoedit')
photoedit_files = [
    (rundjango, 'rundjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    'photoedit/__init__.py',
    (settingspy, 'photoedit/settings.py'),
    'photoedit/urls.py',
    'photoedit/models.py',
    'photoedit/views.py',
    'photoedit/templates/editphoto.html',
    'photoedit/templates/objlist.html',
    ]

install_filelist (os.path.join (SRCDIR, '../Imaging-1.1.6/build/install'),
                  'PIL', photoedit_files)

weathergrabber_dir = os.path.join (user_root, 'weathergrabber')
weathergrabber_files = [
    (rundjango, 'rundjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    'weathergrabber/__init__.py',
    (settingspy, 'weathergrabber/settings.py'),
    'weathergrabber/urls.py',
    'weathergrabber/models.py',
    'weathergrabber/views.py',
    'weathergrabber/templates/weather.html',
    ]

testapp_dir = os.path.join (user_root, 'testapp')
testapp_files = [
    (rundjango, 'rundjango.py'),
    (forkdjango, 'forkdjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    'testapp/__init__.py',
    (settingspy, 'testapp/settings.py'),
    'testapp/urls.py',
    'testapp/models.py',
    'testapp/views.py',
    'testapp/templates/index.html',
    'testapp/templates/postmessage.html',
    'testapp/templates/postmessage1.html',
    'testapp/templates/postmessage2.html',
    'testapp/templates/postmessage_subframe.html',
    'testapp/templates/postmessage_subframe1.html',
    'testapp/templates/callfunction.html',
    'testapp/templates/fid_test.html',
    'testapp/templates/storage_test.html',
    'testapp/templates/augment_label.html',
    'testapp/templates/augment_label_subframe.html',
    'testapp/templates/augment_label_subsubframe.html',
    ]

forktestapp_dir = os.path.join (user_root, 'forktestapp')
forktestapp_files = [
    (rundjango, 'rundjango.py'),
    (forkdjango, 'forkdjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    'forktestapp/__init__.py',
    (settingspy, 'forktestapp/settings.py'),
    'forktestapp/urls.py',
    'forktestapp/models.py',
    'forktestapp/views.py',
    ]

facebook_dir = os.path.join (user_root, 'facebook')
facebook_files = [
    (rundjango, 'rundjango.py'),
    (forkdjango, 'forkdjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    'facebook/__init__.py',
    (settingspy, 'facebook/settings.py'),
    'facebook/urls.py',
    'facebook/models.py',
    'facebook/views.py',
    'facebook/templates/upload.html',
    'facebook/templates/viewprofile.html',
    'facebook/templates/app_iframe.html',
    ]

widgets_dir = os.path.join (user_root, 'widgets')
widgets_files = [
    (rundjango, 'rundjango.py'),
    (forkdjango, 'forkdjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    'widgets/__init__.py',
    (settingspy, 'widgets/settings.py'),
    'widgets/urls.py',
    'widgets/views.py',
    'widgets/templates/viewprofile.html',
    ]

widgets_static_files = (
    'widgets/static/json-secret.html',
    'widgets/static/json2-secret.html',
    )


widgetapp_dir = os.path.join (user_root, 'widgetapp')
widgetapp_files = [
    (rundjango, 'rundjango.py'),
    (forkdjango, 'forkdjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    'widgetapp/__init__.py',
    (settingspy, 'widgetapp/settings.py'),
    'widgetapp/urls.py',
    'widgetapp/views.py',

    'widgetapp/templates/index.html',
    'widgetapp/templates/widgets-twitter.html',
    'widgetapp/templates/widgets-evil.html',
    'widgetapp/templates/widgets-link.html',
    'widgetapp/templates/widgets-puppies.html',
    'widgetapp/templates/widgets-popular.html',
    'widgetapp/templates/widgets-comments.html',
    'widgetapp/templates/widgets-recent-posts.html',
    'widgetapp/templates/widgets-calendar.html',
    'widgetapp/templates/widgets-youtube.html',
    'widgetapp/templates/widgets-history.html',
    'widgetapp/templates/widgets-labels.html',
    'widgetapp/templates/widgets-random.html',
    'widgetapp/templates/widgets-frame1.html',
    'widgetapp/templates/widgets-frame2.html',

    'widgetapp/templates/widgets-cbox-parent.html',
    'widgetapp/templates/widgets-cbox-main.html',
    'widgetapp/templates/widgets-cbox-form.html',
    'widgetapp/templates/widgets-cbox.js',
    'widgetapp/templates/widgets-cbox-css.css',
    'widgetapp/templates/widgets-cbox-frametest1.html',
    'widgetapp/templates/widgets-cbox-frametest2.html',

    'widgetapp/templates/widgets-blog-content.html',
    ]
widgetapp_static_files = (
    'widgets/static/json-secret.html',
    )

poke_dir = os.path.join (user_root, 'poke')
poke_files = [
    (rundjango, 'rundjango.py'),
    (forkdjango, 'forkdjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    'poke/__init__.py',
    (settingspy, 'poke/settings.py'),
    'poke/urls.py',
    'poke/models.py',
    'poke/views.py',
    'poke/templates/readall.html',
    'poke/templates/sendpoke.html',
    'poke/templates/poke.js',
    ]

wall_dir = os.path.join (user_root, 'wall')
wall_files = [
    (rundjango, 'rundjango.py'),
    (forkdjango, 'forkdjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    'wall/__init__.py',
    (settingspy, 'wall/settings.py'),
    'wall/urls.py',
    'wall/models.py',
    'wall/views.py',
    'wall/templates/readall.html',
    'wall/templates/newpost.html',
    ]

compare_dir = os.path.join (user_root, 'compare')
compare_files = [
    (rundjango, 'rundjango.py'),
    (forkdjango, 'forkdjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    'compare/__init__.py',
    (settingspy, 'compare/settings.py'),
    'compare/urls.py',
    'compare/models.py',
    'compare/views.py',
    'compare/templates/private.html',
    'compare/templates/compare.js',
    ]

storage_dir = os.path.join (user_root, 'storage')
storage_files = [
    (rundjango, 'rundjango.py'),
    (forkdjango, 'forkdjango.py'),
    (w5djangoutil, 'w5djangoutil.py'),
    'storage/__init__.py',
    (settingspy, 'storage/settings.py'),
    'storage/urls.py',
    'storage/models.py',
    'storage/views.py',
    'storage/templates/test.html',
    ]

nullcgipy_dir = os.path.join (user_root, 'nullcgipy')
nullcgipy_files = [ ('nullcgi.py') ]

nullcgic_dir = os.path.join (user_root, 'nullcgic')
nullcgic_files = [ (os.path.join (SRCDIR, 'build-tree/obj/clnt/microbench/.libs/nullcgi'), 'nullcgi') ]

if USE_FROZEN:
    def add_exists (dir, fn, filelist):
        src = os.path.join (dir, fn)
        if file_exists (src, interpose=False):
            filelist.append ((src, fn))

    add_exists (blog_dir, 'rundjango', blog_files)
    add_exists (photoapp_dir, 'rundjango', photoapp_files)
    add_exists (calendarapp_dir, 'rundjango', calendarapp_files)
    add_exists (newcalendarapp_dir, 'rundjango', newcalendarapp_files)
    add_exists (weathergrabber_dir, 'rundjango', weathergrabber_files)
    add_exists (nullcgipy_dir, 'nullcgi', nullcgipy_files)

# Format: [username, password, extratags=[], instances=[], declassifiers=[], srcdir, scriptfiles, staticfiles]
developers = [('djangotools', PW, [], [], [], djangotools_dir, djangotools_files, []),
              ('blog', PW, [], [], [], blog_dir, blog_files, blog_static_files),
              ('photoapp', PW, [], [], [], photoapp_dir, photoapp_files, []),
              ('calendarapp', PW, [], [], [], calendarapp_dir, calendarapp_files, []),
              ('newcalendarapp', PW, [], [], [], newcalendarapp_dir, newcalendarapp_files, []),
              ('photoedit', PW, [], [], [], photoedit_dir, photoedit_files, []),
              ('testapp', PW, [], [], [], testapp_dir, testapp_files, []),
              ('forktestapp', PW, [], [], [], forktestapp_dir, forktestapp_files, []),
              ('facebook', PW, [], [], [], facebook_dir, facebook_files, []),
              ('widgets', PW, [], [], [], widgets_dir, widgets_files, widgets_static_files),
              ('widgetapp', PW, [], [], [], widgetapp_dir, widgetapp_files, []),
              ('poke', PW, [], [], [], poke_dir, poke_files, []),
              ('wall', PW, [], [], [], wall_dir, wall_files, []),
              ('compare', PW, [], [], [], compare_dir, compare_files, []),
              ('storage', PW, [], [], [], storage_dir, storage_files, []),
              ('weathergrabber', PW, [], [], [], weathergrabber_dir, weathergrabber_files, []),
              ('nullcgipy', PW, [], [], [], nullcgipy_dir, nullcgipy_files, []),
              ('nullcgic', PW, [], [], [], nullcgic_dir, nullcgic_files, []),
              ]

integrity_filters = (('blog', 'djangotools'),
                     ('calendarapp', 'djangotools'),                     
                     ('newcalendarapp', 'djangotools'),                     
                     ('newcalendarapp', 'calendarapp'),                     
                     ('photoapp', 'djangotools'),
                     ('photoedit', 'djangotools'),
                     ('photoedit', 'photoapp'),
                     ('testapp', 'djangotools'),
                     ('forktestapp', 'djangotools'),
                     ('facebook', 'djangotools'),
                     ('widgets', 'djangotools'),
                     ('widgetapp', 'djangotools'),
                     ('poke', 'djangotools'),
                     ('wall', 'djangotools'),
                     ('storage', 'djangotools'),
                     ('compare', 'djangotools'),
                     ('compare', 'facebook'),
                     )

django_apps = {
    'blog':
    {'name': 'Blogger',
     'script': 'rundjango.py',
     'fullscript': rundjango,
     'syncdb': True, 'freeze': False,
     'srcdir': blog_dir,
     'mode': W5MODE_UNTRUSTED_PYFORK},

    'calendarapp':
    {'name': 'CalendarApp',
     'script': 'rundjango.py',
     'fullscript': rundjango,
     'syncdb': True, 'freeze': False,
     'srcdir': calendarapp_dir,
     'mode': W5MODE_UNTRUSTED_PYFORK},

    'newcalendarapp':
    {'name': 'Calendar2',
     'script': 'rundjango.py',
     'fullscript': rundjango,
     'syncdb': True, 'freeze': False,
     'srcdir': newcalendarapp_dir,
     'mode': W5MODE_UNTRUSTED_PYFORK},
    
    'photoapp':
    {'name': 'PhotoApp',
     'script': 'forkdjango.py',
     'fullscript': forkdjango,
     'syncdb': True, 'freeze': False,
     'srcdir': photoapp_dir,
     'mode': W5MODE_UNTRUSTED_PYFORK},
    
    'photoedit':
    {'name': 'PhotoEdit',
     'script': 'rundjango.py',
     'fullscript': rundjango,
     'syncdb': True, 'freeze': False,
     'srcdir': photoedit_dir,
     'mode': W5MODE_UNTRUSTED_PYFORK},
    
    'testapp':
    {'name': 'TestApp',
     'script': 'forkdjango.py',
     'fullscript': forkdjango,
     'syncdb': True, 'freeze': False,
     'srcdir': testapp_dir,
     'mode': W5MODE_UNTRUSTED_PYFORK},
    
    'forktestapp':
    {'name': 'ForkTestApp',
     'script': 'forkdjango.py',
     'fullscript': forkdjango,
     'syncdb': True, 'freeze': False,
     'srcdir': forktestapp_dir,
     'mode': W5MODE_UNTRUSTED_PYFORK},
    
    'facebook':
    {'name': 'Facebook',
     'script': 'forkdjango.py',
     'fullscript': forkdjango,
     'syncdb': True, 'freeze': False,
     'srcdir': facebook_dir,
     'mode': W5MODE_TRUSTED_PYAPP_FORK},

    'widgets':
    {'name': 'Widgets in Iframes',
     'script': 'forkdjango.py',
     'fullscript': forkdjango,
     'syncdb': True, 'freeze': False,
     'srcdir': widgets_dir,
     'mode': W5MODE_TRUSTED_PYAPP_FORK},

    'widgetapp':
    {'name': 'Widgetapp (run Widgets in Iframes instead)',
     'script': 'forkdjango.py',
     'fullscript': forkdjango,
     'syncdb': True, 'freeze': False,
     'srcdir': widgetapp_dir,
     'mode': W5MODE_UNTRUSTED_PYFORK},

    'poke':
    {'name': 'Poke',
     'script': 'forkdjango.py',
     'fullscript': forkdjango,
     'syncdb': True, 'freeze': False,
     'srcdir': poke_dir,
     'mode': W5MODE_UNTRUSTED_PYFORK},

    'wall':
    {'name': 'Wall',
     'script': 'forkdjango.py',
     'fullscript': forkdjango,
     'syncdb': True, 'freeze': False,
     'srcdir': wall_dir,
     'mode': W5MODE_UNTRUSTED_PYFORK},

    'compare':
    {'name': 'Compare',
     'script': 'forkdjango.py',
     'fullscript': forkdjango,
     'syncdb': True, 'freeze': False,
     'srcdir': compare_dir,
     'mode': W5MODE_UNTRUSTED_PYFORK},

    'storage':
    {'name': 'Storage',
     'script': 'forkdjango.py',
     'fullscript': forkdjango,
     'syncdb': True, 'freeze': False,
     'srcdir': storage_dir,
     'mode': W5MODE_UNTRUSTED_PYFORK},

    'weathergrabber':
    {'name': 'WeatherGrabber',
     'script': 'rundjango.py',
     'fullscript': rundjango,
     'syncdb': True, 'freeze': False,
     'srcdir': weathergrabber_dir,
     'mode': W5MODE_UNTRUSTED_PYFORK},
    
    'djangotools':
    {'name': 'SyncDB',
     'script': 'syncdb.py',
     'fullscript': rundjango,
     'syncdb': False, 'freeze': False,
     'srcdir': djangotools_dir,
     'mode': W5MODE_UNTRUSTED_PY},
    
    'nullcgipy':
    {'name': 'nullcgi.py',
     'script': 'nullcgi.py',
     'fullscript': os.path.join (user_root, 'nullcgipy', 'nullcgi.py'),
     'syncdb': False, 'freeze': False,
     'srcdir': nullcgipy_dir,
     'mode': W5MODE_UNTRUSTED_PY},

    'nullcgic':
    {'name': 'nullcgic',
     'script': 'nullcgi',
     'syncdb': False, 'freeze': False,
     'srcdir': nullcgic_dir,
     'mode': W5MODE_UNTRUSTED_BIN},
    }


# Setup Debug Users:
debug_users = [('alice', PW,
                # Additional Tags
                [('pe', 'friends'),
                 ('pe', 'family')],
                [FRIEND_ACL_NAME],                        # ACL instances
                [('friends', FRIEND_ACL_NAME)],           # ACL asignments
                ),

               ('bob', PW,
                [('pe', 'friends'),
                 ('pe', 'family')],
                [FRIEND_ACL_NAME],
                [('friends', FRIEND_ACL_NAME)],
                ),

               ('carol', PW,
                [('pe', 'friends'),
                 ('pe', 'family')],
                [FRIEND_ACL_NAME],
                [('friends', FRIEND_ACL_NAME)],
                ),
               
               ('nullcgipy', PW, [], [], []),
               ('nullcgic', PW, [], [], []),
]

debug_acls = (
    ('alice', [(FRIEND_ACL_NAME, ('bob',))]),
    ('bob',   [(FRIEND_ACL_NAME, ('alice', 'carol'))]),
    ('carol', [(FRIEND_ACL_NAME, ('bob',))]),
    )

public_jpg, friends_jpg, family_jpg = [os.path.join (photoapp_dir, 'static', fn)
                                       for fn in ('public.jpg', 'friends.jpg', 'family.jpg')]
pub_album_files = [(public_jpg, 'pub1.jpg', []),
                   (public_jpg, 'pub2.jpg', [])]
fr_album_files = [(friends_jpg, 'fr1.jpg', ['friends']),
                  (friends_jpg, 'fr2.jpg', ['friends'])]

debug_photoapp_data = (('alice', [('public_album', pub_album_files),
                                  ('friends_album', fr_album_files)]),
                       ('bob',   [('public_album', pub_album_files),
                                  ('friends_album', fr_album_files)]),
                       )

## Experiment Setup Data
exp_users = [('user%d' % i, PW,
              [('pe', 'friends'), ('pw', 'wtag_app_photoapp')])
             for i in range (EXP_NUSERS)]
exp_acls = ()

exp_album_files = []
exp_album_files += [(public_jpg, 'pub%d.jpg' % i, []) for i in range (EXP_NPUB_PHOTOS)]
exp_album_files += [(friends_jpg, 'fr%d.jpg' % i, ['friends']) for i in range (EXP_NFR_PHOTOS)]

# Only one album
exp_photoapp_data = [(u[0], [('album', exp_album_files)]) 
                     for u in exp_users]

setup_data_debug = {'users': developers + debug_users,
                    'acls': debug_acls,
                    'apps': django_apps,
                    'filters': integrity_filters,
                    'photoapp_data': debug_photoapp_data}

setup_data_experiment = {'users': developers + exp_users + debug_users,
                         'acls': exp_acls,
                         'apps': django_apps,
                         'filters': integrity_filters,
                         'photoapp_data': exp_photoapp_data}

