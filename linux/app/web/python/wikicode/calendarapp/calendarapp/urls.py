from django.conf.urls.defaults import *
from wikicode import url_fmt

m = ('',
     (r'^' + url_fmt + r'/event/(\d+)/$', 'newcalendarapp.views.eventdetails'),
     (r'^' + url_fmt + r'/project/(\d+)/$', 'newcalendarapp.views.projectdetails'),
     (r'^' + url_fmt + r'/(?P<year>\d{4})/(?P<month>\d+)/$', 'newcalendarapp.views.index'),
     (r'^' + url_fmt + r'/upload/newevent/$', 'newcalendarapp.views.newevent'),
     (r'^' + url_fmt + r'/upload/$', 'newcalendarapp.views.upload'),
     (r'^' + url_fmt + r'/?$', 'newcalendarapp.views.index'),
     )                   

urlpatterns = patterns (*m)
