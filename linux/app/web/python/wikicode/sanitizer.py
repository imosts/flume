import HTMLParser, string, wikicode, sys, cgi, urlparse
import flume.flmos as flmo
from wikicode.errors import *
from wikicode.const import *
from wikicode.spawn import spawn_child
from wikicode.util import parse_response, parse_content_type
from flume.labelsetdesc import LabelSetDesc

# Permit Javascript for debugging
PERMIT_JS = False

legal_headers = ('content-language', 'content-type', 'content-length', 'md5-digest',
                 'date', 'last-modified', 'status', 'location')

legal_httpequiv = ('refresh', 'content-type')
legal_charset = ('utf-8',)

# These are the HTML tags that we will leave intact
base_valid_tags =  ['big', 'body', 'br', 'center', 'code', 'dd', 'div', 'dl', 'dt',
                    'em', 'font', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
                    'head', 'hr', 'html', 'i', 'iframe', 'input', 'li', 'menu',
                    'ol', 'option', 'p', 'pre', 'small', 'span', 'strong',
                    'style', 'table', 'tbody', 'thead',
                    'td', 'textarea', 'th', 'title', 'tr', 'tt', 'u', 'ul']

# Tags with fields which we need to check
base_check_tags = {'a':      'href',
                   'embed':  'src',
                   'iframe': 'src',
                   'img':    'src',
                   'form':   'action',
                   'meta':   'url'}

class StrippingParser(HTMLParser.HTMLParser):

    def __init__(self, ls, launcher_env, child_env, user_may_transition=None, user_may_read=None):
        HTMLParser.HTMLParser.__init__(self)
        self.result = []
        self.endTagList = []
        self.ls = ls
        self.launcher_env = launcher_env
        self.child_env = child_env
        self.user_may_transition = user_may_transition
        self.user_may_read = user_may_read
        self.valid_tags = list (base_valid_tags)
        if PERMIT_JS:
            self.valid_tags.append ('script')
        self.check_tags = base_check_tags.copy ()

    def get_result (self):
        return ''.join (self.result)
        
    def handle_data(self, data):
        if data:
            self.result.append (cgi.escape (data))

    def handle_charref(self, name):
        self.result.append ('&#%s;' % name)
        
    def handle_entityref(self, name):
        self.result.append ('&%s;' % name)

    def handle_cond_exec (self, tag, attrs):
        include_ls = None
        exc = []
        for k, v in attrs:
            if k.lower() == 'labelset':
                include_ls = wikicode.decode_labelset (v)
            elif k.lower() == 'exec':
                exc.append (wikicode.unescape(v))
        
        if not include_ls:
            raise WCExtensionError ('Undefined labelset argument in cond_exec')
        if len (exc) == 0:
            raise WCExtensionError ('Undefined exec argument in cond_exec')

        # Is the client allowed to include something with label <ls>?
        if self.user_may_transition and not self.user_may_transition (self.ls, include_ls):
            raise WCExtensionError ('Condition include tried an illegal transition from %s to %s'
                                    % (self.ls, include_ls))
        if self.user_may_read and not self.user_may_read (include_ls):
            return ''

        # Spawn it!
        lsd = LabelSetDesc (CAPSET=['ENV: MASTERGTAG_CAP, MASTERGTAG_TOK'], env=self.launcher_env)
        lsd.acquire_capabilities (savels=True)
        try:
            out, err, status = spawn_child (include_ls, exc, env=self.child_env)
        finally:
            lsd.pop_labelset ()

        #sys.stderr.write ("output is %s\n" % out )
        sys.stderr.write (err)
        return sanitize_include (include_ls, self.launcher_env, self.child_env, out)

    def handle_cond_inc (self, tag, attrs):
        include_ls = None
        include_txt = None
        for k, v in attrs:
            if k.lower() == 'labelset':
                include_ls = wikicode.decode_labelset (v)
            elif k.lower() == 'include':
                include_txt = wikicode.unescape(v)
        
        if not include_ls:
            raise WCExtensionError ('Undefined labelset argument in cond_inc')
        if not include_txt:
            raise WCExtensionError ('Undefined include argument in cond_inc')

        # Is the client allowed to include something with label <ls>?
        if self.user_may_transition and not self.user_may_transition (self.ls, include_ls):
            raise WCExtensionError ('Condition include tried an illegal transition from %s to %s'
                                    % (self.ls, include_ls))
        if self.user_may_read and not self.user_may_read (include_ls):
            return ''

        return sanitize_include (include_ls, self.launcher_env, self.child_env, include_txt)

    def gen_tag (self, tag, attrs):
        s = '<%s' % tag
        if len (attrs) > 0:
            s += ' %s' % ''.join ([' %s="%s"' % (k,v) for k,v in attrs])
        s += '>'
        return s

    def check_meta (self, tag, attrs):
        for k, v in attrs:
            if k.lower () == 'http-equiv' and v.lower () in legal_httpequiv:
                return
                
        raise WCExtensionError ('Illegal tag (not http-equiv and %s) %s'
                                % (legal_httpequiv, self.gen_tag (tag, attrs)))
            
    def handle_starttag(self, tag, attrs):
        """ Strip invalid tags and check wikicode labels """

        if tag == 'cond_exec':
            self.result.append (self.handle_cond_exec (tag, attrs))
            return

        if tag == 'cond_inc':
            self.result.append (self.handle_cond_inc (tag, attrs))
            return

        # Ignore invalid tags
        if tag not in (list (self.valid_tags) + self.check_tags.keys ()):
            sys.stderr.write ('stripping unknown tag: %s\n' % tag)
            return

        # Detect Javascript in all tags
        if not PERMIT_JS:
            for k, v in attrs:
                if k.lower ().startswith ('on') or v.lower ().startswith ('javascript'):
                    raise WCUnsupported, 'extension generated javascript in argument "%s"' % k

        # Check that links all contain correct originiation labelset
        if tag in self.check_tags.keys ():
            field = self.check_tags[tag]
            for k,v in attrs:
                if k.lower () == field:
                    check_link (self.ls, v, self.user_may_transition, env=self.launcher_env)

        # Check meta after checking labelsets because we need to check
        # the URL in refresh commands
        if tag == 'meta':
            self.check_meta (tag, attrs)
        
        # If all the checks pass, then append the tag.
        self.result.append (self.gen_tag (tag, attrs))

    def handle_endtag(self, tag):
        if tag in (list (self.valid_tags) + self.check_tags.keys ()):
            self.result.append ("</%s>" % tag)

class StrictStrippingParser (StrippingParser):
    def __init__ (self, *args, **kwargs):
        StrippingParser.__init__ (self, *args, **kwargs)
        self.valid_tags.remove ('input')

def check_link (page_ls, link, user_may_transition=None, env=None):
    if not env:
        env=os.environ
    # Check wikicode urls
    uri = wikicode.W5Uri (link, env=env, trusted=False)

    if (uri.mode in trusted_modes and
        len (uri.ls2.get_S ()) == 0 and
        len (uri.ls2.get_I ()) == 0 and
        len (uri.ls2.get_O ()) == 0):
        # Allow anyone to link to a trusted page, if the ls is empty.
        # This allows untrusted pages to get rid of S tags when
        # linking to start page, but prevents untrusted pages from
        # linking to high integrity pages.
        return

    # Check that it is legal to transition from page_ls to ls2.
    if user_may_transition:
        if uri.ls2 and not user_may_transition (page_ls, uri.ls2):
            raise WCExtensionError, ('Link page_ls %s may not transition to ls2 %s' % (page_ls, uri.ls2))

def sanitize_include (ls, launcher_env, child_env, s, may_transition=None, may_read=None):
    """ Sanitize HTML to be included inside another HTML """
    return sanitize_html (ls, launcher_env, child_env, s, may_transition, may_read, StrictStrippingParser)

def sanitize_html (ls, launcher_env, child_env, s, may_transition=None, may_read=None, parsertype=StrippingParser):
    """
    1) Strip illegal HTML tags and javascript.
    2) Ensure proper s,i,o to link_from page.
    """
    try:
        parser = parsertype (ls, launcher_env, child_env, may_transition, may_read)
        parser.feed(s)
        parser.close()
        return parser.get_result ()
    except Exception:
        sys.stderr.write ("got error on page: %s\n" % s)
        raise
    
def validate_headers (hlist, ls, may_transition, env=None):
    if not env:
        env=os.environ
    
    # Check for illegal header lines
    diff = set ([h[0] for h in hlist]) - set (legal_headers)
    if len (diff) > 0:
        raise WCExtensionError ('Illegal HTTP headers: %s' % (list (diff),))

    # Validate the 'location' URL
    for h in hlist:
        if h[0] == 'location':
            check_link (ls, h[1], may_transition, env=env)
        elif h[0] == 'content-type':
            typ, params = parse_content_type (h[1])
            if typ in ('text/html',):
                if params.has_key ('charset') and params ['charset'] not in legal_charset:
                    raise WCExtensionError ('Unsupported charset: %s' % (params ['charset'],))

NO_SANITIZE_NECESSARY = ['text/plain', 'text/css', 'image/jpeg', 'image/gif']

def sanitize_response (ls, launcher_env, child_env, s, may_transition=None, may_read=None):
    """ Sanitize a response based on content type. """

    headers, content, hlist = parse_response (s)
    validate_headers (hlist, ls, may_transition, env=launcher_env)

    # Check for content-types and sanitize content.
    for h in hlist:
        if h[0] == 'content-type':
            typ, params = parse_content_type (h[1])
            if typ in ('text/html',):
                content = sanitize_html (ls, launcher_env, child_env, content, may_transition, may_read)
            elif typ in ['text/javascript']:
                raise WCExtensionError ("%s content-type not permitted in non-JS mode" % typ)
            elif typ in NO_SANITIZE_NECESSARY:
                pass
            else:
                raise WCExtensionError ("Unknown content-type: '%s'" % cgi.escape (typ))

    return headers + '\r\n\r\n' + content
    
def sanitize_response_lite (ls, launcher_env, child_env, s, may_transition=None, may_read=None):
    # Just do basic checks on headers like content type, etc.
    # We use this when we're allowing Javascript
    
    # Check for content-types and sanitize content.
    headers, content, hlist = parse_response (s)
    for h in hlist:
        if h[0] == 'content-type':
            typ, params = parse_content_type (h[1])
            if typ in ('text/html',):
                pass
            elif typ in NO_SANITIZE_NECESSARY + ['text/javascript']:
                pass
            else:
                raise WCExtensionError ("Unknown content-type: '%s'" % cgi.escape (typ))

    return headers + '\r\n\r\n' + content
