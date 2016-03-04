
"""setuid.py

Utilities for making setuid wrapper files."""

import flume as flm
import flume.flmos as flmo

def makeWrapper (dest, argv, tag, token, ilabel=None, labelset=None,
                 mode=0644):
    """Make a setuid script with the given executable, capability/tag,
    token for login, and ilabel. Set the script labelset equal
    to the given one PLUS the secrecy tag for setuid."""

    t = flmo.setuid_handle ()
    
    if labelset is None:
        labelset = flmo.LabelSet ()

    l = labelset.get_S ()
    l += t
    labelset.set_S (l)

    dest += ".suwrp"

    fields = [ ("Tag", tag.armor32 ()),
               ("Token", token),
               ("Argv", ' '.join (argv) ) ]

    if ilabel is not None:
        fields += [ ("IntegrityLabel", ilabel.freeze ().armor32 ()) ]

    dat = ''.join ([ "%s\t%s\n" % (t[0], t[1]) for t in fields ])

    flmo.writefile (name=dest, mode=mode, labelset=labelset, data=dat)


def makeFilter (name, find, replace, caps, labelset=None, mode=0600,
                write_fn=None):
    """
    Make a filesystem filter, at the destination 'name';
    In this filter, find filters of the form 'find' and replace
    them with 'replace'. Use the given caps as declassification
    privileges. Apply the given labelset to the file, and also
    the FS access mode.
    """
    
    if len(caps) == 1:
        h = caps[0]
    else:
        h = flmo.new_group ("filtergroup for '%s'" % name, labelset)
        flmo.add_to_group (h, caps )

    tok = flmo.make_login (h)
    ff = find.freeze ()
    fr = replace.freeze ()

    fields = [ ("Handle", h.armor32()),
               ("Token", tok),
               ("Find", ff),
               ("Replace", fr) ]

    dat = ''.join ([ "%s\t%s\n" % (t[0], t[1]) for t in fields ])

    if not write_fn:
        write_fn = flmo.writefile
    write_fn (name=name,mode=mode,labelset=labelset,data=dat)
    
