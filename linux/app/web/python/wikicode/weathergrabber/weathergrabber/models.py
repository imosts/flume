import datetime
from django.db import models
from django.contrib.w5.models import User
import flume.flmos as flmo

class Weather (models.Model):
    day = models.DateField ()
    zip = models.CharField (maxlength=5)
    low = models.IntegerField ()
    high = models.IntegerField ()
    condition = models.CharField (maxlength=300)
    
    def __str__ (self):
        return self.condition
