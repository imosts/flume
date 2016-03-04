import flume
import flume.flmos as flmo
import flume.util as flmu

master_typs = ('E', 'I', 'W', 'R', 'GTAG', 'GGRP')

def master_cap (typ):
    return 'MASTER%s_CAP' % typ.upper ()

def master_tok (typ):
    return 'MASTER%s_TOK' % typ.upper ()

def all_env_vars ():
    all = []
    for typ in master_typs:
        all.extend ( [master_cap (typ), master_tok (typ)] )
    return all

def make_all ():
    all_tags = {}
    all_caps = {}
    all_toks = {}
    for typ, flags in (('e', 'pe'),
                       ('i', 'pi'),
                       ('w', 'pw'),
                       ('r', 'pr')):

        tag, caps = flmu.makeTag (flags, 'wikicode master %s' % typ)
        toks = [flmo.make_login (c) for c in caps]
        all_tags[typ] = tag
        all_caps[typ] = caps
        all_toks[typ] = toks

        print 'export %s=' % (master_cap(typ),) + ','.join (['0x%x' % c.val () for c in caps])
        print 'export %s=' % (master_tok(typ),) + ','.join (toks)

    def makegroup (name):
        ls = flmo.LabelSet (I=flmo.Label ([all_tags['i']]),
                            O=flmo.Label ([all_caps['w'][0]]))

        flmo.set_label2 (I=flmo.Label([all_tags['i']]))
        gtag, gcap = flmu.makeGroup (name, ls)
        gtok = flmo.make_login (gcap)
        return gtag, gcap, gtok


    # Make a master group for all individual tags and add the master tags to it
    # The MASTERGTAG_CAP capability group does not contain any sub-groups.
    gtag, gcap, gtok = makegroup ('wikicode GTAG')
    transfer = []
    for k in all_caps.keys():
        transfer.extend (all_caps[k])
    flmo.add_to_group (gtag, flmo.Label (transfer))

    print 'export %s=0x%x' % (master_cap ('GTAG'), gcap.val ())
    print 'export %s=%s' % (master_tok ('GTAG'), gtok)

    # Make a master group for all user capability sub-groups.  We keep
    # these separate from the tags, because we don't want to search groups
    # recursively (its slow and hammers IDD).
    gtag, gcap, gtok = makegroup ('wikicode GGRP')
    print 'export %s=0x%x' % (master_cap ('GGRP'), gcap.val ())
    print 'export %s=%s' % (master_tok ('GGRP'), gtok)



