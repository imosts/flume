from django.db import models
from django.contrib.w5.models import User
import flume.flmos as flmo


class WidgetHtml (models.Model):    
    html = models.CharField ()
