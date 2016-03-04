from django.db import models
from django.contrib.w5.models import User
import flume.flmos as flmo


class PokeMsg (models.Model):
    sender = models.ForeignKey (User, related_name='poke_sender_set')
    recipient = models.ForeignKey (User, related_name='poke_recipient_set')

    text = models.CharField (maxlength=200)
    pub_date = models.DateTimeField ()
    
    def __str__ (self):
        return 'Poke %s -> %s: %s' % (self.sender, self.recipient, self.text)
