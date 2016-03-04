from django.conf.urls.defaults import *
from wikicode import url_fmt

m = ('',
     (r'^' + url_fmt + r'/?$', 'widgets.views.index'),
     (r'^' + url_fmt + r'/viewprofile/(\w+)/$', 'widgets.views.viewprofile'),
     )                   
urlpatterns = patterns (*m)
