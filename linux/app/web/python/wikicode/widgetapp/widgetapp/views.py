import flume, datetime, sys
import flume.flmos as flmo
from wikicode import get_uid, cond_exec, PYTHON, request_uri
from wikicode.prepare import is_prepare, prepare_stags
from wikicode.db.user import User as W5User
from wikicode.const import *
from wikicode.errors import *
from django.template import loader
from django.shortcuts import render_to_response
from django.http import HttpResponse, HttpResponseRedirect
from django.contrib.w5.models import TagValue
from django.contrib.w5.util import urlprefix, new_page_id
import w5djangoutil


def index (request):
    url = urlprefix (geturl=True).absolute_uri ()
    
    return render_to_response ("index.html",
                               {'urlprefix': url})

def twitter (request):
    return render_iframe(request, "twitter")

def evil (request):
    return render_iframe(request, "evil")

def puppies (request):
    return render_iframe(request, "puppies")

def link (request):
    return render_iframe(request, "link")

def popular (request):
    return render_iframe(request, "popular")

def comments (request):
    return render_iframe(request, "comments")

def recentposts (request):
    return render_iframe(request, "recent-posts", provide_posts=True)

def labels (request):
    return render_iframe(request, "labels", provide_posts=True)

def random (request):
    return render_iframe(request, "random", provide_posts=True)

def frame1 (request):
    return render_iframe(request, "frame1")

def frame2 (request):
    return render_iframe(request, "frame2")

def cbox (request):
    return render_iframe(request, "cbox-parent")
def cbox_main (request):
    return render_iframe(request, "cbox-main")
def cbox_form (request):
    return render_iframe(request, "cbox-form")
def cbox_js (request):
    return render_iframe(request, "cbox", suffix='.js', mimetype="text/javascript")
def cbox_css (request):
    return render_iframe(request, "cbox-css", suffix='.css', mimetype="text/css")

def cbox_frametest1 (request):
    w5u = W5User.object_withid (id=get_uid ())
    
    url1 = urlprefix (cid=w5djangoutil.get_new_cid (), geturl=True)
    url2 = urlprefix (cid=w5djangoutil.get_new_cid (), geturl=True)

    ls = flmo.get_labelset ()
    ls.set_S (ls.get_S () + w5u.get_tag ('etag'))
    url_secret = urlprefix (link_ls=ls)
    return render_to_response ('widgets-cbox-frametest1.html',
                               {'urlprefix1' : url1.absolute_uri (),
                                'urlprefix2' : url2.absolute_uri (),
                                'ctx1' : url1.context_id (),
                                'ctx2' : url2.context_id (),
                                'urlprefix_secret' : url_secret,
                                })

def cbox_frametest2 (request, other_ctx):
    url = urlprefix (cid=other_ctx, geturl=True)
    return render_to_response ('widgets-cbox-frametest2.html',
                               {'urlprefix_other' : url.absolute_uri ()})



def blog_content (request):
    return render_iframe(request, "blog-content")

def youtube (request):
    return render_iframe(request, "youtube")

def calendar (request):
    return render_iframe(request, "calendar")

def history (request):
    return render_iframe(request, "history")



def static_file_url (filename, owner=None, subdir='', ls=None):

    if owner is None:
        owner = wikicode.get_developer ()

    path = os.path.join (owner.static_dir(), subdir, filename)

    return urlprefix (link_ls=ls,
                      mode=W5MODE_UNTRUSTED_STATIC_IHOME,
                      therest=path,
                      trusted=False,
                      devel="widgets",
                      file="widgets",
                      js=True)


def render_iframe (request, widget,
                   suffix='.html',
                   mimetype=None,
                   provide_posts=False,
                   provide_comments=False):

    owner = "widgets"
    feed_posts_url = feed_comments_url = None

    if (widget == frame2):
        id_and_name = "pm2"

    if (provide_posts):
        json_name = "json-secret.html"
        # Provide the URL of the json-feed
        if (widget == "random"):
            json_name = "json2-secret.html"
        w5u = W5User.object_withid (get_uid())
        feed_posts_url = static_file_url (json_name,
                                          subdir="widgets/static",
                                          owner=w5u,
                                          ls=flmo.LabelSet (S=flmo.Label ([w5u.get_tag ('etag')])))

    if (provide_comments):
        raise NotImplementedError

    s = loader.render_to_string ('widgets-' + widget + suffix,
                                 {'urlprefix' : urlprefix (js=True),
                                  'feed_posts_url' : feed_posts_url,
                                  'feed_comments_url' : feed_comments_url,
                                  'owner' : owner,
                                  })
    return HttpResponse (s, mimetype=mimetype)

