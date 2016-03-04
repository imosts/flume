from django.conf.urls.defaults import *
from wikicode import url_fmt

m = ('',
     (r'^' + url_fmt + r'/?$', 'poke.views.index'),
     (r'^' + url_fmt + r'/upload/$', 'poke.views.upload'),

     # Called when the user is viewing his own profile
     (r'^' + url_fmt + r'/public/$', 'poke.views.public'),
     (r'^' + url_fmt + r'/friends/$', 'poke.views.friends'),
     (r'^' + url_fmt + r'/private/$', 'poke.views.private'),
     (r'^' + url_fmt + r'/pairwise/(\w+)/$', 'poke.views.pairwise'),

     # Called when the user is viewing someone else's profile
     (r'^' + url_fmt + r'/vpublic/$', 'poke.views.vpublic'),
     (r'^' + url_fmt + r'/vfriends/$', 'poke.views.vfriends'),
     (r'^' + url_fmt + r'/vprivate/$', 'poke.views.vprivate'),
     (r'^' + url_fmt + r'/vpairwise/(\w+)/$', 'poke.views.vpairwise'),

     (r'^' + url_fmt + r'/poke_js/$', 'poke.views.poke_js'),

)                   
urlpatterns = patterns (*m)
