import flume.flmos as flmo
flmo.set_libc_interposing (True)

# Setup Django environment
from django.core.management import setup_environ
try:
    import settings # Assumed to be in the same directory.
except ImportError:
    import sys
    sys.stderr.write("""
    Error: Can't find the file 'settings.py' in the directory
    containing %r. It appears you've customized things.\nYou'll have
    to run django-admin.py, passing it your settings module.\n(If the
    file settings.py does indeed exist, it's causing an ImportError
    somehow.)\n""" % __file__)
    sys.exit(1)
setup_environ (settings)


# Tester code
from mysite.polls.models import Poll, Choice
from datetime import datetime

print '---------------------------------------------------------'

# Create an object
p = Poll(question="What's up?", pub_date=datetime.now())
p.save ()
myid = p.id

# Retrieve an object
q = Poll.objects.get(id=myid)
assert isinstance (q.pub_date, datetime)
#q.pub_date = datetime (2005, 4, 1, 0, 0)
#q.save ()

print "p is %s" % p
print "q is %s" % q
print "pubdate is type datetime %s" % isinstance (q.pub_date, datetime)
print "poll objects: %s" % (Poll.objects.all (), )
print "was published today %s" % [x.was_published_today () for x in Poll.objects.all ()]

# Add questions
p = Poll.objects.get(pk=myid)
p.choice_set.create(choice='Not much', votes=0)
p.choice_set.create(choice='The sky', votes=0)
c = p.choice_set.create(choice='Just hacking again', votes=0)
print "poll: %s" % c.poll
print "all choices: %s" % p.choice_set.all()
print "choice count: %s" % p.choice_set.count()
print ("all choicees from this year: %s" %
       Choice.objects.filter(poll__pub_date__year=datetime.now().year))

print "filtered: %s" % Poll.objects.filter(question__startswith='What')
p.delete ()

#print dir (p.question)
#print dir (p.pub_date)

#p.pub_date

