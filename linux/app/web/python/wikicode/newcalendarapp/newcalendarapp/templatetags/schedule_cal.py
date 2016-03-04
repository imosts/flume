import datetime
import calendar
import string
from django import template

register = template.Library()


@register.inclusion_tag('month_cal.html')
def schedule_cal(date = datetime.datetime.now(), cal_items=[], urlprefix=""):
	""" 
	This will generate a calendar. It expects the year & month (in datetime format)
	and a list of dicts in the following format:
	
	cal_items = [{ 'id':1, 'day':14, 'title':"Concert at Huckelberries" }, { 'id':2, 'day':17, 'title':"BBQ at Mom\'s house"}]
	
	"""
	# Set the values pulled in from urls.py to integers from strings
	year = date.year
	month = date.month
	
	# account for previous month in case of Jan
	if month-1 == 0:
		lastmonth = 12
	else:
		lastmonth = month-1
	
	month_range = calendar.monthrange(year, month)
	first_day_of_month = datetime.date(year, month, 1)
	last_day_of_month = datetime.date(year, month, month_range[1])
	num_days_last_month = calendar.monthrange(year, lastmonth)[1]
	# first day of calendar is:
	#
	# first day of the month with days counted back (timedelta)
	# until Sunday which is day-of-week_num plus one (for the
	# 0 offset) 
	#
	
	first_day_of_calendar = first_day_of_month - datetime.timedelta(first_day_of_month.weekday())
	
	# last day of calendar is:
	# 
	# the last day of the month with days added on (timedelta) 
	# until saturday[5] (the last day of our calendar)
	#
	
	last_day_of_calendar = last_day_of_month + datetime.timedelta(12 - last_day_of_month.weekday())
	
	month_cal = []
	week = []
	week_headers = []
	for header in calendar.weekheader(2).split(' '):
		week_headers.append(header)
	day = first_day_of_calendar
	while day <= last_day_of_calendar:
		
		cal_day = {} 				# Reset the day's values
		cal_day['day'] = day		# Set the value of day to the current day num
		cal_day['event'] = []		# Clear any events for the day
		for event in cal_items:		# iterate through every event passed in
			if event['day'] == day:	# Search for events whose day matches the current day
				cal_day['event'].append({'title':event['title'], 'id':event['id'], 'class':event['class']}) # If it is happening today, add it to the list
		if day.month == month:		# Figure out if the day is the current month, or the leading / following calendar days
			cal_day['in_month'] = True
		else:
			cal_day['in_month'] = False
		week.append(cal_day)		# Add the current day to the week
		if day.weekday() == 6:		# When Sunday comes, add the week to the calendar
			month_cal.append(week)	
			week = []				# Reset the week
		day += datetime.timedelta(1) 		# set day to next day (in datetime object)
	
	return {'month_cal': month_cal, 'headers': week_headers, 'date':date, 'urlprefix':urlprefix}
