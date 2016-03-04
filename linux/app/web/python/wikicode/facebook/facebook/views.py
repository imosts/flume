import flume, datetime, sys
import flume.flmos as flmo
from wikicode import get_uid, cond_exec, PYTHON, request_uri
from wikicode.prepare import is_prepare, prepare_stags
from wikicode.db.user import User as W5User
from wikicode.const import *
from wikicode.errors import *
from django.shortcuts import render_to_response
from django.http import HttpResponse, HttpResponseRedirect
from django.newforms import form_for_model, form_for_instance
from django.contrib.w5.models import User, TagValue
from django.contrib.w5.util import urlprefix, new_page_id
from facebook.models import ContactInfo, Interests, Status
import w5djangoutil

def index (request):
    return HttpResponse ("Safebook: anon mode is unused.")

def blank (request):
    return HttpResponse ("Safebook: blank")

def friend_tags (w5u):
    friends = w5u.get_acl_entries (FRIEND_ACL_NAME)


model_types = ([ContactInfo, 'ContactInfo', 'contact_id'],
               [Interests, 'Interests', 'interest_id'],
               [Status, 'Status', 'status_id'])

def get_form_data (request):
    # Protect all profile data with friends.
    u = User.objects.get (id=get_uid ())
    w5u = W5User.object_withid (u.id)
    etag = w5u.get_tag ('friends')
    slab = flmo.Label ([etag])
    flmo.set_label (flume.LABEL_S, slab)

    try:
        form_data = dict (request.POST.items())
        form_data['user'] = u.id

        for mt in model_types:
            Form = form_for_model (mt[0])
            form = Form (form_data)
            mt.append (form) # associate a form class to each model type

        all_valid = reduce (lambda a, b: a and b,
                            [mt[3].is_valid () for mt in model_types])

        if all_valid:
            for form in [mt[3] for mt in model_types]:
                obj = form.save (commit=False)
                if form_data.has_key (mt[2]):
                    obj.id = form_data[mt[2]]

                obj.save (desls=flmo.LabelSet (S=slab))

            return HttpResponseRedirect (urlprefix () + '/upload/'), None, None

        msg = [mt[3].errors for mt in model_types]
        return None, form_data, msg

    finally:
        flmo.set_label (flume.LABEL_S, flmo.Label ())

def make_form_html (form_data, user):
    def make_row (boundfield):
        return ('<tr><td>%s</td><td>%s</td></tr>'
                % (boundfield.html_name, boundfield))

    w5u = W5User.object_withid (get_uid ())
    etag = w5u.get_tag ('friends')
    slab = flmo.Label ([etag])
    flmo.set_label (flume.LABEL_S, slab)

    try:
        hidden_ids = []
        form_html = []
        for mt in model_types:
            l = list (getattr (user, "%s_set" % mt[1].lower ()).all ())
            if len (l) > 0:
                Form = form_for_instance (l[0])
                hidden_ids.append ((mt[2], l[0].id)) # send the id through the form
            else:
                Form = form_for_model (mt[0])
            form = Form (form_data)

            for field in form:
                if field.name != 'user':
                    form_html.append (make_row (field))
        form_html = '\n'.join (form_html)
        return form_html, hidden_ids
    finally:
        flmo.set_label (flume.LABEL_S, flmo.Label ())

def make_app_data (viewer, profile_owner):
    """ <viewer> is a W5User and <profile_owner> is a string """
    
    if viewer.un == profile_owner:
        priv = FBAPP_LINK_SELF_PRIV
        fri  = FBAPP_LINK_SELF_FRIEND
        pub  = FBAPP_LINK_SELF_PUB
        pair = FBAPP_LINK_SELF_PAIRWISE
    else:
        priv = FBAPP_LINK_VIEW_PRIV
        fri  = FBAPP_LINK_VIEW_FRIEND
        pub  = FBAPP_LINK_VIEW_PUB
        pair = FBAPP_LINK_VIEW_PAIRWISE

    def get_pairwise_tag (owner, target):
        try:
            t = owner.get_tag (target)
        except InvalidObject:
            t, caps = owner.maketag ('pe', target)
            # Assign the friend ACL to the new etag
            owner.set_aclinstance (target, FRIEND_ACL_NAME)
        return t
        
    # Make links for apps
    def make_link_data (appname):
        """ Returns a list of links for <appname> """
        # Link prefix for different labels

        # put all readable tags into private_ls
        readable_tags = [t for t in w5djangoutil.get_all_readable () if t.prefix () & flume.HANDLE_OPT_DEFAULT_ADD]
        private_ls = flmo.LabelSet (S=flmo.Label ([viewer.get_tag ('etag')] + readable_tags))
        
        friend_ls = flmo.LabelSet (S=flmo.Label ([viewer.get_tag ('friends')]))
        public_ls = flmo.LabelSet ()

        app_links = []
        for text, hint, mode, ls in ((priv, 'me', priv, private_ls),
                                     (fri, 'friends', fri, friend_ls),
                                     (pub, 'everyone', pub, public_ls)):
            if fbapp_link_names[appname][mode]:
                therest = text
                if viewer.un != profile_owner:
                    therest += '/%s' % profile_owner
                    
                url = urlprefix (link_ls=ls,
                                 mode=W5MODE_UNTRUSTED_PYFORK,
                                 therest=therest,
                                 cid=viewer.new_context_id (),
                                 devel=appname,
                                 geturl=True)

                app_links.append ({ 'link_name': '%s' % fbapp_link_names[appname][mode],
                                    'link_hint': '%s' % hint,
                                    'elem_id': '%s_mode' % mode,
                                    'url': url.absolute_uri ()})

        if viewer.un == profile_owner:
            # Make a link to private msg each individual friend
            for friend, fid in viewer.get_acl_entries (FRIEND_ACL_NAME):
                if fbapp_link_names[appname][pair]:
                    t = get_pairwise_tag (viewer, friend)
                    ls = flmo.LabelSet (S=flmo.Label ([t]))

                
                    app_links.append ( { 'link_name': '%s' % fbapp_link_names[appname][pair], 
                                         'link_hint': '%s' % friend,
                                         'elem_id': "%s_mode" % friend,
                                         'url': urlprefix (link_ls=ls, mode=W5MODE_UNTRUSTED_PYFORK,
                                                           therest='%s/%s' % (pair, friend),
                                                           cid=viewer.new_context_id (), devel=appname,
                                                           geturl=True).absolute_uri ()
                                     } )
        else:
            if fbapp_link_names[appname][pair]:
                t = get_pairwise_tag (viewer, profile_owner)
                ls = flmo.LabelSet (S=flmo.Label ([t]))
                app_links.append ( { 'link_name': '%s' % fbapp_link_names[appname][pair], 
                                     'link_hint': '%s' % profile_owner,
                                     'elem_id': "%s_mode" % profile_owner,
                                     'url': urlprefix (link_ls=ls, mode=W5MODE_UNTRUSTED_PYFORK,
                                                       therest='%s/%s' % (pair, profile_owner),
                                                       cid=viewer.new_context_id (), devel=appname,
                                                       geturl=True).absolute_uri ()
                                     } )

        return app_links

    app_data = {}
    for app in FBAPPS:
        print >> sys.stderr, "making app_data for %s" % app
        app_data[app] = make_link_data (app)
    return app_data

def upload (request):
    """ Render the basic Facebook profile page, accepts data with
    different labels and saves it to the DB. """
    
    msg = None
    form_data = None

    # Read existing data
    u = User.objects.get (id=get_uid ())
    w5u = W5User.object_withid (u.id)

    if request.POST.has_key ('update'):
        redirect, form_data, msg = get_form_data (request)
        if redirect:
            return redirect

    form_html, hidden_ids = make_form_html (form_data, u)
    app_data = make_app_data (w5u, u.username)

    friends = w5djangoutil.get_friendlist ()
    args = { 'username'  : w5u.un,
             'urlprefix' : urlprefix (),
             'hidden_ids': hidden_ids,
             'msg'       : msg,
             'labelset'  : flmo.get_labelset (),
             'form'      : form_html,
             'app_data'  : app_data,
             'friends'   : friends,
             }

    return render_to_response ('upload.html', args)

def viewprofile (request, un):
    w5u = W5User.object_withid (get_uid ())

    profile_user = User.objects.get (username=un)
    profile_w5user = W5User.object_withid (profile_user.id)

    ftag = profile_w5user.get_tag (FRIEND_ETAG_NAME)
    if (un != w5u.un and
        not profile_w5user.get_acl_decision (ftag, w5u)):
        return HttpResponse ("You are not allowed to view %s's profile" % un)
        
    interests = profile_user.interests_set.all ()
    if len (interests) > 0:
        interests = interests[0].interests
    else:
        interests = None
    
    status = profile_user.status_set.all ()
    if len (status) > 0:
        status = status[0].status
    else:
        status = None

    app_data = make_app_data (w5u, un)
    return render_to_response ('viewprofile.html',
                               {'profile_user': profile_user,
                                'interests': interests,
                                'status': status,
                                'app_data' : app_data,
                                })
