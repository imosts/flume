from django.conf.urls.defaults import *
from wikicode import url_fmt

urlpatterns = patterns ('',
                        (r'^' + url_fmt + r'/?$', 'blog.views.index'),
                        (r'^' + url_fmt + r'/upload/$', 'blog.views.upload'),                        
                        (r'^' + url_fmt + r'/upload/newblog/(\d+)/$', 'blog.views.newblog'),
                        (r'^' + url_fmt + r'/upload/newpost/(\d+)/(\d+)/$', 'blog.views.newpost'),
                        (r'^' + url_fmt + r'/viewblog/(\d+)/$', 'blog.views.viewblog'),
                        (r'^' + url_fmt + r'/search/$', 'blog.views.search'),
                        )
