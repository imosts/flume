from django.conf.urls.defaults import *
from wikicode import url_fmt

m = ('',
     (r'^' + url_fmt + r'/?$', 'photoapp.views.index'),
     (r'^' + url_fmt + r'/viewalbum/(\d+)/$', 'photoapp.views.viewalbum'),
     (r'^' + url_fmt + r'/slideshow/(\d+)/$', 'photoapp.views.slideshow'),
     (r'^' + url_fmt + r'/slideshowtxt/(\d+)/$', 'photoapp.views.slideshowtxt'),

     (r'^' + url_fmt + r'/upload/$', 'photoapp.views.upload'),
     (r'^' + url_fmt + r'/upload/newalbum/(\d+)/$', 'photoapp.views.newalbum'),
     (r'^' + url_fmt + r'/upload/newphoto/(\d+)/(\d+)/$', 'photoapp.views.newphoto'),
     )                   

urlpatterns = patterns (*m)
