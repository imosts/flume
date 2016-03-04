import flume, datetime, sys
import flume.flmos as flmo
from wikicode import get_uid, cond_exec, PYTHON, request_uri
from wikicode.prepare import is_prepare, prepare_stags
from wikicode.db.user import User as W5User
from django.shortcuts import render_to_response
from django.http import HttpResponse, HttpResponseRedirect
from django.contrib.w5.models import User, TagValue
from django.contrib.w5.util import urlprefix, new_page_id
from poke.models import PokeMsg

# The following views are never really used
def _unimplemented (request, fn):
    return HttpResponse ("%s is not implemented" % fn)
def index (request):
    return _unimplemented (request, "index")
def upload (request):
    return _unimplemented (request, "upload")
def friends (request):
    return _unimplemented (request, "friends")
def public (request):
    return _unimplemented (request, "public")

# We only use the following views
def private (requset):
    # Read all 
    user = User.objects.get (id=get_uid ())
    pokes = user.poke_recipient_set.all ()
    return render_to_response ('readall.html',
                               {'myprefix': urlprefix (),
                                'compareprefix': urlprefix (devel="compare"),
                                'pokes': pokes,
                                'ls': str (flmo.get_labelset ())
                                })

def pairwise (request, friend_un):
    sender = User.objects.get (id=get_uid ())
    receiver = User.objects.get (username=friend_un)
    
    if request.POST.has_key ("submit"):
        # send the poke
        poke = PokeMsg (sender = sender,
                        recipient = receiver,
                        text = request.POST.get ("poke_content", 'empty'),
                        pub_date = datetime.datetime.now ())
        poke.save ()
        return HttpResponseRedirect (urlprefix () + "/pairwise/%s/" % friend_un)

    return render_to_response ('sendpoke.html', {'myprefix': urlprefix (),
                                                 'compareprefix': urlprefix (devel="compare"),
                                                 'friend_un': friend_un,
                                                 'sender' : sender.username,
                                                 'receiver' : receiver.username,
                                                 })

def vpairwise (request, profile_owner):
    return pairwise (request, profile_owner)

def poke_js (request):
    user = User.objects.get (id=get_uid ())
    return render_to_response ('poke.js',
                               {'myprefix' : urlprefix (),
                                'storageprefix': urlprefix (devel='storage'),
                                'compareprefix': urlprefix (devel="compare"),
                                'username' : user.username,
                                })
