from django.conf.urls.defaults import *
from wikicode import url_fmt

m = ('',
     (r'^' + url_fmt + r'/?$', 'photoedit.views.index'),
     (r'^' + url_fmt + r'/upload/$', 'photoedit.views.upload'),
     (r'^' + url_fmt + r'/upload/album/(\d+)/(\d+)/$', 'photoedit.views.album'),
     (r'^' + url_fmt + r'/upload/editphoto/(\d+)/(\d+)/$', 'photoedit.views.editphoto'),
     )                   
urlpatterns = patterns (*m)
