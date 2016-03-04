import sys

DELIMITERS = (' ',',')


def multisplit(string, delimiters):
	working = [string]
	for d in delimiters:
		result = []
		for word in working:
			result.extend(word.split(d))
		working = result
	return result

class Comparator:
	"""A class for repeatedly comparing a line of test output to a
	line in the expected template."""
	def __init__(self):
		self.handles = {}

	def compare_to_template(self, query, template):
		"""Return true iff the query matches the template.  Requres all
		previous lines of the template have been proessed."""
		q_label = []
		t_label = []
		inbraces = False
		donebraces = False
		for  (q, t) in zip(multisplit(query, DELIMITERS),
						   multisplit(template, DELIMITERS)):
			handled = False
			if t.startswith('{'):
				if not q.startswith('{'): return False
				t = t[1:]
				q = q[1:]
				inbraces = True
			if t.startswith('$'):
				if inbraces:
					if t.endswith('}'):
						if not q.endswith('}'): return False
						donebraces = True
						t = t[:-1]
						q = q[:-1]
					t_label.append(t)
					q_label.append(q)
				elif t in self.handles:
					if self.handles[t] != q:
						return False
				else:
					self.handles[t] = q
				handled = True
			if donebraces:
				print t_label, q_label
				if len(t_label) != len(q_label): return False
				for t_handle in t_label:
					if self.handles[t_handle] not in q_label:
						return False
			elif not handled:
				if t != q:
					print t, q
					return False
		return True

class Usage(Exception):
	"""Raised when the user has invoked the program incorrectly"""

	def print_usage(self):
		print """usage: python checker.py <candidatefile> <templatefile>"""

def main(argv = None):
	"""Going to be an output checker."""
	if argv == None: argv = sys.argv
	if len(argv) != 3:
		raise Usage()
	(progname, candidatefile, templatefile) = argv
	try:
		cand_handle = open(candidatefile)
		temp_handle = open(templatefile)
	except:
		raise Usage()
	try:
		check = Comparator()
		for (query, template) in zip(cand_handle.readlines(),
									 temp_handle.readlines()):
			result = check.compare_to_template(query, template)
			print result
	except:
		print "The files didn't match lengths or something"
		raise
		
if __name__ == "__main__":
	try:
		sys.exit(main())
	except Usage, u:
		u.print_usage()
		
