import flume, re, os
from flume.flmos import Handle, Label, LabelSet, set_label, set_label2, req_privs, get_label, get_labelset

rx_cache = {}
def cached_re (*args):
    key = args
    if not rx_cache.has_key (key):
        rx_cache[key] = re.compile (*args)
    return rx_cache[key]

part_rxx = r'^\s*(S|I|O|CAPSET)\s*=\s*\((.*)\)\s*$'
opart_rxx = r'^\s*(ENV|LIT)\s*:\s*(.*)\s*,\s*(.*)\s*$'
sipart_rxx = r'^\s*(ENV|LIT|DB)\s*:\s*(.*)\s*$'

class TokenPair:
    def __init__ (self, handle, token):
        self.h = handle
        self.tok = token

    def __str__ (self):
        return '%s:%s' % (self.h, self.tok)

class LabelSetDesc:
    """
    Describes a capabilityset and labelset in a way that makes
    privilege acquisition and setting labels convenient.  If the S or
    I contains a capability, set_my_label will convert it to a tag
    before calling set_label.

    There is a difference between the 'O' label and the 'CAPSET'.

    LabelSetDesc always adds the capabilities in 'CAPSET' to the
    current process O label, however LabelSetDesc.get_label() returns
    the *description* provided in the 'O' label, not the process's
    actual O label.  We make this distinction because a user might use
    a LabelSetDesc to specify a file's I label and O label.  The user
    would need the {I+, W+} capabilies in its process O label, but the
    *file's* O label should only contain the {W+} capability.
    
    Describing how to get capabilities:
      1) The cap,group/token values themselves: 'LIT: 0x12345678, wnzcuc9s7nc6j2b9wc6w5vv3rxtg2jyw'
      2) Environment variable name, that contains a cap,group/token: 'ENV: MASTERW_CAP, MASTERW_TOK'

    Describing how to determine labels:
      1) a string containing the tag value: '0x12345678'
      2) a string of the form: 'user:tagname1', this class will query the database to get the tag value.

    An example <desc> string:
      'S=(LIT: 0x12345678; DB: user:etag)|'
      'I=(LIT: 0x87654321; ENV: MASTERI_CAP; DB: user:itag)|'
      'O=(ENV: MASTERW_CAP)|'
      'CAPSET=(LIT: 0x12345678, wnzcuc9s7nc6j2b9wc6w5vv3rxtg2jyw; ENV: MASTERW_CAP, MASTERW_TOK)'
    """

    def __init__ (self, S=[], I=[], O=[], CAPSET=[], desc=None, env=os.environ):
        if desc:
            assert S == I == O == CAPSET == [], 'cannot simultaneously specify S,I,O,CAPSET and desc'
            S, I, O, CAPSET = self._parse_desc (desc)
        else:
            assert desc is None, 'cannot simultaneously specify S,I,O,CAPSET and desc'

        self.oldls = None
        self._labelmap = { flume.LABEL_S: S,
                           flume.LABEL_I: I,
                           flume.LABEL_O: O,
                           'CAPSET': CAPSET }
        self.env = env

    def set_env (self, env):
        self.env = env

    def _parse_desc (self, desc):
        parts = desc.split ('|')
        assert len (parts) <= 4, 'too many parts in <desc> string %s' % (parts, )
        ret = {}

        for s in parts:
            m = cached_re (part_rxx).match (s)
            typ = m.group (1)
            assert ret.has_key(typ) is False, 'repeat description for label type %s' % (typ,)
            ret[typ] = m.group (2).split (';')

        for typ in ('S', 'I', 'O', 'CAPSET'):
            if ret.has_key (typ) is False:
                ret[typ] = []

        return [ret[typ] for typ in ('S', 'I', 'O', 'CAPSET')]

    def _get_labelinfo (self, labtyp, ret=None, env=None):
        """
        If labtyp = 'CAPSET'flum return a list like ((h1, tok1), (h2, tok2)...)
        Otherwise, return a list like (h1, h2...)
        if <ret> is not None, append to <ret>.
        """
        if not env:
            env = self.env

        parts = self._labelmap[labtyp]
        if ret is None:
            ret = []
        
        if labtyp in ('CAPSET',):
            for s in parts:
                m = cached_re (opart_rxx).match (s)
                typ = m.group (1)
                cap = m.group (2)
                tok = m.group (3)

                if typ == 'LIT':
                    pass
                elif typ == 'ENV':
                    cap = env[cap]
                    tok = env[tok]
                else:
                    raise ValueError, 'Unsupported cap/tok type \'%s\'' % typ

                caps = cap.split (',')
                toks = tok.split (',')
                if len (caps) != len (toks):
                    raise ValueError, 'Number of caps and toks does not match'

                for c, t in zip (caps, toks):
                    ret.append ((Handle (int (c, 16)), t))

        elif labtyp in (flume.LABEL_S, flume.LABEL_I, flume.LABEL_O):
            for s in parts:
                tags, typ = self.get_tags (s, gettype=True, env=env)
                if labtyp != flume.LABEL_O:
                    tags = [t.toTag () for t in tags]
                ret.extend (tags)

        return ret

    def get_tags (cls, s, gettype=False, env=None):
        """
        returns a list of tags
        """
        if not env:
            env=os.environ
        
        m = cached_re (sipart_rxx).match (s)
        typ = m.group (1)
        tag = m.group (2)

        if typ == 'LIT':
            h = [Handle (int (t, 16)) for t in tag.split (',')]
        elif typ == 'ENV':
            if not env.has_key (tag):
                raise AssertionError ('could not find %s in env %s'
                                      % (tag, '\n'.join ([str(s) for s in env.items ()])))
            
            tags = env[tag]
            h = [Handle (int (t, 16)) for t in tags.split (',')]
        elif typ == 'DB':
            raise NotImplementedError, 'does not work yet'
        else:
            raise ValueError, 'Unsupported tag type \'%s\'' % typ

        if gettype:
            return h, typ
        else:
            return h
    get_tags = classmethod(get_tags)

    def get_label (self, typ, env=None):
        info = self._get_labelinfo (typ, env=env)
        if typ in (flume.LABEL_S, flume.LABEL_I, flume.LABEL_O):
            # remove duplicates
            return Label (set(info))
        elif typ in ('CAPSET',):
            return Label ([ h[0] for h in info ])
        else:
            raise TypeError, "<typ> must be flume.LABEL_S, I, O or 'CAPSET'"

    def acquire_capabilities (self, savels=False, env=None):
        if savels:
            assert not self.oldls, 'weird, oldls should be None'
            self.oldls = get_labelset ()

        if not env:
            env = self.env

        olab = get_label (flume.LABEL_O)
        get_p = []
        for h, tok in self._get_labelinfo ('CAPSET', env=env):
            if h not in olab:
                get_p.append ((h, tok))
        for h, tok in get_p:
            req_privs (h, tok)

    def pop_labelset (self):
        assert self.oldls, 'oldls was undefined, nothing to pop to'
        set_label2 (S=self.oldls.get_S())
        set_label2 (I=self.oldls.get_I())
        set_label2 (O=self.oldls.get_O())
        self.oldls = None

    def get_proc_labelset (self):
        return LabelSet (S=self.get_label (flume.LABEL_S),
                         I=self.get_label (flume.LABEL_I),
                         O=self.get_label ('CAPSET'))

    def get_file_labelset (self, env=None):
        return LabelSet (S=self.get_label (flume.LABEL_S, env),
                         I=self.get_label (flume.LABEL_I, env),
                         O=self.get_label (flume.LABEL_O, env))
        
    def set_my_label (self, labtyp):
        if labtyp not in (flume.LABEL_S, flume.LABEL_I):
            raise TypeError, 'only works with S and I labels'
        
        taglist = get_label (labtyp).toList ()
        taglist = self._get_labelinfo (labtyp, ret=taglist)
        set_label (labtyp, Label (taglist))

    def set_my_labelset (self):
        """
        Acquires capabilities in CAPSET and sets the S and I labels
        according to the description.  This ignores the O label
        description.
        """
        self.acquire_capabilities ()
        self.set_my_label (flume.LABEL_I)
        self.set_my_label (flume.LABEL_S)

    def __str__ (self):
        return str(self._labelmap)

def test ():
    """
    To run this test:
    $ flumepython -c 'from flume.labelsetdesc import test; test()'
    """
    import flume.util as flmu
    import flume.flmos as flmo
    flmo.set_label2 (S=None, I=None, O=None)

    wtag, wcaps = flmu.makeTag ('pw', 'Test wtag')
    wtok = flmo.make_login (wcaps[0])

    etag, ecaps = flmu.makeTag ('e', 'Test etag')
    itag, icaps = flmu.makeTag ('i', 'Test itag')

    def checkmakecap (name, flags):
        if (not os.environ.has_key ('%s_CAP' % name) or
            not os.environ.has_key ('%s_TOK' % name)):
            tag, caps = flmu.makeTag (flags, 'Test %s' % name)
            tok = flmo.make_login (caps[0])
            os.envrion['%s_CAP' % name] = str(caps[0])
            os.envrion['%s_TOK' % name] = str(tok)
        else:
            caps = [Handle (int (os.environ['%s_CAP' % name], 16))]
            tag = caps[0].toTag()

        print 'returning %s %s' % (tag, caps[0])
        return tag, caps[0]

    mitag, micap = checkmakecap ('MASTERI', 'pi')
    mwtag, mwcap = checkmakecap ('MASTERW', 'pw')

    z = LabelSetDesc (desc=
#                      'S=(LIT:%x; DB: user:etag)| '
                      'S=(LIT:%x)| '
                      'I=(LIT: %x; ENV: MASTERI_CAP) |'
                      'O=(ENV: MASTERW_CAP) |'
                      'CAPSET=(LIT: %x, %s; ENV: MASTERI_CAP, MASTERI_TOK; ENV: MASTERW_CAP, MASTERW_TOK)'
                      % (etag.val(), itag.val(), wtag.val(), wtok))

    # Check that we parsed correctly
    desired_olab = Label ([mwcap])
    desired_proc_ls = flmo.LabelSet (S=Label ([etag]),
                                     I=Label ([itag, mitag]),
                                     O=Label ([wtag, micap, mwcap]))

    for desired, typ in ((desired_proc_ls.get_S(), flume.LABEL_S),
                         (desired_proc_ls.get_I(), flume.LABEL_I),
                         (desired_olab, flume.LABEL_O),
                         (desired_proc_ls.get_O(), 'CAPSET')):
        if z.get_label (typ) != desired:
            print "FAIL get_label %s returned incorrect value %s != %s" % (typ, z.get_label (typ), desired)
        else:
            print "PASS get_label %s returned correct value" % typ

    if z.get_proc_labelset () != desired_proc_ls:
        print "FAIL get_proc_labelset returned incorrect value"
    else:
        print "PASS get_proc_labelset returned correct value"

    desired_file_ls = flmo.LabelSet (S=Label ([etag]),
                                     I=Label ([itag, mitag]),
                                     O=Label ([mwcap]))
    if z.get_file_labelset () != desired_file_ls:
        print "FAIL get_file_labelset returned incorrect value"
    else:
        print "PASS get_file_labelset returned correct value"

    # Check that we were able to set our labels correctly.
    z.set_my_labelset ()
    ls = get_labelset ()
    if ls != desired_proc_ls:
        print "FAIL ls %s != %s" % (ls, desired_proc_ls)
    else:
        print "PASS my labelset is correct"
