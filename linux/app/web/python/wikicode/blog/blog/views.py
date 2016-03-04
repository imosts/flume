import datetime, flume, wikicode
import flume.flmos as flmo
from wikicode import get_uid, get_devel_un, cond_exec, PYTHON
from wikicode.prepare import is_prepare, prepare_stags
from wikicode.db.user import User as W5User
from django.shortcuts import render_to_response
from django.http import HttpResponse, HttpResponseRedirect
from django.core.urlresolvers import reverse
from blog.models import BlogPointer, Blog, PostPointer, Post
from django.contrib.w5.models import User, TagValue
from django.contrib.w5.util import urlprefix, new_page_id, base_ls, django_setup_py, get_one_py

def index (request):
    if wikicode.IMODE & wikicode.IMODE_USER:
        blog_list = Blog.objects.itag_owner_in_col ('owner_id')
    else:
        blog_list = Blog.objects.all ()

    import w5djangoutil
    readable_tags = w5djangoutil.get_all_readable ()
    link_ls = flmo.get_labelset ()
    link_ls.set_S (link_ls.get_S () + readable_tags)

    #w5djangoutil.send_email ('bob', "hello bob")

    return render_to_response('index.html',
                              {'urlprefix': urlprefix (),
                               'urlprefix_alltags': urlprefix (link_ls=link_ls),
                               'blog_list': blog_list})

def viewblog (request, blog_id):
    import w5djangoutil

    b = Blog.objects.get (id=blog_id)
    w5owner = W5User.object_withid (b.owner.id)
    my_ls = flmo.get_labelset ()

    if wikicode.IMODE & wikicode.IMODE_USER:
        postpointers = b.postpointer_set.itag_has ([w5owner.script_tag ()])
    else:
        postpointers = b.postpointer_set.all ()
    post_list = []
    widget_list = []
    for pp in postpointers:
        if w5djangoutil.may_read (pp.get_labelset ()):
            post_ls = my_ls.clone ()
            post_ls.set_S (post_ls.get_S () + pp.get_slabel ())

            txt = cond_exec (post_ls, (PYTHON, '-c', show_post_py (pp.id)))
            post_list.append (txt)

    return render_to_response('viewblog.html',
                              {'urlprefix': urlprefix (),
                               'title': b.title,
                               'post_list': post_list,
                               'widget_list': widget_list,
                               })

def show_post_py (pointer_id):
    return (get_one_py (get_devel_un (), 'Post', 'owner', pointer_id) +
            "print ('<p>Title: %s<BR>Date: %s<BR>Text: %s<BR>' % (obj.title, obj.pub_date, obj.text));")

def per_blog_link_py (pointer_id, link_ls, subdir):
    # This assumes that the current labelset has S={}
    # Prints a link <a href=/...devel/(subdir)/(blog_id)/(page_id)/><title></a>
    return (get_one_py (get_devel_un (), 'Blog', 'owner', pointer_id) + 
            "print ('<A HREF=\"%s/%s/%%s/%d/\">%%s</a>' %% (obj.id, obj.title)); "
            % (urlprefix (link_ls), subdir, new_page_id ()))

def upload (request):
    #import w5djangoutil
    #w5djangoutil.send_email ('bob', "hello bob")

    if is_prepare ():
        return "Prepare does not make sense on this page."
    else:
        u = User.objects.get (id=get_uid ())
        w5u = W5User.object_withid (u.id)

        if wikicode.IMODE & wikicode.IMODE_USER:
            blog_pointers = u.blogpointer_set.itag_has ([w5u.script_tag ()])
        else:
            blog_pointers = u.blogpointer_set.all ()

        blog_includes = []
        for bp in blog_pointers:
            blog_ls = flmo.get_labelset ()
            blog_ls.set_S (blog_ls.get_S () + bp.get_slabel ())

            txt = cond_exec (blog_ls, (PYTHON, '-c',
                                       per_blog_link_py (bp.id, blog_ls, 'upload/newpost')))
            blog_includes.append (txt)

        return render_to_response ('upload.html',
                                   {'urlprefix': urlprefix (),
                                    'blog_includes': blog_includes,
                                    'new_page_id': new_page_id (),
                                    })
                               
def make_postpointer (pointer_ls, blog, post_ls, page_id):
    u = User.objects.get (id=get_uid ())

    if len (pointer_ls.get_S ()) > 0:
        return ("Error, tried to create post pointer "
                "with S label %s.  Should be empty" % pointer_ls)

    pp = PostPointer (blog=blog, owner=u,
                      labelset=post_ls.toRaw ().armor (),
                      page_id=page_id, pub_date=datetime.datetime.now ())
    pp.save (desls=pointer_ls)
    return pp

def newpost (request, blog_id, page_id):
    blog = Blog.objects.get (id=blog_id)
    bp = blog.blogpointer

    if is_prepare ():
        post_ls = base_ls ()
        post_ls.set_S (flmo.Label (set (post_ls.get_S ()) | set (prepare_stags ())))
        bp = make_postpointer (bp.get_labelset (), blog, post_ls, page_id)
        return ("Created a PostPointer with id %d and ls %s for page_id %s"
                % (bp.id, post_ls, page_id))

    if request.POST.has_key ('title'):
        title = request.POST['title']
        text = request.POST['content']
        previous_page_id = request.POST['page_id']
        try:
            pp = PostPointer.objects.get (page_id=previous_page_id)
        except PostPointer.DoesNotExist:
            pp = make_postpointer (bp.get_labelset (), blog, base_ls (), page_id)
            
        if pp.get_labelset () != base_ls ():
            return HttpResponse ("Error, uploader (%s) should have same S label "
                                 "as the new post (%s)." % (base_ls (), pp.get_labelset ()))

        p = Post (postpointer=pp, title=title, text=text,
                  owner=User.objects.get (id=get_uid ()),
                  pub_date=datetime.datetime.now())
        p.save (desls=pp.get_labelset ())
        return HttpResponse ("done")

    else:
        proc_slabel = flmo.get_label (flume.LABEL_S)
        blog_slabel = blog.blogpointer.get_slabel ()
        if proc_slabel != blog_slabel:
            return HttpResponse ("Error, post uploader (%s) should have same S label "
                                 "as the blog (%s)." % (proc_slabel, blog_slabel))

        return render_to_response ('newpost.html',
                                   {'urlprefix': urlprefix (),
                                    'blog_id': blog_id,
                                    'page_id': page_id,
                                    'new_page_id': new_page_id (),
                                    })

def make_blogpointer (pointer_ls, user, blog_ls, page_id):
    if len (pointer_ls.get_S ()) > 0:
        return ("Error, tried to create blog pointer "
                "with S label %s.  Should be empty" % pointer_ls)

    bp = BlogPointer (owner=user, labelset=blog_ls.toRaw ().armor (),
                      page_id=page_id, pub_date=datetime.datetime.now ())
    bp.save (desls=pointer_ls)
    return bp

def newblog (request, page_id):
    u = User.objects.get (id=get_uid ())
    
    if is_prepare ():
        blog_ls = base_ls ()
        blog_ls.set_S (flmo.Label (set (blog_ls.get_S ()) | set (prepare_stags ())))
        bp = make_blogpointer (base_ls (), u, blog_ls, page_id)
        return ("Created BlogPointer with id %d and S label %s for page_id %s"
                % (ap.id, blog_ls, page_id))

    elif request.POST.has_key ('title'):
        title = request.POST['title']
        previous_page_id = request.POST['page_id']
        try:
            bp = BlogPointer.objects.get (page_id=previous_page_id)
        except BlogPointer.DoesNotExist:
            bp = make_blogpointer (base_ls (), u, base_ls (), page_id)

        b = Blog (blogpointer=bp, title=title, owner=u, pub_date=datetime.datetime.now ())
        b.save (desls=bp.get_labelset ())
        return HttpResponseRedirect (urlprefix () + '/upload/newpost/%d/%d/' % (b.id, new_page_id ()))

    else:
        return render_to_response ('newblog.html',
                                   {'urlprefix': urlprefix (),
                                    'page_id': page_id,
                                    'new_page_id': new_page_id (),
                                    })

def search (request):
    if request.GET.has_key ('keywords'):
        keywords = request.GET['keywords']
        keywords = keywords.split ()

        post_list = Post.objects.all ()
        for kw in keywords:
            post_list = post_list.filter (text__icontains=kw)

        return render_to_response('search.html',
                                  {'title': "Search results",
                                   'post_list': post_list,
                                   })
    else:
        return HttpResponse ("Missing form input 'keywords'")
        
