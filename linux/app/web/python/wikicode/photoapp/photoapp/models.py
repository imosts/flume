import datetime
from django.db import models
from django.contrib.w5.models import User
import flume.flmos as flmo

class AlbumPointer (models.Model):
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
    
    def __str__ (self):
        return '<albumpointer %s ls %s>' % (self.id, self.get_labelset ())

class Album (models.Model):
    albumpointer = models.ForeignKey (AlbumPointer)

    title = models.CharField (maxlength=200)
    owner = models.ForeignKey (User)
    pub_date = models.DateTimeField ()
    
    def __str__ (self):
        return 'Album %s (%s)' % (self.title, self.owner)

class PhotoPointer (models.Model):
    album = models.ForeignKey (Album)
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
    
    def __str__ (self):
        return '<photopointer %s ls %s>' % (self.id, self.get_labelset ())

class Photo (models.Model):
    photopointer = models.ForeignKey (PhotoPointer)

    title = models.CharField (maxlength=128)
    caption = models.TextField (maxlength=256)
    pub_date = models.DateTimeField ()
    filename = models.TextField (maxlength=256)

    def __str__ (self):
        return self.title

