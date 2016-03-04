import flume, datetime, sys
import flume.flmos as flmo
from wikicode import get_uid, cond_exec, PYTHON, request_uri
from wikicode.prepare import is_prepare, prepare_stags
from wikicode.db.user import User as W5User
from django.shortcuts import render_to_response
from django.http import HttpResponse, HttpResponseRedirect
from django.contrib.w5.models import User, TagValue
from django.contrib.w5.util import urlprefix, new_page_id
from wall.models import WallPost

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

# We only use the following views
def _private (request, profile_owner):
    owner = User.objects.get (username=profile_owner)
    posts = owner.wall_owner_set.all ()
    return render_to_response ('readall.html',
                               {'user': owner.username,
                                'posts': posts,
                                })

def private (request):
    # XXX This should just get username from env.
    user = User.objects.get (id=get_uid ())
    return _private (request, user.username)

def vprivate (request, profile_owner):
    return _private (request, profile_owner)

def friends (request):
    me = User.objects.get (id=get_uid ())
    return render_to_response ('newpost.html', {'urlprefix': urlprefix (),
                                                'profile_owner': me.username,
                                                'redir': '/friends',
                                                })
def vfriends (request, profile_owner):
    return render_to_response ('newpost.html', {'urlprefix': urlprefix (),
                                                'profile_owner': profile_owner,
                                                'redir': '/vfriends/%s' % profile_owner,
                                                })
    
def savepost (request, profile_owner):
    if request.POST.has_key ("submit"):
        me = User.objects.get (id=get_uid ())
        owner = User.objects.get (username=profile_owner)
        post = WallPost (author = me,
                         wallowner = owner,
                         text = request.POST.get ("post_content", 'empty'),
                         pub_date = datetime.datetime.now ())
        post.save ()
        return HttpResponseRedirect (urlprefix () + request.POST['redir'])

    raise NotImplementedError ("error")
    
