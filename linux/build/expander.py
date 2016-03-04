
"""
expander.py

    A little filter that expands expressions of the form

      {x,y}_{a,b}

   to:

     x_a
     x_b
     y_a
     y_b

  ...etc
"""

import re
import sys

rxx = re.compile ("{(.*?)}")

def listify (i, el):
    if i % 2 == 0:
        return [ el ]
    else:
        return el.split(',')

def parse (line):
    return [ listify (*p) for p in enumerate (rxx.split (line)) ]

def expand (base, parts, out):
    if len(parts) == 0:
        out.write (base + "\n")
    else:
        for x in parts[0]:
            expand (base + x, parts[1:], out)

def main ():
    for line in sys.stdin:
        expand ( '', parse (line.strip ()), sys.stdout )


main ()
    
