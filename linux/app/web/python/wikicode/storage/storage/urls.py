from django.conf.urls.defaults import *
from wikicode import url_fmt

m = ('',
     (r'^' + url_fmt + r'/?$', 'storage.views.index'),
     (r'^' + url_fmt + r'/upload/$', 'storage.views.upload'),

     (r'^' + url_fmt + r'/put/$', 'storage.views.put'),
     (r'^' + url_fmt + r'/get/$', 'storage.views.get'),
     (r'^' + url_fmt + r'/success/$', 'storage.views.success'),
)                   
urlpatterns = patterns (*m)
