import datetime, wikicode
from django.db import models, transaction
from flume import *
import flume.flmos as flmo
import flume.util as flmu
from wikicode.db.util import DB_LSD

class User (models.Model):
    username = models.CharField (maxlength=128, unique=True)

    def tags (self, mask=None):
        if mask:
            masks = []
            for m in mask:
                opt, copts = flmu.flag2opts (m)
                masks.append ("(tagvalue >> 56) = %d" % (opt,))
            return self.tagvalue_set.extra (where=['(' + ' OR '.join (masks) + ')'])
        else:
            return self.tagvalue_set.all ()

    class FlumeMeta:
        tablelsd = DB_LSD (I=['ENV: MASTERI_CAP'],
                           O=['ENV: MASTERW_CAP'],
                           CAPSET=['ENV: MASTERI_CAP, MASTERI_TOK',
                                   'ENV: MASTERW_CAP, MASTERW_TOK'])
        
    class DuplicateError (Exception):
        pass

    def __str__ (self):
        return '%s' % (self.username,)

class Password (models.Model):
    user = models.OneToOneField (User)
    password = models.CharField (maxlength=128)
    g_token = models.CharField (maxlength=128)

    class FlumeMeta:
        tablelsd = DB_LSD (S=['ENV: MASTERR0_CAP'],
                           I=['ENV: MASTERI_CAP'],
                           O=['ENV: MASTERW_CAP'],
                           CAPSET=['ENV: MASTERR0_CAP, MASTERR0_TOK',
                                   'ENV: MASTERR1_CAP, MASTERR1_TOK',
                                   'ENV: MASTERI_CAP, MASTERI_TOK',
                                   'ENV: MASTERW_CAP, MASTERW_TOK'])

class ExpProtUserData (models.Model):
    user = models.OneToOneField (User)
    email = models.EmailField ()
    favoritecolor = models.CharField (maxlength=64)

    class FlumeMeta:
        tablelsd = DB_LSD (S=[], I=[], O=[])

    def __str__ (self):
        return '%s, %s' % (self.password, self.email)

class TagValue (models.Model):
    user = models.ForeignKey (User)
    tagvalue = models.BigIntegerField ()

    class FlumeMeta:
        tablelsd = DB_LSD (I=['ENV: MASTERI_CAP'],
                           O=['ENV: MASTERW_CAP'],
                           CAPSET=['ENV: MASTERI_CAP, MASTERI_TOK',
                                   'ENV: MASTERW_CAP, MASTERW_TOK'])
        
    def __str__ (self):
        return '%s' % (self.tagvalue, )

    def to_flume_tag (self):
        return flmo.Handle (self.tagvalue)

class TagName (models.Model):
    tagvalue = models.ForeignKey (TagValue)
    tagname = models.CharField (maxlength=128, unique=True)

    class FlumeMeta:
        tablelsd = DB_LSD (I=['ENV: MASTERI_CAP'],
                           O=['ENV: MASTERW_CAP'],
                           CAPSET=['ENV: MASTERI_CAP, MASTERI_TOK',
                                   'ENV: MASTERW_CAP, MASTERW_TOK'])
        # tagtype == export_protect
        #slabel = '{this}'
        #ilabel = '{user_i}'
        #olabel = '{user_w}'

        # tagtype == write_protect
        #slabel = ''
        #ilabel = '{user_i}'
        #olabel = '{user_w}'

    def __str__ (self):
        return '%s' % (tagname,)
"""
class Photo (asdf):

    class FlumeMeta:
        pass

    def __init__ (self, security_typ):
    olabel = "album.owner.wtag"

    if security_typ == public:
        slabel = ""

class PrivatePhoto (Photo):

    slabel = "album.owner.etag"

    slabel = "newtag"
    etag = models.Etag ("owner.group")
""" 
