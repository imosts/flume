import flume, datetime, sys
import flume.flmos as flmo
from wikicode import get_uid, cond_exec, PYTHON, request_uri
from wikicode.prepare import is_prepare, prepare_stags
from wikicode.db.user import User as W5User
from wikicode.const import *
from django.shortcuts import render_to_response as r2r
from django.template import loader
from django.http import HttpResponse, HttpResponseRedirect
from django.contrib.w5.models import User, TagValue
from django.contrib.w5.util import urlprefix, new_page_id
from facebook.models import Interests

# The following views are never really used
def _unimplemented (request, fn):
    return HttpResponse ("%s is not implemented" % fn)
def index (request):
    return _unimplemented (request, "index")
def upload (request):
    return _unimplemented (request, "upload")
def public (request):
    return _unimplemented (request, "public")
def pairwise (request, friend_un):
    return _unimplemented (request, "pairwise")

def private (request):
    # XXX This should just get username from env.
    user = User.objects.get (id=get_uid ())
    
    interests = user.interests_set.all ()
    similar_users = []
    if len (interests) > 0:
        interests = interests[0]
        for i in interests.interests.split ():
            for similar_user in Interests.objects.filter (interests__icontains=i):
                if similar_user.user.username != user.username:
                    similar_users.append (similar_user.user.username)

    return r2r ('private.html',
                {'myprefix': urlprefix (geturl=True).absolute_uri (),
                 'fbprefix': urlprefix (mode=W5MODE_TRUSTED_PYAPP_FORK,
                                        link_ls=flmo.LabelSet (),
                                        devel='facebook',
                                        geturl=True,
                                        trusted=True).absolute_uri (),
                 'similar_users': similar_users })

def vprivate (request, profile_owner):
    return _private (request, profile_owner)
    
def compare_js (request):
    user = User.objects.get (id=get_uid ())
    s = loader.render_to_string ('compare.js',
                                 {'username': user.username,
                                  'urlprefix' : urlprefix (js=True)})
    return HttpResponse (s, mimetype='text/javascript')



# Pretend that this is what Facebook provides for 3rd parties:
def get_friends (request):
    #active_user = User.objects.get (id=get_uid ())

    import w5djangoutil
    friends = w5djangoutil.get_friendlist ()
    return HttpResponse (','.join (friends))

def get_interests (request, username):
    user = User.objects.get (username=username)

    all_interests = []
    interests = user.interests_set.all ()
    for e in interests:
        for i in e.interests.split ():
            all_interests.append (i)

    return HttpResponse (','.join (all_interests))
