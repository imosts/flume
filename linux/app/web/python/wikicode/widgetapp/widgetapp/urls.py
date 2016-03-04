from django.conf.urls.defaults import *
from wikicode import url_fmt

m = ('',
     (r'^' + url_fmt + r'/?$', 'widgetapp.views.index'),

     (r'^' + url_fmt + r'/twitter/$', 'widgetapp.views.twitter'),
     (r'^' + url_fmt + r'/evil/$', 'widgetapp.views.evil'),
     (r'^' + url_fmt + r'/puppies/$', 'widgetapp.views.puppies'),
     (r'^' + url_fmt + r'/link/$', 'widgetapp.views.link'),
     (r'^' + url_fmt + r'/popular/$', 'widgetapp.views.popular'),
     (r'^' + url_fmt + r'/comments/$', 'widgetapp.views.comments'),
     (r'^' + url_fmt + r'/recentposts/$', 'widgetapp.views.recentposts'),
     (r'^' + url_fmt + r'/youtube/$', 'widgetapp.views.youtube'),
     (r'^' + url_fmt + r'/calendar/$', 'widgetapp.views.calendar'),
     (r'^' + url_fmt + r'/history/$', 'widgetapp.views.history'),
     (r'^' + url_fmt + r'/labels/$', 'widgetapp.views.labels'),
     (r'^' + url_fmt + r'/random/$', 'widgetapp.views.random'),
     (r'^' + url_fmt + r'/frame1/$', 'widgetapp.views.frame1'),
     (r'^' + url_fmt + r'/frame2/$', 'widgetapp.views.frame2'),

     (r'^' + url_fmt + r'/cbox/$', 'widgetapp.views.cbox'),
     (r'^' + url_fmt + r'/cbox_main/$', 'widgetapp.views.cbox_main'),
     (r'^' + url_fmt + r'/cbox_form/$', 'widgetapp.views.cbox_form'),
     (r'^' + url_fmt + r'/cbox_js/$', 'widgetapp.views.cbox_js'),
     (r'^' + url_fmt + r'/cbox_css/$', 'widgetapp.views.cbox_css'),
     (r'^' + url_fmt + r'/cbox_frametest1/$', 'widgetapp.views.cbox_frametest1'),
     (r'^' + url_fmt + r'/cbox_frametest2/(\w+)/$', 'widgetapp.views.cbox_frametest2'),

     (r'^' + url_fmt + r'/blog_content/$', 'widgetapp.views.blog_content'),
     )                   
urlpatterns = patterns (*m)
