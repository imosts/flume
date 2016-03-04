from django.contrib.w5.util import urlprefix, new_page_id, base_ls, django_setup_py, get_one_py
from django.http import HttpResponse
from django.shortcuts import render_to_response, get_object_or_404
from calendarapp.models import Event, Project
from weathergrabber.models import Weather
from django.newforms import form_for_model, form_for_instance, save_instance
from django import newforms as forms
from django.contrib.w5.models import User
from wikicode import get_uid
import datetime
import sys

EventForm = form_for_model(Event)
ProjectForm = form_for_model(Project)

def index(http_request, year=datetime.datetime.now().strftime("%Y"), month=datetime.datetime.now().strftime("%m")):
	"""
	This view should return a listing of events inside a calendar module.
	
	It accepts the parameters year and month. If they aren't given, it defaults to current year and current month
	"""
	# make sure the year number and month number are ints
	year = int(year)
	month = int(month)
	timestamp = datetime.datetime(year, month, 1)
	
	#initialize container for dates to be stored
	date_list = []
	
	events = Event.objects.filter(edate__year=year).filter(edate__month=month)
	for event in events:
		date_list.append({'id':event.id, 'day':datetime.date(event.edate.year, event.edate.month, event.edate.day), 'title':event.title, 'class':'event'})

	projects = Project.objects.filter(due__year=year).filter(due__month=month)
	for project in projects:
		date_list.append({'id':project.id, 'day':datetime.date(project.due.year, project.due.month, project.due.day), 'title':project.name, 'class':'projects'})
			
	# next month's timestamp
	if month == 12:
		next_month = datetime.datetime(year+1, 1, 1)
	elif month < 12:
		next_month = datetime.datetime(year, month+1, 1)
	
	upcoming_projects = Project.objects.filter(due__year=next_month.year).filter(due__month=next_month.month)
	
	
	return render_to_response('schedule_cal.html', 
				  {'date_list':date_list, 
				   'date':timestamp, 
                                   'urlprefix': urlprefix (),
				   'upcoming_projects':upcoming_projects}, 
				  )

def eventdetails(http_request, event_id=0):
	"""
	This view should return the details of the clicked on event
	and the associated weather at the time of the event
	"""
	e = get_object_or_404(Event, pk=event_id)
	weather = list(Weather.objects.filter(day=e.edate).filter(zip=e.zip))
	if len(weather) == 0:
		w = None
	else:
		w = weather[0]
	return render_to_response('event_detail.html', {'event': e,
							'w': w })

def projectdetails(http_request, project_id=0):
	"""
	This view should return the details of the clicked on project
	"""
	p = get_object_or_404(Project, pk=project_id)
	return render_to_response('project_detail.html', {'project': p})

def upload(http_request):
	u = User.objects.get (id=get_uid ())
	all_events = Event.objects.filter(owner=u)
	all_projects = Project.objects.filter(owner=u)
        return render_to_response ('upload.html',
                                   {'urlprefix': urlprefix (),
                                    'new_page_id': new_page_id (),
				    'all_events': all_events,
				    'all_projects': all_projects,
                                   })
	
def newevent(http_request):
	u = User.objects.get (id=get_uid ())
	if http_request.method == 'POST':
		form = EventForm(http_request.POST)
		owner = User.objects.get (id=get_uid())
		title = http_request.POST['title']
		e = forms.DateTimeField()
		entry = form['edate']
		edate = e.clean(entry.data)
		zip = http_request.POST['zip']
		event = Event (owner=owner, title=title, edate=edate, zip=zip)
		event.save()
		return HttpResponse("done")
	f = EventForm()
	return render_to_response('newevent.html',
				  {'form': f,
                                   'urlprefix': urlprefix (),
				   })

