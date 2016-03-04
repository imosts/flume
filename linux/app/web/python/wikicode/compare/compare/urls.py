from django.conf.urls.defaults import *
from wikicode import url_fmt

m = ('',
     (r'^' + url_fmt + r'/?$', 'compare.views.index'),
     (r'^' + url_fmt + r'/upload/$', 'compare.views.upload'),

     # Called when the user is viewing his own profile
     (r'^' + url_fmt + r'/public/$', 'compare.views.public'),
     (r'^' + url_fmt + r'/friends/$', 'compare.views.friends'),
     (r'^' + url_fmt + r'/private/$', 'compare.views.private'),
     (r'^' + url_fmt + r'/pairwise/(\w+)/$', 'compare.views.pairwise'),

     # Called when the user is viewing someone else's profile
     (r'^' + url_fmt + r'/vpublic/(\w+)/$', 'compare.views.vpublic'),
     (r'^' + url_fmt + r'/vfriends/(\w+)/$', 'compare.views.vfriends'),
     (r'^' + url_fmt + r'/vprivate/(\w+)/$', 'compare.views.vprivate'),
     (r'^' + url_fmt + r'/vpairwise/(\w+)/$', 'compare.views.vpairwise'),

     (r'^' + url_fmt + r'/compare_js/$', 'compare.views.compare_js'),

     # Pretend that this is what Facebook provides for 3rd parties:
     (r'^' + url_fmt + r'/get_friends/$', 'compare.views.get_friends'),
     (r'^' + url_fmt + r'/get_interests/(\w+)/$', 'compare.views.get_interests'),
)                   
urlpatterns = patterns (*m)
