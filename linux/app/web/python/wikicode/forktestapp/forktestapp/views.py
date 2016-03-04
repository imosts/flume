import flume, datetime
import flume.flmos as flmo
from django.shortcuts import render_to_response
from django.http import HttpResponse, HttpResponseRedirect
from wikicode import get_uid, cond_exec, PYTHON, request_uri
from wikicode.prepare import is_prepare, prepare_stags
from wikicode.db.user import User as W5User

from django.contrib.w5.models import User, TagValue
from django.contrib.w5.util import urlprefix, new_page_id

def index (request):
    return HttpResponse ("Fork Test App, index<BR> child ls %s" % flmo.get_labelset ())

def upload (request):
    return HttpResponse ("Fork Test App, uploader")
