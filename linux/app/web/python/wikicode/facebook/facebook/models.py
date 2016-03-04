from django.db import models
from django.contrib.w5.models import User
import flume.flmos as flmo


class ContactInfo (models.Model):
    user = models.ForeignKey (User)
    
    firstname = models.CharField (maxlength=32)
    lastname = models.CharField (maxlength=32)
    phonenumber = models.PhoneNumberField ()
    emailaddr = models.EmailField ()

class Interests (models.Model):
    user = models.ForeignKey (User)

    interests = models.CharField (maxlength=512)

class Status (models.Model):
    user = models.ForeignKey (User)

    status = models.CharField (maxlength=512)
    
