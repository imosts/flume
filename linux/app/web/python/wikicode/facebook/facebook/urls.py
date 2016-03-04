from django.conf.urls.defaults import *
from wikicode import url_fmt

m = ('',
     (r'^' + url_fmt + r'/?$', 'facebook.views.index'),
     (r'^' + url_fmt + r'/upload/$', 'facebook.views.upload'),
     (r'^' + url_fmt + r'/viewprofile/(\w+)/$', 'facebook.views.viewprofile'),
     (r'^' + url_fmt + r'/blank/$', 'facebook.views.blank'),
     )                   
urlpatterns = patterns (*m)
