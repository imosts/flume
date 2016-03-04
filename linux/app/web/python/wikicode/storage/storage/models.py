from django.db import models
from django.contrib.w5.models import User
import flume.flmos as flmo

class Datum (models.Model):
    k = models.CharField (maxlength=256)
    v = models.CharField (maxlength=4096)
    slab = models.CharField (maxlength=512)
    olab = models.CharField (maxlength=512)
