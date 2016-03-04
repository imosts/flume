import flume, datetime, sys, wikicode
import flume.flmos as flmo
from wikicode import get_uid, cond_exec, PYTHON, request_uri
from wikicode.prepare import is_prepare, prepare_stags
from wikicode.db.user import User as W5User
from django.shortcuts import render_to_response
from django.http import HttpResponse, HttpResponseRedirect
from django.contrib.w5.models import User, TagValue
from django.contrib.w5.util import urlprefix, new_page_id
from storage.models import Datum

INDEX_BY_SLAB = False
INDEX_BY_OLAB = True

def index (request):
    #return HttpResponse ("Not implemented, use upload instead")
    return upload (request)

def upload (request):
    return render_to_response ("test.html",
                               {'urlprefix': urlprefix ()})

def success (request):
    return HttpResponse ("Success")

def put (request):
    if request.POST.has_key ("submit"):
        key = request.POST.get ("key")
        val = request.POST.get ("val")

        slab = flmo.get_label (flume.LABEL_S)
        olab = wikicode.referer_ls ().get_O ()

        slab = str (slab.toRaw ().armor ())
        olab = str (olab.toRaw ().armor ())

        if INDEX_BY_SLAB is False:
            slab = ''
        if INDEX_BY_OLAB is False:
            olab = ''

        print >> sys.stderr, "PUT %s %s %s" % (key, slab, olab)

        try:
            datum = Datum.objects.get (k=key, slab=slab, olab=olab)
            datum.v = val
        except Datum.DoesNotExist:
            datum = Datum (k=key, v=val, slab=slab, olab=olab)
        datum.save ()
        
        return HttpResponse (datum.v)

    raise NotImplementedError ("You must call with submit, a key, and a val.")
    
def get (request):
    if request.GET.has_key ("submit"):
        key = request.GET.get ("key")

        slab = flmo.get_label (flume.LABEL_S)
        olab = wikicode.referer_ls ().get_O ()

        slab = str (slab.toRaw ().armor ())
        olab = str (olab.toRaw ().armor ())

        if INDEX_BY_SLAB is False:
            slab = ''
        if INDEX_BY_OLAB is False:
            olab = ''

        print >> sys.stderr, "GET %s %s %s" % (key, slab, olab)

        datum = Datum.objects.get (k=key, slab=slab, olab=olab)
        return HttpResponse (datum.v)

    raise NotImplementedError ("You must call with submit and a key.");
