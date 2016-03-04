
// -*-c++-*-

#include "testharness.h"
#include "rxx.h"
#include "flume_prot.h"
#include "flume.h"
#include "sha1.h"
#include "serial.h"

//-----------------------------------------------------------------------

bool arg_is (const str &in, const str &arg)
{
  if (in.len () < arg.len ())
    return false;
  else
    return (memcmp (arg.cstr (), in.cstr (), arg.len ()) == 0);
}

//-----------------------------------------------------------------------

tamed void
test_harness_t::handle_op_std (const vec<str> &args, cbb cb)
{
  tvars {
    bool handled (true);
    bool ok;
    int a;
  }

  a = str2cmd (args[0]);
  
  switch (a) {
  case CMD_NEW_HANDLE:
    {
      twait { new_handle (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: newh [-+p:]<handle-name>      "
	  "(make a new hndl; -p for persistent; +/- for default add/sub)\n";
      }
      break;
    }

  case CMD_REQ_PRIVS:
    {
      twait { req_privs (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: reqp <handle> <token>                      "
	  "(login with a crypto token)\n";
      }
      break;
    }

  case CMD_ADD_TO_GROUP:
    {
      twait { add_to_group (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: add2g[roup] <group> <h1> <h2> .... "
	  "(add handles to group)\n";
      }
      break;
    }

  case CMD_NEW_GROUP:
    {
      twait { new_group (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: g[roup-alloc] <group-name> [<O> <I> <S>..]   "
	  "(make a new group)\n";
      }
      break;
    }

  case CMD_HELP:
    {
      display_help ();
      break;
    }
  default:
    handled = false;
    break;
  }
  cb->trigger (handled);
}

//-----------------------------------------------------------------------

tamed void
test_harness_t::handle_op (str s, cbv cb)
{
  tvars {
    vec<str> args;
    bool handled;
  }
  static rxx splrxx ("\\s+");
  if (split (&args, splrxx, s) && args.size () > 0) {
    twait { handle_op_std (args, mkevent (handled)); }
    if (!handled) {
      twait { handle_op (args, mkevent (handled)); }
    }
  } else {
    handled = true;
  }
  if (!handled)
    warn << "Unhandled command: " << s << "\n";

  cb->trigger ();
}

//-----------------------------------------------------------------------

void
test_harness_t::add_cmd (int i, const str &n, const char *desc)
{
  cmd_t c (i, n, desc);
  _commands.push_back (c);
  add_alias (i, n);
}

//-----------------------------------------------------------------------

void
test_harness_t::add_alias (int i, const str &n)
{
  cmd_pair_t cp (i, n);
  _command_lookup.push_back (cp);
}

//-----------------------------------------------------------------------

int 
test_harness_t::str2cmd (const str &arg)
{
  for (size_t i = 0; i < _command_lookup.size (); i++) {
    const str &cmd = _command_lookup[i]._name;
    if (arg.len () >= cmd.len () &&
	memcmp (arg.cstr (), cmd.cstr(), cmd.len ()) == 0)
      return _command_lookup[i]._id;
  }
  return -1;
}

//-----------------------------------------------------------------------

void
test_harness_t::cmd_init ()
{
  add_cmd (CMD_HELP, "help", "display help screen");
  add_cmd (CMD_NEW_HANDLE, "newh", "create a new handle");
  add_cmd (CMD_NEW_GROUP, "newg", "create a new group");
  add_cmd (CMD_ADD_TO_GROUP, "add2g", "add a handle to a group");
  add_cmd (CMD_REQ_PRIVS, "reqp", "request privileges");
}

//-----------------------------------------------------------------------

static void
output_spc (int n)
{
  if (n < 1) n = 1;
  mstr m (n + 1);
  memset (m.cstr (), ' ', n);
  m.cstr ()[n] = 0;
  m.setlen (n+1);
  aout << m;
}

//-----------------------------------------------------------------------

void
test_harness_t::display_help ()
{
  int coll = 20;
  aout << "------------- Available Commands -------------------\n";
  for (size_t i = 0; i < _commands.size (); i++) {
    aout << "  " << _commands[i]._name.cstr ();
    output_spc (coll - _commands[i]._name.len ());
    aout << _commands[i]._desc << "\n";
  }
}

//-----------------------------------------------------------------------

tamed void
test_harness_t::new_handle (const vec<str> &s, cbb cb)
{
  tvars {
    new_handle_arg_t arg;
    new_handle_res_t res;
    clnt_stat err;
    int procid;
    str procnm;
    str prog;
    bool ok (true);
    handle_id_t hid;
  }

  if (s.size () != 2 || !hid.from_str (s[1])) {
    ok = false;
  } else if ((hid.prefix ()) & (HANDLE_OPT_GROUP)) {
    warn << "Prefix bits 'g' not allowed....\n";
    ok = false;
  }

  if (ok) {
    hid.to_xdr (&arg);
    
    new_handle_proc (&procid, &procnm);
    prog = progname ();
    
    twait { conn ()->call (procid, &arg, &res, mkevent (err)); }
    if (err) {
      warn << "** In " << procnm << ": " << err << "\n";
    } else if (res.status != FLUME_OK) {
      warn << "** " << prog << " error in " << procnm << ": " 
	   << res.status << "\n";
    } else {
      handle_t h (*res.base_h);
      str h_str = h.to_str ();
      aout << "New handle: " << hid.name () << " -> " << h_str << "\n";
      insert_handle (hid, h);
    }
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
test_harness_t::serveloop (cbv cb)
{
  tvars {
    bool eof (false);
    str ln;
    int err;
    rendezvous_t<> cg (__FILE__, __LINE__);
  }

  while (!eof) {
    aout << "(rmtst) ";
    twait { fdcb (0, selread, mkevent ()); }
    twait { ain->readline (mkevent (ln, err)); }
    
    if (err) {
      warn << "Readline error: " << err << "\n";
      eof = true;
    } else if (!ln || ln == "." || ln == "quit") {
      eof = true;
    } else {
      twait { handle_op (ln, mkevent ()); }
    }
  }
  warn << "EOF encountered...\n";
  stop_serve ();

  while (cg.n_triggers_left ()) {
    twait (cg);
  }

  warn << "Exiting serve loop...\n";

  cb->trigger ();
}
  
//-----------------------------------------------------------------------

tamed void
test_harness_t::str2handle (const str &s, handle_t *h, cbb cb)
{
  tvars {
    bool ret;
  }

  if (h->from_str (s)) {
    ret = true;
  } else {
    twait { lookup_handle (s, h, mkevent (ret)); }
  }

  if (!ret) {
    warn << "Cannot convert to handle: " << s << "\n";
  }
  cb->trigger (ret);
}

//-----------------------------------------------------------------------


//
// Return values (via callback): -1, 0, 1:
//   -1 - is a label but didn't parse.
//   0  - is not a label
//   1  - is a label and parsed.
//
tamed void
test_harness_t::parse_label (const vec<str> &args, size_t *ip,
			     label_t *l, label_type_t *typ, cbi cb)
{
  tvars {
    int ret (0);
    handle_t h;
    bool ok;
    size_t i (*ip);
    bool cap (false);
  }

  static rxx x ("^(s|o|i):{", "i");
  if (i >= args.size ()  || !x.search (args[i])) {
    ret = 0;
  } else {
    switch (x[1][0]) {
    case 's': 
    case 'S':
      *typ = LABEL_S; 
      break;
    case 'i': 
    case 'I':
      *typ = LABEL_I; 
      break;
    case 'o': 
    case 'O':
      cap = true;
      *typ = LABEL_O; 
      break;
    default: 
      assert (false);
      break;
    }
    ret = 1;
    
    for (i++ ;i < args.size () && args[i] != "}" && ret == 1; i++) {
      twait { str2handle (args[i], &h, mkevent (ok)); }
      if (!ok) {
	ret = -1;
      } else if (!cap && h.is_capability ()) {
	warn << "Capability found in regular label: " << h.to_str () << "\n";
	ret = -1;
      } else if (cap && !h.is_capability ()) {
	warn << "Non-capability found in capability set: " << h.to_str () 
	     << "\n";
	ret = -1;
      } else {
	l->insert (h);
      }
    }
    if (i < args.size () && args[i] == "}") {
      i++;
    }
  }
  *ip = i;
  cb->trigger (ret);
}


//-----------------------------------------------------------------------   

tamed void
test_harness_t::parse_labels (const vec<str> &args, size_t *ip,
			      labelset_t *ls, cbi cb)
{
  tvars {
    int k;
    int rc (1);
    ptr<label_t> l;
    label_type_t typ;
  }

  for (k = 0; k < 3 && rc == 1; k++) {
    l = New refcounted<label_t> ();
    twait { parse_label (args, ip, l, &typ, mkevent (rc)); }
    if (rc == 1) {
      switch (typ) {
      case LABEL_S: ls->set_S (l) ; break ;
      case LABEL_O: ls->set_O (New refcounted<capset_t> (*l)) ; break ;
      case LABEL_I: ls->set_I (l) ; break ;
      default:
	warn ("Unexpected label type: %d\n", typ);
	rc = -1;
	break;
      }
    }
  }
  cb->trigger (rc);
}

//-----------------------------------------------------------------------   

void
test_harness_t::lookup_handle (const str &s, handle_t *h_out, cbb cb)
{
  handle_id_t name;

  cb->trigger ( name.from_str (s) && (lookup_handle (name, h_out)) );
}

//-----------------------------------------------------------------------

tamed void
test_harness_t::add_to_group (const vec<str> &v, cbb cb)
{
  tvars {
    bool ret (true), op_rc;
    handle_t g;
    size_t i (1);
    x_handlevec_t hv;
    handle_t h;
  }

  if (v.size () < 3) {
    ret = false;
  } else {
    twait { str2handle (v[i++], &g, mkevent (ret)); }
    if (ret && !g.is_group ()) {
      warn << "Expected a group; got non-group instead: " 
	   << g.to_str () << "\n";
      ret = false;
    }
  }
  
  for (/* i = i */ ; ret && i < v.size (); i++) {
    twait { str2handle (v[i], &h, mkevent (ret)); }
    if (ret) hv.push_back (h);
  }

  if (ret) {
    twait { add_to_group_op (g, &hv, mkevent (op_rc)); }
    if (op_rc)
      aout << "Successful group operation.\n";
  }

  cb->trigger (ret);
}

//-----------------------------------------------------------------------

tamed void
test_harness_t::req_privs (const vec<str> &v, cbb cb)
{
  tvars {
    req_privs_arg_t arg;
    req_privs_res_t res;
    clnt_stat err;
    bool ok;
    int procid;
    str procname, prog;
    handle_t h;
  }

  prog = progname ();
  req_privs_proc (&procid, &procname);
  
  if (v.size () != 3) {
    ok = false;
  } else {
    twait { str2handle (v[1], &h, mkevent (ok)); }
    if (!ok) {
      warn << "str2handle(" << v[1] << ") failed\n";
      ok = false;
    } else {
      arg.token.set_typ (PRIV_TOK_STR);
      *arg.token.strtok = v[2];
      arg.handle = h;
      twait { conn ()->call (procid, &arg, &res, mkevent (err)); }
      if (err) {
	warn << "In " << procname << ": " << err << "\n";
      } else if (res != FLUME_OK) {
	warn << prog << " returned error status: " << res << "\n";
      } else {
	aout << "Successful login for handle: " << h.to_str () << "\n";
      }
    }
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

void
test_harness_t::insert_handle (const handle_id_t &i, const handle_t &h)
{
  warn << "Insert : " << i.to_str () << " --> " << h.to_str () << "\n";
  _named_handles.insert (i, h.decap ());
  _handle_rev_lookup.insert (h.decap (), i);
}

//-----------------------------------------------------------------------

void
test_harness_t::insert_handle (handle_prefix_t p, const str &n, 
			       const handle_t &h)
{
  handle_id_t i = handle_id_t (p, n).decap ();
  warn << "Insert : " << i.to_str () << " --> " << h.to_str () << "\n";
  _named_handles.insert (i, h);
  _handle_rev_lookup.insert (h.decap (), i);
}

//-----------------------------------------------------------------------

bool
test_harness_t::lookup_handle (const handle_id_t &i, handle_t *r) const
{
  warn << "Lookup: " << i.to_str () << "\n";
  const handle_t *h = _named_handles[i.decap ()];
  if (h) {
    *r = handle_t (i.prefix (), h->basevalue ());
    return true;
  }
  return false;
}

//-----------------------------------------------------------------------

bool
test_harness_t::lookup_handle (handle_prefix_t p, const str &name, 
			       handle_t *r) const
{
  return lookup_handle (handle_id_t (p, name), r);
}

//-----------------------------------------------------------------------

tamed void
test_harness_t::new_group (const vec<str> &s, cbb cb)
{
  tvars {
    str name;
    new_group_res_t res;
    bool rc (true);
    size_t ip (1);
    labelset_t ls;
    int plrc;
  }

  if (s.size () < 2) {
    rc = false;
  } else {
    name = s[ip++];
    twait { parse_labels (s, &ip, &ls, mkevent (plrc)); }

    if (plrc < 0) {
      rc = false;
    } else {
      twait { new_group_op (name, ls, &res, mkevent (rc)); }
      if (rc) {
	handle_t g_h (res.group->base_h);
	str h1 = g_h.to_str ();
	aout << "New group: " << name << " -> (" << h1 << ")\n";
	insert_handle (HANDLE_OPT_GROUP|HANDLE_OPT_PERSISTENT, name, g_h);
      }
      // return TRUE either way
      rc = true;
    }
  }
  cb->trigger (rc);
}

//-----------------------------------------------------------------------
