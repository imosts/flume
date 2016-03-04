import flume, datetime
import flume.flmos as flmo
from django.shortcuts import render_to_response
from django.http import HttpResponse, HttpResponseRedirect
from wikicode import get_uid, cond_exec, PYTHON
from wikicode.prepare import is_prepare, prepare_stags
from wikicode.db.user import User as W5User

from django.contrib.w5.models import User, TagValue
from django.contrib.w5.util import urlprefix, new_page_id

from photoapp.models import AlbumPointer, Album, PhotoPointer, Photo
from photoapp.views import per_album_link_py, per_photo_link_py, photo_url

def index (request):
    return HttpResponse ("It makes no sense to run the photo editing "
                         "app in anonymous (read-only) mode.")

def upload (request):
    if is_prepare ():
        return "Prepare does not make sense on this page."
    else:
        u = User.objects.get (id=get_uid ())

        # Show all of the user's Albums.  We can't list the photos
        # directly, because we can't see all the pointers (their S
        # labels might not be {}).
        album_includes = []
        for ap in u.albumpointer_set.all ():
            # run cond_exec with current labelset + any new S tags in the photo
            link_ls = flmo.get_labelset ()
            link_ls.set_S (ap.get_slabel ())

            txt = cond_exec (link_ls, (PYTHON, '-c',
                                       per_album_link_py (ap.id, link_ls, 'upload/album')))
            album_includes.append (txt)

        return render_to_response ('objlist.html',
                                   {'urlprefix': urlprefix (),
                                    'obj_list': album_includes,
                                    'title': 'Photo Editor',
                                    'directions': 'Edit photos in one of your albums',
                                    })

def album (request, album_id, page_id):
    # Show a list of photos in this album
    if is_prepare ():
        return "foo you"
    else:
        a = Album.objects.get (id=album_id)
        photo_includes = []
        for pp in a.photopointer_set.all ():
            link_ls = flmo.get_labelset ()
            link_ls.set_S (link_ls.get_S () + pp.get_slabel ())

            txt = cond_exec (link_ls, (PYTHON, '-c',
                                       per_photo_link_py (pp, link_ls, 'upload/editphoto')))
            photo_includes.append (txt)    

    return render_to_response ('objlist.html',
                               {'urlprefix': urlprefix (),
                                'obj_list': photo_includes,
                                'title': "Photo Editor: Album [%s]" % a.title,
                                'directions': "Pick one photo to edit",
                                })

def editphoto (request, photo_id, page_id):
    if is_prepare ():
        return "Foo"

    elif request.POST.has_key ('action'):
        action = request.POST['action']
        if action == 'rotateright' or action == 'update_metadata':
            p = Photo.objects.get (id=photo_id)

            if action == 'rotateright':
                import Image
                im = Image.open (p.filename)
                im = im.rotate (-90)
                ls = flmo.stat_file (p.filename)
                im.save (p.filename, labelset=ls, endpoint=ls)
            elif action == 'update_metadata':
                title = request.POST['title']
                caption = request.POST['caption']

                p = Photo.objects.get (id=photo_id)
                p.title = title
                p.caption = caption
                p.pub_date = datetime.datetime.now ()

                ls = flmo.stat_file (p.filename)
                p.save ()
            
            return HttpResponseRedirect (urlprefix () + '/upload/editphoto/%s/%s/' % (photo_id, new_page_id ()))

        else:
            return HttpResponse ("invalid action '%s'" % action)

    else:
        p = Photo.objects.get (id=photo_id)
        img_url = photo_url (p)
        return render_to_response ('editphoto.html',
                                   {'urlprefix': urlprefix (),
                                    'imgurl': img_url,
                                    'photo': p,
                                    'newpageid': new_page_id (),
                                    }
                                   )
