from django.conf.urls.defaults import *
from wikicode import url_fmt

m = ('',
     (r'^' + url_fmt + r'/?$', 'testapp.views.index'),
     (r'^' + url_fmt + r'/upload/$', 'testapp.views.upload'),

     (r'^' + url_fmt + r'/info/$', 'testapp.views.info'),
     (r'^' + url_fmt + r'/links/$', 'testapp.views.links'),
     (r'^' + url_fmt + r'/callfunction/$', 'testapp.views.callfunction'),

     (r'^' + url_fmt + r'/postmessage/$', 'testapp.views.postmessage'),
     (r'^' + url_fmt + r'/postmessage1/$', 'testapp.views.postmessage1'),
     (r'^' + url_fmt + r'/postmessage2/$', 'testapp.views.postmessage2'),

     (r'^' + url_fmt + r'/postmessage_subframe/$', 'testapp.views.postmessage_subframe'),
     (r'^' + url_fmt + r'/postmessage_subframe1/$', 'testapp.views.postmessage_subframe1'),
     (r'^' + url_fmt + r'/postmessage_subframe2/$', 'testapp.views.postmessage_subframe2'),

     (r'^' + url_fmt + r'/fid_test/$', 'testapp.views.fid_test'),
     (r'^' + url_fmt + r'/storage_test/$', 'testapp.views.storage_test'),

     (r'^' + url_fmt + r'/augment_label/$', 'testapp.views.augment_label'),
     (r'^' + url_fmt + r'/augment_label_subframe1/$', 'testapp.views.augment_label_subframe1'),
     (r'^' + url_fmt + r'/augment_label_subframe2/$', 'testapp.views.augment_label_subframe2'),
     (r'^' + url_fmt + r'/augment_label_subframe3/$', 'testapp.views.augment_label_subframe3'),
     (r'^' + url_fmt + r'/augment_label_subframe4/$', 'testapp.views.augment_label_subframe4'),
     (r'^' + url_fmt + r'/augment_label_subframe5/$', 'testapp.views.augment_label_subframe5'),
     (r'^' + url_fmt + r'/augment_label_subframe6/$', 'testapp.views.augment_label_subframe6'),
     (r'^' + url_fmt + r'/augment_label_subframe7/$', 'testapp.views.augment_label_subframe7'),
     (r'^' + url_fmt + r'/augment_label_subsubframe/$', 'testapp.views.augment_label_subsubframe'),

     )                   
urlpatterns = patterns (*m)
