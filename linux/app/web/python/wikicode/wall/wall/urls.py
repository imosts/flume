from django.conf.urls.defaults import *
from wikicode import url_fmt

m = ('',
     (r'^' + url_fmt + r'/?$', 'wall.views.index'),
     (r'^' + url_fmt + r'/upload/$', 'wall.views.upload'),
     (r'^' + url_fmt + r'/savepost/(\w+)/$', 'wall.views.savepost'),
     

     # Called when the user is viewing his own profile
     (r'^' + url_fmt + r'/public/$', 'wall.views.public'),
     (r'^' + url_fmt + r'/friends/$', 'wall.views.friends'),
     (r'^' + url_fmt + r'/private/$', 'wall.views.private'),
     (r'^' + url_fmt + r'/pairwise/(\w+)/$', 'wall.views.pairwise'),

     # Called when the user is viewing someone else's profile
     (r'^' + url_fmt + r'/vpublic/(\w+)/$', 'wall.views.vpublic'),
     (r'^' + url_fmt + r'/vfriends/(\w+)/$', 'wall.views.vfriends'),
     (r'^' + url_fmt + r'/vprivate/(\w+)/$', 'wall.views.vprivate'),
     (r'^' + url_fmt + r'/vpairwise/(\w+)/$', 'wall.views.vpairwise'),
)                   
urlpatterns = patterns (*m)
