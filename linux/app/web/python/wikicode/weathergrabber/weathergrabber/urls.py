from django.conf.urls.defaults import *
from wikicode import url_fmt

m = ('',
     (r'^' + url_fmt + r'/?$', 'weathergrabber.views.index'),
     (r'^' + url_fmt + r'/upload/$', 'weathergrabber.views.getweather'),
     )                   

urlpatterns = patterns (*m)
