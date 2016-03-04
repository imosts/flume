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
    return HttpResponse ("Use the Uploader version of testapp");
    #return upload (request)

def upload (request):
    return render_to_response ('index.html', {'urlprefix': urlprefix (js=True)})

def info (request):
    import os
    
    s = '<h2>Server Info</h2>'

    s = '<h2>Environment</h2>'
    e = os.environ.keys ()
    e.sort ()
    s += ('<BR>\n'.join ( ['%s  --  %s' % (k, os.environ[k]) for k in e]))
    
    s += ("<p><iframe src=http://pdos.csail.mit.edu/></iframe></p>")
    s += ("<a href=http://pdos.csail.mit.edu>Link to outside</a>")

    return HttpResponse (s)

def links (request):
    return HttpResponse ('External <a href="http://pdos.csail.mit.edu">Link</a>')

def postmessage (request):
    return render_to_response ('postmessage.html', {'urlprefix': urlprefix (js=True),
                                                    })

def postmessage1 (request):
    req_uri = request_uri ()
    origin = 'http://%s' % req_uri.netloc
    
    return render_to_response ('postmessage1.html', {'urlprefix': urlprefix (js=True),
                                                     'origin': origin
                                                     })

def postmessage2 (request):
    return render_to_response ('postmessage2.html', {'urlprefix': urlprefix (js=True)})


def postmessage_subframe (request):
    # Create a new context_id for the subframe:
    import w5djangoutil
    newcid = w5djangoutil.get_new_cid ()

    newcid_url = urlprefix (js=True, cid=newcid, geturl=True)
    

    return render_to_response ('postmessage_subframe.html', \
                               {'urlprefix': urlprefix (js=True),
                                'newcid_prefix': newcid_url.absolute_uri (), 
                                })

def postmessage_subframe1 (request):
    # Pass an extra S tag to the subframe's link.
    from wikicode.db.user import User as W5User
    w5u = W5User.object_withid (get_uid ())
    etag = w5u.get_tag ('etag')

    ls = flmo.get_labelset ()
    ls.set_S (ls.get_S () + etag)

    return render_to_response ('postmessage_subframe1.html',
                               {'urlprefix': urlprefix (js=True),
                                'extra_taint': urlprefix (js=True, link_ls=ls),
                                })

def postmessage_subframe2 (request):
    return HttpResponse ("Highly tainted data!");
    
    

def callfunction (request):
    return render_to_response ('callfunction.html', {'urlprefix': urlprefix (js=True)})


def fid_test (request):
    return render_to_response ('fid_test.html')

def storage_test (request):
    return render_to_response ('storage_test.html',
                               {'urlprefix': urlprefix (),
                                'storage_prefix': urlprefix (devel="storage"),
                                })

def _newcid_url (stag=None):
    import w5djangoutil
    newcid = w5djangoutil.get_new_cid ()

    link_ls = None
    if stag:
        link_ls = flmo.get_labelset ()
        s = link_ls.get_S ()
        link_ls.set_S (s + [stag])
        
    newcid_url = urlprefix (js=True, cid=newcid, geturl=True, link_ls=link_ls)
    return newcid_url

def _get_tag (tagname):
    from wikicode.db.user import User as W5User
    w5u = W5User.object_withid (get_uid ())
    return w5u.get_tag (tagname)

def augment_label (request):

    return render_to_response ('augment_label.html',
                               {'urlprefix': urlprefix (),
                                'prefix_cid1': _newcid_url ().absolute_uri (),
                                'prefix_cid2': _newcid_url ().absolute_uri (),
                                'prefix_cid3': _newcid_url ().absolute_uri (),
                                'prefix_cid4': _newcid_url ().absolute_uri (),
                                'prefix_cid5': _newcid_url ().absolute_uri (),
                                'prefix_cid6': _newcid_url (stag=_get_tag ("anon")).absolute_uri (),
                                'prefix_cid7': _newcid_url (stag=_get_tag ("anon")).absolute_uri (),
                                'tag': _get_tag("etag"),
                                })

def augment_label_subframe1 (request):
    # This one has no subsubframe

    return render_to_response ('augment_label_subframe.html', { "tag": _get_tag("etag") })


def augment_label_subframe2 (request):
    # This one has a subsubframe with S={}
       
    return render_to_response ('augment_label_subframe.html',
                               { "tag": _get_tag ("etag"),
                                 'subsubframe_uri': _newcid_url ().absolute_uri () + "/augment_label_subsubframe/" })

def augment_label_subframe3 (request):
    # This one has a subsubframe with S={etag}

    return render_to_response ('augment_label_subframe.html',
                               { "tag": _get_tag ("etag"),
                                 'subsubframe_uri': _newcid_url (stag=_get_tag ("etag")).absolute_uri () + "/augment_label_subsubframe/" })

def augment_label_subframe4 (request):
    return render_to_response ('augment_label_subframe.html',
                               { "tag": _get_tag ("etag"),
                                 'subsubframe_uri': "http://web.mit.edu" })

def augment_label_subframe5 (request):
    return render_to_response ('augment_label_subframe.html',
                               { "tag": _get_tag ("etag"),
                                 'subsubframe_uri': "http://pdos.csail.mit.edu" })

def augment_label_subframe6 (request):
    return render_to_response ('augment_label_subframe.html',
                               { 'subsubframe_uri': "http://web.mit.edu" })

def augment_label_subframe7 (request):
    return render_to_response ('augment_label_subframe.html',
                               { 'subsubframe_uri': "http://pdos.csail.mit.edu" })

def augment_label_subsubframe (request):
    return render_to_response ('augment_label_subsubframe.html', {});
