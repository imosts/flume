#!/usr/local/bin/python
from string import letters
from random import randint

length = 8

print ''.join ([ letters[randint (0,51)] for x in range (length)])
