import datetime, flume, os, time
import flume.flmos as flmo
import urllib
from xml.dom import minidom
import w5djangoutil

from wikicode import get_uid, get_devel_un, PYTHON
from wikicode import combine_forward_ls, cond_exec
from wikicode.util import check_mkdir_label
import wikicode.db.user as w5user
from wikicode.db.user import User as W5User
from wikicode.prepare import is_prepare, prepare_stags

from django.shortcuts import render_to_response
from django.http import HttpResponse, HttpResponseRedirect
from django.core.urlresolvers import reverse
from django.contrib.w5.models import User, TagValue
from django.contrib.w5.util import urlprefix, new_page_id, base_ls, django_setup_py, get_one_py

from weathergrabber.models import Weather

WEATHER_URL = 'http://weather.yahooapis.com/forecastrss?p=%s'
WEATHER_NS = 'http://xml.weather.yahoo.com/ns/rss/1.0'

DBG_WEATHER_XML = """<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<rss version="2.0" xmlns:yweather="http://xml.weather.yahoo.com/ns/rss/1.0" xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#">
<channel>

<title>Yahoo! Weather - San Francisco, CA</title>
<link>http://us.rd.yahoo.com/dailynews/rss/weather/San_Francisco__CA/*http://weather.yahoo.com/forecast/94110_f.html</link>
<description>Yahoo! Weather for San Francisco, CA</description>
<language>en-us</language>
<lastBuildDate>Tue, 29 Apr 2008 8:56 am PDT</lastBuildDate>
<ttl>60</ttl>
<yweather:location city="San Francisco" region="CA"   country="US"/>
<yweather:units temperature="F" distance="mi" pressure="in" speed="mph"/>
<yweather:wind chill="54"   direction="270"   speed="17" />
<yweather:atmosphere humidity="72"  visibility="10"  pressure="30.1"  rising="1" />
<yweather:astronomy sunrise="6:16 am"   sunset="7:59 pm"/>
<image>
<title>Yahoo! Weather</title>
<width>142</width>
<height>18</height>
<link>http://weather.yahoo.com</link>
<url>http://l.yimg.com/us.yimg.com/i/us/nws/th/main_142b.gif</url>
</image>
<item>
<title>Conditions for San Francisco, CA at 8:56 am PDT</title>
<geo:lat>37.77</geo:lat>
<geo:long>-122.42</geo:long>
<link>http://us.rd.yahoo.com/dailynews/rss/weather/San_Francisco__CA/*http://weather.yahoo.com/forecast/94110_f.html</link>
<pubDate>Tue, 29 Apr 2008 8:56 am PDT</pubDate>
<yweather:condition  text="Mostly Cloudy"  code="28"  temp="54"  date="Tue, 29 Apr 2008 8:56 am PDT" />
<description><![CDATA[
<img src="http://l.yimg.com/us.yimg.com/i/us/we/52/28.gif"/><br />
<b>Current Conditions:</b><br />
Mostly Cloudy, 54 F<BR />
<BR /><b>Forecast:</b><BR />
Tue - Partly Cloudy. High: 58 Low: 47<br />
Wed - Sunny. High: 59 Low: 47<br />
<br />
<a href="http://us.rd.yahoo.com/dailynews/rss/weather/San_Francisco__CA/*http://weather.yahoo.com/forecast/USCA0987_f.html">Full Forecast at Yahoo! Weather</a><BR/>
(provided by The Weather Channel)<br/>
]]></description>
<yweather:forecast day="Tue" date="29 Apr 2008" low="47" high="58" text="Partly Cloudy" code="30" />
<yweather:forecast day="Wed" date="30 Apr 2008" low="47" high="59" text="Sunny" code="32" />
<guid isPermaLink="false">94110_2008_04_29_8_56_PDT</guid>
</item>
</channel>
</rss><!-- api1.weather.re4.yahoo.com uncompressed Tue Apr 29 09:51:47 PDT 2008 -->
"""

def weather_for_zip(zip_code):
    url = WEATHER_URL % zip_code
    xmldata = w5djangoutil.get_url(url)
    dom = minidom.parseString(xmldata)
    for node in dom.getElementsByTagNameNS(WEATHER_NS, 'forecast'):
        wdate = datetime.date(*time.strptime(node.getAttribute('date'), '%d %b %Y')[:3])
        low = node.getAttribute('low')
        high = node.getAttribute('high')
        condition = node.getAttribute('text')
        wcount = Weather.objects.filter(day=wdate).filter(zip=zip_code).count()
        if wcount == 0:
            w = Weather(day=wdate, zip=zip_code, low=low, high=high, condition=condition)
            w.save()
    ycondition = dom.getElementsByTagNameNS(WEATHER_NS, 'condition')[0]
    current_condition = ycondition.getAttribute('text')
    current_temp = ycondition.getAttribute('temp')
    current_date = ycondition.getAttribute('date')
    title = dom.getElementsByTagName('title')[0].firstChild.data


def getweather (request):
    if is_prepare ():
        return "Prepare does not make sense on this page."
    else:
        zips = ("94110", "02116", "94043", "02139", "60010")
        for z in zips:
            weather_for_zip(z)
    return HttpResponse("added weather for zips %s" % " ".join(zips))

def index (request):
    weather_list = Weather.objects.all()
    return render_to_response('weather.html',
                              {'weather_list':weather_list})
