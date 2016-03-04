import datetime
from django.db import models
from django.contrib.w5.models import User

import flume
import flume.flmos as flmo

class BlogPointer (models.Model):
    owner = models.ForeignKey (User)
    labelset = models.CharField (maxlength=512)
    page_id = models.CharField (maxlength=16)
    pub_date = models.DateTimeField ()

    def get_slabel (self):
        ls = self.get_labelset ()
        return ls.get_S ()

    def get_labelset (self):
        ls = flmo.LabelSet ()
        ls.fromRaw (flmo.RawData (self.labelset, True))
        return ls

class Blog (models.Model):
    blogpointer = models.ForeignKey (BlogPointer)
    
    title = models.CharField (maxlength=200)
    owner = models.ForeignKey (User)
    pub_date = models.DateTimeField ()

    def __str__ (self):
        return 'Blog %s (%s)' % (self.title, self.owner)

class PostPointer (models.Model):
    blog = models.ForeignKey (Blog)
    labelset = models.CharField (maxlength=512)
    page_id = models.CharField (maxlength=16)
    owner = models.ForeignKey (User)
    pub_date = models.DateTimeField ()

    def get_slabel (self):
        ls = self.get_labelset ()
        return ls.get_S ()

    def get_labelset (self):
        ls = flmo.LabelSet ()
        ls.fromRaw (flmo.RawData (self.labelset, True))
        return ls
    
    def __str__ (self):
        return '<postpointer %s ls %s>' % (self.postid, self.slabel)

class Post (models.Model):
    postpointer = models.ForeignKey (PostPointer)
    owner = models.ForeignKey (User)

    title = models.CharField (maxlength=200)
    text = models.TextField (maxlength=1000)
    pub_date = models.DateTimeField ()

    def __str__ (self):
        return self.title

