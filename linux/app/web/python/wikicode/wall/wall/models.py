from django.db import models
from django.contrib.w5.models import User
import flume.flmos as flmo

class WallPost (models.Model):
    author = models.ForeignKey (User, related_name='wall_author_set')
    wallowner = models.ForeignKey (User, related_name='wall_owner_set')

    text = models.CharField (maxlength=200)
    pub_date = models.DateTimeField ()
    
    def __str__ (self):
        return 'WallPost %s -> %s: %s' % (self.author, self.wallowner, self.text)
