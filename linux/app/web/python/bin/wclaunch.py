#!/usr/bin/python
import wikicode, os, sys
from wikicode.launcher import wclauncher

if __name__ == '__main__':
    env = os.environ.copy ()
    wcl = wclauncher (env)
    respcode, headers, output = wcl.get_response ()

    # Format the output as a normal CGI process would
    all_headers = ['Status: ' + str (respcode)]
    all_headers.extend (['%s: %s' % (k, v) for k, v in headers])

    sys.stdout.write ('\r\n'.join (all_headers) + '\r\n\r\n')
    for o in output:
        sys.stdout.write (o)
    

        
