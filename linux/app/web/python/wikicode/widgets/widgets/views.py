import flume, datetime, sys
import flume.flmos as flmo
from wikicode import get_uid, cond_exec, PYTHON, request_uri
from wikicode.prepare import is_prepare, prepare_stags
from wikicode.db.user import User as W5User
from wikicode.const import *
from wikicode.errors import *
from django.shortcuts import render_to_response
from django.http import HttpResponse, HttpResponseRedirect
from django.contrib.w5.models import TagValue
from django.contrib.w5.util import urlprefix, new_page_id
import w5djangoutil


def index (request):
    widget_data = []
    w5u = W5User.object_withid (get_uid())

    for widget in WIDGETS:
        public_ls = flmo.LabelSet ()
        private_ls = flmo.LabelSet (S=flmo.Label ([w5u.get_tag ('etag')]))
        id_name = ""

        if widget == 'cbox' or widget == 'blog_content':
            ls = private_ls
        else:
            ls = public_ls

        if (widget == 'frame2'):
            id_name = "pm2"
        else:
            id_name = ""

        url = urlprefix (link_ls=ls,
                         js=True,
                         mode=W5MODE_UNTRUSTED_PYFORK,
                         therest=widget,
                         cid=w5djangoutil.get_new_cid(),
                         devel="widgetapp",
                         geturl=True)

        widget_data.append ({'url': url.absolute_uri(),
                           'name': widget,
                           'ls': str(ls),
                           })

    return render_to_response ('viewprofile.html',
                               {'widget_data' : widget_data,
                                'id_name' : id_name,
                                })
