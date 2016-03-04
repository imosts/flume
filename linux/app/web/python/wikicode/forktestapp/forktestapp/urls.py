from django.conf.urls.defaults import *
from wikicode import url_fmt

m = ('',
     (r'^' + url_fmt + r'/?$', 'forktestapp.views.index'),
     (r'^' + url_fmt + r'/upload/$', 'forktestapp.views.upload'),
     )                   
urlpatterns = patterns (*m)
