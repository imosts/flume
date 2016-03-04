
// -*-c++-*-
/* $Id: tame.h 2077 2006-07-07 18:24:23Z max $ */

#include "flume_idd_prot.h"
#include "async.h"
#include "flume.h"
#include "tame.h"
#include "arpc.h"
#include "pslave.h"
#include "aios.h"
#include "iddutil.h"
#include "rxx.h"
#include "parseopt.h"
#include "testharness.h"
#include "handlemgr.h"

enum {
  MEMBER_OF = 201,
  FREEZE_LABEL = 202,
  THAW_LABEL = 203,
};


class idd_test_t : public test_harness_t {
public:
  idd_test_t () : test_harness_t (), _idd (NULL) {}

  void init (const vec<str> &v, cbb cb, CLOSURE);
  void run (cbv cb, CLOSURE);
  void handle_op (const vec<str> &s, cbb cb) { handle_op_T (s, cb); }
  void member_of (const vec<str> &v, cbb cb, CLOSURE);
  void freeze (const vec<str> &v, cbb cb, CLOSURE);
  void thaw (const str &s, cbb cb, CLOSURE);
  void cmd_init ();

protected:
  helper_t *conn () { return _idd->conn (); }
  void new_handle_proc (int *i, str *n) const { PROC(i, n, IDD_NEW_HANDLE); }
  void lookup_proc (int *i, str *n) const 
  { PROC(i, n, IDD_LOOKUP_HANDLE_BY_NICKNAME); }

  void make_login_proc (int *i, str *n) const { PROC(i, n, IDD_MAKE_LOGIN); }
  void req_privs_proc (int *i, str *n) const { PROC(i, n, IDD_REQ_PRIVS); }
  void add_to_group_T (const vec<str> &v, cbb cb, CLOSURE) ;
  void new_group_op_T (const str &name, const labelset_t &ls,
		       new_group_res_t *res, cbb cb, CLOSURE);

  void add_to_group_op (handle_t m, const x_handlevec_t *x, cbb cb)
  { add_to_group_op_T (m, x, cb); }
  void new_group_op (const str &name, const labelset_t &ls, 
		     new_group_res_t *res, cbb cb)
  { new_group_op_T (name, ls, res, cb); }

  str progname () const { return "idd"; }

private:
  void add_to_group_op_T (handle_t m, const x_handlevec_t *x, cbb cb, CLOSURE);
  void handle_op_T (const vec<str> &s, cbb cb, CLOSURE);
  idd::server_handle_t *_idd;
  ptr<mutating_perproc_handlemgr_t> _pphmgr;
};


//------------------------------------------------------------------------

tamed void 
idd_test_t::init (const vec<str> &v, cbb cb)
{
  tvars {
    bool rc;
    idd::cfg_t cfg;
  }
  
  rc = cfg.from_argv (v);
  if (rc) {
    twait { cfg.alloc_and_start (&_idd, mkevent (rc)); }
  }

  if (rc) {
    global_idd_init (_idd, NULL);
    _pphmgr = mhmgr_t::alloc (New refcounted<labelset_t> (), NULL);
  } else {
    warn << "Cannot connect to given IDD\n";
  }

  cb->trigger (rc);
}

//-----------------------------------------------------------------------

static void
output_ynm (const vec<handle_t> &v, ynm_t ynm)
{
  aout << v[0].to_str () << " ";
  switch (ynm) {
  case YNM_NO:
    aout << "is NOT";
    break;
  case YNM_YES:
    aout << "IS";
    break;
  case YNM_MAYBE:
    aout << "might be";
    break;
  default:
    assert (false);
    break;
  }
  aout << " a member of " << v[1].to_str ();
}

//-----------------------------------------------------------------------

tamed void
idd_test_t::member_of (const vec<str> &v, cbb cb)
{
  tvars {
    idd_member_of_arg_t arg;
    idd_member_of_res_t res;
    clnt_stat err;
    vec<handle_t> h;
    size_t i;
    bool ret (true);
    bool ok;
  }
  h.setsize (2);
  for (i = 0; i < 2; i++) {
    twait { str2handle (v[i+1], &h[i], mkevent (ok)); }
    if (!ok) {
      ret = false;
    }
  }
  if (ret) {
    arg.capability = h[0];
    arg.group = h[1];
    twait { _idd->conn ()->call (IDD_MEMBER_OF, &arg, &res, mkevent (err)); }
    if (err) {
      warn << "** In IDD_MEMBER_OF: " << err << "\n";
    } else {
      output_ynm (h, res.ynm);
      if (res.ynm == YNM_MAYBE) {
	aout << "; try subgroups:\n";
	for (i = 0; i < res.subgroups->size (); i++) {
	  handle_t h ((*res.subgroups)[i]);
	  aout << "\t" << h.to_str () << "\n";
	}
      } else {
	aout << "\n";
      }
    }
  }
  cb->trigger (ret);
}

//-----------------------------------------------------------------------

tamed void
idd_test_t::thaw (const str &s, cbb cb)
{
  tvars {
    bool ret (true);
    handle_t h;
    frozen_label_t arg;
    thaw_label_res_t res;
    clnt_stat err;
    bool ok;
  }
  
  twait { str2handle (s, &h, mkevent (ok)); }
  if (!ok) {
    ret = false;
  } else {
    arg = h;
    twait { _idd->conn ()->call (IDD_THAW_LABEL, &arg, &res, mkevent (err)); }
    if (err) {
      warn << "** In IDD_THAW_LABEL: " << err << "\n";
    } else if (res.status != FLUME_OK) {
      warn << "** Error in IDD_THAW_LABEL: " << res.status << "\n";
    } else {
      label_t l (*res.thawed);
      aout << "Label returned: " << l.to_str () << "\n";
    }
  }
  cb->trigger (ret);
}

//-----------------------------------------------------------------------


//-----------------------------------------------------------------------

tamed void
idd_test_t::freeze (const vec<str> &v, cbb cb)
{
  tvars {
    x_label_t arg;
    freeze_label_res_t res;
    clnt_stat err;
    bool ok;
    bool ret (true);
    size_t i;
    handle_t h;
  }
  for (i = 1; i < v.size (); i++) {
    twait { str2handle (v[i], &h, mkevent (ok)); }
    if (!ok) {
      ret = false;
    } else {
      arg.push_back (h);
    }
  }
  if (ret) {
    twait { 
      _idd->conn ()->call (IDD_FREEZE_LABEL, &arg, &res, mkevent (err)); 
    }
    if (err) {
      warn << "** In IDD_FREEZE_LABEL: " << err << "\n";
    } else if (res.status != FLUME_OK) {
      warn << "** IDD error in FREEZE_LABEL: " << res.status << "\n";
    } else {
      handle_t h (*res.frozen);
      aout << "Frozen label: " << h.to_str () << "\n";
    }
  }
  cb->trigger (ret);
}

//-----------------------------------------------------------------------

static void
usage ()
{
  warnx << "usage: " << progname << " <hostname>:<port>\n";
  exit (2);
}

//-----------------------------------------------------------------------

tamed void
idd_test_t::add_to_group_op_T (handle_t g, const x_handlevec_t *x, cbb cb)
{
  tvars {
    flume_status_t stat;
  }
  twait { _pphmgr->group_union_in_unsafe (g, x, mkevent (stat)); }
  cb->trigger (stat == FLUME_OK);
}

//-----------------------------------------------------------------------

tamed void
idd_test_t::new_group_op_T (const str &name, const labelset_t &ls,
			    new_group_res_t *res, cbb cb)
{
  tvars {
    bool ok (true);
  }
  
  twait { _pphmgr->new_group_unsafe (name, ls, res, mkevent ()); }
  if (res->status != FLUME_OK) {
    warn << "** idd error in new_group_unsafe: " 
	 << res->status << "\n";
    ok = false;
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
idd_test_t::handle_op_T (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok;
    bool handled (true);
    int a;
  }

  a = str2cmd (args[0]);

  switch (a) {
    
  case MEMBER_OF:
    {
      if (args.size () == 3) {
	twait { member_of (args, mkevent (ok)); }
      } else {
	ok = false;
      }
      if (!ok) {
	warn << "usage: m[ember-of] <handle> <group> ...  "
	  "(query membership)\n";
      }
      break;
    }
    
  case FREEZE_LABEL:
    {
      if (args.size () >= 2) {
	twait { freeze (args, mkevent (ok)); }
      } else {
	ok = false;
      }
      if (!ok) {
	warn << "usage: f[reeze] <h1> <h2> ...           "
	  "(freeze a label)\n";
      }
      break;
    }
    
  case THAW_LABEL:
    {
      if (args.size () == 2) {
	twait { thaw (args[1], mkevent (ok)); }
      } else {
	ok = false;
      } 
      if (!ok) {
	warn << "usage: t[haw] <frozen>                 "
	  "(thaw a label)\n";
      }
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
idd_test_t::run (cbv cb)
{
  // Should return on an EOF
  twait { serveloop (mkevent ()); }
  cb->trigger ();
}

//-----------------------------------------------------------------------

void
idd_test_t::cmd_init ()
{
  test_harness_t::cmd_init ();
  add_cmd (MEMBER_OF, "memof", "test if a handle is a member of a group");
  add_cmd (FREEZE_LABEL, "freeze", "freeze a label to a persistent form");
  add_cmd (THAW_LABEL, "thaw", "thaw a lable from a persistent form");
}

//-----------------------------------------------------------------------

tamed static void 
main2 (int argc, char **argv)
{
  tvars {
    idd_test_t *t;
    vec<str> argv_s;
    bool ok;
  }

  if (argc != 2)
    usage ();

  t = New idd_test_t ();
  t->cmd_init ();

  for (int i = 0; i < argc; i++) {
    argv_s.push_back (argv[i]);
  }
  
  twait { t->init (argv_s, mkevent (ok)); }
  if (!ok)
    usage ();


  twait { t->run (mkevent ()); }
  exit (0);
}

//-----------------------------------------------------------------------

int
main (int argc, char *argv[])
{
  setprogname (argv[0]);
  main2 (argc, argv);
  amain ();
  return 0;
}
