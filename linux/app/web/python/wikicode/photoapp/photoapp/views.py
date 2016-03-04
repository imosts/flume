import datetime, flume, os, wikicode, os.path
import flume.flmos as flmo
import DBV.dbapi as dbapi

from wikicode import W5Uri, get_uid, get_devel_un, PYTHON
from wikicode import combine_forward_ls, cond_exec, request_uri
from wikicode.util import check_mkdir_label, add_caps, helper_write
import wikicode.db.user as w5user
from wikicode.db.user import User as W5User
from wikicode.prepare import is_prepare, prepare_stags
from wikicode.const import *

from django.shortcuts import render_to_response
from django.http import HttpResponse, HttpResponseRedirect
from django.core.urlresolvers import reverse
from django.contrib.w5.models import User, TagValue
from django.contrib.w5.util import urlprefix, new_page_id, base_ls, django_setup_py, get_one_py

from photoapp.models import AlbumPointer, Album, PhotoPointer, Photo

def view_link_py (albumpointer_id, album_ls):
    return (get_one_py (get_devel_un(), 'Album', 'owner', albumpointer_id) + 
            "print ('"
            "<td>%%s</td>"
            "<td>%%s</td>"
            "<td><A HREF=\"%s/viewalbum/%%s/\">View</a></td>"
            "<td><A HREF=\"%s/slideshow/%%s/\">Slideshow</a></td>"
            "' %% (obj.title, obj.owner, obj.id, obj.id)); "
            % (urlprefix (album_ls, js=True),
               urlprefix (album_ls, js=True),))

def per_album_link_py (albumpointer_id, link_ls, subdir):
    # This assumes that the current labelset has S={}
    # Prints a link <a href=/...devel/(subdir)/(album_id)/(page_id)/><title></a>
    return (get_one_py (get_devel_un (), 'Album', 'owner', albumpointer_id) + 
            "print ('<A HREF=\"%s/%s/%%s/%d/\">%%s</a>' %% (obj.id, obj.title)); "
            % (urlprefix (link_ls), subdir, new_page_id ()))

def photo_setup_py (photopointer_id, itag):
    s = (django_setup_py () +
         "from photoapp.models import PhotoPointer, Photo; " +
         "pp = PhotoPointer.objects.get (id=%d); " % photopointer_id)

    if wikicode.IMODE & wikicode.IMODE_USER:
        s += "photos = pp.photo_set.itag_has ([%d]); " % itag.val ()
    else:
        s += "photos = pp.photo_set.all (); "
    s += "photos = [p for p in photos]; p = photos[0]; "
    return s

def per_photo_link_py (photopointer, link_ls, subdir):
    # Prints a link <a href=/...devel/(subdir)/(photo_id)/(page_id)/><title></a>
    w5u = W5User.object_withid (photopointer.album.owner.id)
    itag = w5u.script_tag ()

    return (photo_setup_py (photopointer.id, itag) +
            "print ('<A HREF=\"%s/%s/%%s/%d/\">%%s</a>' %% (p.id, p.title)); "
            % (urlprefix (link_ls), subdir, new_page_id ()))

def photo_url (photo, my_ls=None):
    if my_ls is None:
        my_ls = flmo.get_labelset ()

    if isinstance (photo, PhotoPointer):
        photo_ls = photo.get_labelset ()
        actual_path = 'ihome/' + photo_ls.to_filename() + '/%d.jpg' % photo.id
        img_ls = combine_forward_ls (my_ls, photo_ls)
    elif isinstance (photo, Photo):
        photo_ls = my_ls
        actual_path = photo.filename[1:] # Remove the leading '/'
        img_ls = my_ls

    uri = W5Uri (mode='static-ihome', devel=get_devel_un (),
                 file=actual_path, link_ls=img_ls,
                 jsmode=True, trusted=False)
    return str (uri)

def index (request):
    # Get all album pointers, regardles of integrity.
    # This will accept albums made by any user, and any app.

    if wikicode.IMODE & wikicode.IMODE_USER:
        # The Extra SQL verifies that the itag corresponds to the owner of the Album object.
        album_pointers = AlbumPointer.objects.itag_owner_in_col ('owner_id')
    else:
        album_pointers = AlbumPointer.objects.all ()
        
    album_includes = []
    for ap in album_pointers:
        # Add any S tags on the album to the current labelset
        album_ls = flmo.get_labelset ()
        album_ls.set_S (album_ls.get_S () + ap.get_slabel ())

        txt = cond_exec (album_ls, (PYTHON, '-c', view_link_py (ap.id, album_ls)))
        album_includes.append (txt)

    return render_to_response ('index.html',
                               {'urlprefix': urlprefix (),
                                'album_includes': album_includes,
                               })

def get_photo_urls (album):
    import w5djangoutil

    # Figure out the list of posts and their labels.
    # Only look at photos that were actually written by the owner.
    w5owner = W5User.object_withid (album.owner.id)
    if wikicode.IMODE & wikicode.IMODE_USER:
        photopointers = album.photopointer_set.itag_has ([w5owner.script_tag()])
    else:
        photopointers = album.photopointer_set.all ()
    my_ls = flmo.get_labelset ()

    photo_urls = []
    caption_urls = []
    for pp in photopointers:
        photo_ls = pp.get_labelset ()
        if w5djangoutil.may_read (photo_ls):
            photo_urls.append (photo_url (pp, my_ls))
            img_ls = combine_forward_ls (my_ls, pp.get_labelset ())
            caption_urls.append (urlprefix (link_ls=img_ls, js=True) +
                                 "/slideshowtxt/%d/" % pp.id)
            
    return photo_urls, caption_urls

def viewalbum (request, album_id):
    a = Album.objects.get (id=album_id)
    photo_urls, caption_urls = get_photo_urls (a)
    return render_to_response('viewalbum.html',
                              {'urlprefix': urlprefix (),
                               'album_id': album_id,
                               'title': a.title,
                               'photo_urls': photo_urls,
                               })

def slideshowtxt (request, photopointer_id):
    pp = PhotoPointer.objects.get (id=photopointer_id)

    w5owner = W5User.object_withid (pp.album.owner.id)
    if wikicode.IMODE & wikicode.IMODE_USER:
        photos = pp.photo_set.itag_has ([w5owner.script_tag ()])
    else:
        photos = pp.photo_set.all ()
    a = []
    for p in photos:
        if VERBOSE_CAPTIONS:
            fname = p.filename
        else:
            fname = os.path.basename(p.filename)
        
        a.append ("<p><table>"
                  "<tr><td>Title: %s</td></tr>"
                  "<tr><td>Caption: %s</td></tr>"
                  "<tr><td>Date: %s</td></tr>"
                  "<tr><td>Filename: %s</td></tr>"
                  "</table></p>" % (p.title, p.caption, p.pub_date.strftime("%D"), fname))
    return HttpResponse ("\n".join (a))

def slideshow (request, album_id):
    a = Album.objects.get (id=album_id)
    photo_urls, caption_urls = get_photo_urls (a)            
    return render_to_response('slideshow.html',
                              {'urlprefix': urlprefix (),
                               'album_id': album_id,
                               'title': a.title,
                               'photo_urls': photo_urls,
                               'caption_urls': caption_urls,
                               })

def upload (request):
    if is_prepare ():
        return "Prepare does not make sense on this page."
    else:
        u = User.objects.get (id=get_uid ())
        w5owner = W5User.object_withid (u.id)
        if wikicode.IMODE & wikicode.IMODE_USER:
            album_pointers = u.albumpointer_set.itag_has ([w5owner.script_tag ()])
        else:
            album_pointers = u.albumpointer_set.all ()

        album_includes = []
        for ap in album_pointers:
            # run cond_exec with current labelset + any new S tags in the photo
            album_ls = flmo.get_labelset ()
            album_ls.set_S (album_ls.get_S () + ap.get_slabel ())
            
            txt = cond_exec (album_ls, (PYTHON, '-c',
                                        per_album_link_py (ap.id, album_ls, 'upload/newphoto')))
            album_includes.append (txt)

        if wikicode.IMODE & wikicode.IMODE_USER:
            all_albums = Album.objects.itag_owner_in_col ('owner_id')
        else:
            all_albums = Album.objects.all ()

        return render_to_response ('upload.html',
                                   {'urlprefix': urlprefix (),
                                    'all_albums': all_albums,
                                    'album_includes': album_includes,
                                    'new_page_id': new_page_id (),
                                   })

def make_albumpointer (pointer_ls, user, album_ls, page_id):
    if len (pointer_ls.get_S ()) > 0:
        return ("Error, tried to create album pointer "
                "with S label %s.  Should be empty" % pointer_ls)

    ap = AlbumPointer (owner=user, labelset=album_ls.toRaw ().armor (),
                       page_id=page_id, pub_date=datetime.datetime.now ())
    ap.save (desls=pointer_ls)
    return ap

def newalbum (request, page_id):
    u = User.objects.get (id=get_uid ())

    if is_prepare ():
        album_ls = base_ls ()
        album_ls.set_S (flmo.Label (set (album_ls.get_S ()) | set (prepare_stags ())))
        ap = make_albumpointer (base_ls (), u, album_ls, page_id)
        return ("Created AlbumPointer with id %d and S label %s for page_id %s"
                % (ap.id, album_ls, page_id))

    elif request.POST.has_key ('title'):
        title = request.POST['title']

        previous_page_id = request.POST['page_id']
        try:
            ap = AlbumPointer.objects.get (page_id=previous_page_id)
        except AlbumPointer.DoesNotExist:
            ap = make_albumpointer (base_ls (), u, base_ls (), page_id)

        a = Album (albumpointer=ap, title=title, owner=u,
                   pub_date=datetime.datetime.now ())

        a.save (desls=ap.get_labelset ())
        return HttpResponseRedirect (urlprefix () + '/upload/newphoto/%d/%d/' % (a.id, new_page_id ()))

    else:
        slab = flmo.get_label (flume.LABEL_S)
        if len (slab) > 0:
            return HttpResponse ("Error, album creation should have empty S label."
                                 "You tried to run it with S = %s" % slab)

        # Spit out the form
        return render_to_response ('newalbum.html',
                                   {'urlprefix': urlprefix (),
                                    'page_id': page_id,
                                    'new_page_id': new_page_id (),
                                    'cid': request_uri ().context_id (),
                                    }
                                   )

def make_photopointer (pointer_ls, album, ls, page_id):
        # Create and save a photo pointer.  This should run with the S
        # label of the album so that clients can see the pointer even
        # if they can't see the photo.
        pp = PhotoPointer (album=album, labelset=ls.toRaw ().armor (),
                           page_id=page_id, pub_date=datetime.datetime.now())
        pp.save (desls=pointer_ls)
        return pp
    
def save_photo (filename, file_dat, file_ls, set_proc_s=False):
    dname = os.path.join ('/ihome', file_ls.to_filename ())
    fname = os.path.join (dname, filename)

    oldls = flmo.get_labelset ()
    add_caps (file_ls)
    flmo.set_label2 (I=file_ls.get_I ())
    
    check_mkdir_label (dname, 0755, file_ls)
    helper_write (fname, file_dat, file_ls)

    flmo.set_label2 (I=oldls.get_I ())
    flmo.set_label2 (O=oldls.get_O ())
    return fname

def newphoto (request, album_id, page_id):
    album = Album.objects.get (id=album_id)
    ap = album.albumpointer

    if is_prepare ():
        # Create and save a photo pointer.  XXX This should run with the S
        # label of the album so that clients can see the pointer even
        # if they can't see the photo.
        photo_ls = base_ls ()
        photo_ls.set_S (flmo.Label (set (photo_ls.get_S ()) | set (prepare_stags ())))
        pp = make_photopointer (ap.get_labelset (), album, photo_ls, page_id)
        return ("Created a PhotoPointer with id %d and S label %s for page_id %s"
                % (pp.id, photo_ls.get_S (), page_id))

    elif request.POST.has_key ('title'):
        # Process the form input
        u = User.objects.get (id=get_uid ())
        title = request.POST['title']
        caption = request.POST['caption']
        file_dat = request.FILES['file']['content']

        previous_page_id = request.POST['page_id']
        try:
            # See if the previous page made us a pointer already (due to toolbar adding an S tag)
            pp = PhotoPointer.objects.get (page_id=previous_page_id)
        except PhotoPointer.DoesNotExist:
            pp = make_photopointer (ap.get_labelset (), album, base_ls (), page_id)

        file_ls = base_ls ()
        if wikicode.IMODE & wikicode.IMODE_APP:
            if pp.get_labelset () != file_ls:
                return HttpResponse ("Error, photo uploader (%s) should have same S label "
                                     "as the new photo (%s)." % (file_ls, pp.get_labelset ()))

        fname = save_photo (str (pp.id) + '.jpg', file_dat, file_ls)
        photo = Photo (photopointer=pp, title=title, caption=caption,
                       filename=fname, pub_date=datetime.datetime.now())
        photo.save (desls=file_ls)

        # XXX We probably want to transition directly to the Uploader
        # with S={}, but we might have S={x} right now.  We should
        # implement a direct link to the main uploader page that
        # automatically declassifies.  This is pretty safe because its
        # the same as linking from the homepage, and there's only one
        # uploader.
        return HttpResponse ("done")

    else:
        slab = flmo.get_label (flume.LABEL_S)
        album_slab = album.albumpointer.get_slabel ()
        if slab != album_slab:
            return HttpResponse ("Error, photo uploader (%s) should have same S label "
                                 "as the album (%s)." % (slab, album_slab))

        # Spit out the form
        return render_to_response ('newphoto.html',
                                   {'urlprefix': urlprefix (),
                                    'album': album,
                                    'page_id': page_id,
                                    'new_page_id': new_page_id (),
                                    }
                                   )
    
# Functions for setting up albums and photos through a setup script.
def experiment_prep (username):
    u = User.objects.get (username=username)
    w5u = W5User.object_withkey (username)

    if USE_DEVEL_WCAPS:
        olab = flmo.Label ([w5user.devel_from_env ().get_tag ('wtag')])
    else:
        olab = flmo.Label ([w5u.get_tag('wtag_app_photoapp')])
    
    pointer_ls = flmo.LabelSet (I=flmo.Label ([w5u.script_tag()]),
                                O=olab)
    return u, w5u, pointer_ls

def experiment_newalbum (username, albumname):
    u, w5u, pointer_ls = experiment_prep (username)
    
    # Make the pointer and the album
    # Assume for now that the album has S={}
    try:
        Album.objects.get (title=albumname, owner=u)
        return False
    except Album.DoesNotExist:
        fake_page_id = new_page_id ()
        ap = make_albumpointer (pointer_ls, u, pointer_ls, fake_page_id)
        a = Album (albumpointer=ap, title=albumname, owner=u,
                   pub_date=datetime.datetime.now ())
        a.save (desls=ap.get_labelset ())
        return True
    
def experiment_newphoto (username, albumname, filename, file_dat, tags=[]):
    u, w5u, pointer_ls = experiment_prep (username)
    photo_ls = pointer_ls.clone ()
    photo_ls.set_S (photo_ls.get_S () + [w5u.get_tag (tn) for tn in tags])
    add_caps (photo_ls)
    
    # XXX Be stupid about queries because our DB crapped out on inner join
    a = Album.objects.get (title=albumname, owner=u)
    ppointers = a.photopointer_set.all ()

    found = False
    for pp in ppointers:
        try:
            Photo.objects.get (title=filename, photopointer=pp)
            found = True
        except Photo.DoesNotExist:
            pass

    if found:
        return False
    else:
        fake_page_id = new_page_id ()
        a = Album.objects.get (title=albumname, owner=u)
        pp = make_photopointer (pointer_ls, a, photo_ls, fake_page_id)

        fname = save_photo (str (pp.id) + '.jpg', file_dat, photo_ls, set_proc_s=True)
        p = Photo (photopointer=pp, title=filename, caption='',
                   filename=fname, pub_date=datetime.datetime.now ())
        flmo.set_label2 (S=photo_ls.get_S ()) # Set so that our ep label has the right S, can we can remove it after save
        p.save (desls=photo_ls)
        flmo.set_label2 (S=None)
        dbapi.close_all_conns () # Close all conns to get rid of the high secrecy db endpoint.
        return True

def experiment_get_albumid (owner, albumname):
    u, w5u, pointer_ls = experiment_prep (owner)
    a = Album.objects.get (owner=u, title=albumname)
    return a.id
