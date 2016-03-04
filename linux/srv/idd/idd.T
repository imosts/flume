// -*-c++-*-

#include "async.h"
#include "crypt.h"
#include "arpc.h"
#include "idd.h"
#include "flume_idd_prot.h"
#include "pslave.h"
#include <mysqld_error.h>
#include "flume_prot.h"
#include "flume_srv_const.h"


TYPE2STRUCT( , flume_status_t);

namespace idd {

  //-----------------------------------------------------------------------

  my_ssrv_client_t::my_ssrv_client_t (my_ssrv_t *s, const rpc_program *const p,
				      ptr<axprt> x, const txa_prog_t *t)
    : ssrv_client_t (s, p, x, t), 
      _my_ssrv (s),
      _x (x), 
      _cli (aclnt::alloc (x, *p))
  {
    s->insert (this);
  }

  //-----------------------------------------------------------------------

  my_ssrv_client_t::~my_ssrv_client_t ()
  {
    _my_ssrv->remove (this);
  }

  //-----------------------------------------------------------------------

  void
  my_ssrv_t::insert (my_ssrv_client_t *c)
  {
    _my_list.insert_head (c);
  }

  //-----------------------------------------------------------------------

  void
  my_ssrv_t::remove (my_ssrv_client_t *c)
  {
    _my_list.remove (c);
  }

  //-----------------------------------------------------------------------

  void
  my_ssrv_t::accept (ptr<axprt_stream> x)
  {
    if (!x) {
      fatal << "listen port closed.\n";
    }
    vNew my_ssrv_client_t (this, prog, x, txa_prog);
    
  }

  //-----------------------------------------------------------------------

  tamed void
  my_ssrv_client_t::invalidate (const x_handle_t &x, cbv cb)
  {
    tvars {
      clnt_stat err;
    }
    twait {
      _cli->call (IDD_MEMBER_OF_CACHE_INVALIDATE, &x, NULL, mkevent (err));
    }
    if (err) {
      warn << "Error in invalidate cache RPC: " << err << "\n";
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------
  
  tamed void
  my_ssrv_t::invalidate (const x_handle_t &x, cbv cb)
  {
    tvars {
      my_ssrv_client_t *p, *n;
    }

    twait {
      for (p = _my_list.first; p; p = n) {
	n = _my_list.next (p);
	p->invalidate (x, mkevent ());
      }
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  tamed void
  my_ssrv_client_t::dispatch_T (svccb *sbp)
  {
    tvars {
      operate_on_group_arg_t *arg;
	  ptr<bool> df;
    }
	df = _destroyed;
    if (sbp && sbp->proc () == IDD_OPERATE_ON_GROUP) {
      arg = sbp->Xtmpl getarg<operate_on_group_arg_t> ();
      twait { _my_ssrv->invalidate (arg->group, mkevent ()); }
    }
	if (*df) {
	  warn << "ssrv_client_t destroyed before dispatch...\n";
	} else {
      ssrv_client_t::dispatch (sbp);
    }
  }

  //-----------------------------------------------------------------------

  thread_t::thread_t (mtd_thread_arg_t *a, idd_t *m) 
    : amysql_thread_t (a), _master_idd (m) {}

  //-----------------------------------------------------------------------

  void
  thread_t::handle_factory_init ()
  {
    _master_idd->handle_factory_init (this);
  }

  //-----------------------------------------------------------------------

  void
  idd_t::handle_factory_init (thread_t *t)
  {
    if (!_handle_factory_init && !_seed) {
      int64_t i = t->get_max_handle ();
      if (i > 0) {
	_handle_factory->set_max_id (i);
	warn << "Setting max handle id=" << i << "\n";
      }
      _handle_factory_init = true;
    }
  }

  //-----------------------------------------------------------------------

  bool
  thread_t::init ()
  {
    if (!mysql.connect (_master_idd->db_name (), 
			_master_idd->db_user (), 
			_master_idd->db_host (), 
			_master_idd->db_pw ())) {
      TWARN (mysql.error ());
      return false;
    }

    _new_handle_sth = PREP("INSERT INTO handles (handle,type,descr) "
			   "VALUES(?,?,?)");
    _new_nickname_sth = PREP("INSERT INTO nicknames (nickname,handle) "
			     "VALUES(?,?)");
    _add_to_group_sth = PREP("INSERT INTO group_members (handle, member) "
			     "VALUES(?,?)");
    _add_subgroup_sth = PREP("INSERT INTO subgroups (handle, subgroup) "
			     "VALUES(?,?)");
    _member_of_sth = PREP("SELECT COUNT(*) from group_members WHERE "
			  "member=? AND handle=?");
    _get_subgroups_sth = PREP("SELECT subgroup FROM subgroups WHERE handle=?");
    _lookup_frozen_label_sth = PREP ("SELECT frozen FROM freezer "
				     "WHERE thawed=?");
    _new_frozen_label_sth = PREP("INSERT INTO freezer (frozen,thawed) "
				 "VALUES(?,?)");
    _thaw_label_sth = PREP ("SELECT thawed FROM freezer WHERE frozen=?");
    _make_login_sth = PREP ("INSERT into auth_tokens"
			    "(token, handle, created,lasttouch, duration, "
			    "expired,fixed) "
			    "VALUES(?,?,NOW(),NOW(),?,0,?)");

    _req_privs_sth = PREP("SELECT id, duration, "
                          "UNIX_TIMESTAMP() - UNIX_TIMESTAMP(created), "
			  "UNIX_TIMESTAMP() - UNIX_TIMESTAMP(lasttouch), "
			  "fixed, expired "
                          "FROM auth_tokens "
			  "WHERE token=? AND handle=?");
    _touch_login_sth = PREP("UPDATE auth_tokens SET lasttouch=NOW() "
			    "WHERE id=?");
    _expire_login_sth = PREP("UPDATE auth_tokens SET expired=1 "
			     "WHERE id=?");
    _handle_desc_lookup_sth = PREP("SELECT COUNT(*) FROM handles WHERE "
				   "type=? AND descr=?");
    _handle_value_lookup_sth = PREP("SELECT COUNT(*) FROM handles WHERE "
				    "handle=?");
    _get_max_handle_sth = PREP ("SELECT MAX(handle) FROM handles");
    _next_debug_id_sth = PREP ("INSERT INTO debug_seq () VALUES()");
    _lookup_handle_sth = PREP ("SELECT handle FROM nicknames "
			       "WHERE nickname=?"); 
    _insert_group_labels_sth = PREP("INSERT INTO group_labels (handle,S,I,W) "
				 "VALUES(?,?,?,?)");
    _get_group_labels_sth = PREP("SELECT S,I,W FROM group_labels "
				 "WHERE handle=?");
    _insert_gea_sth = PREP("INSERT INTO ghetto_ea_map (hash,extattr) "
			   "VALUES(?,?)");
    _lookup_gea_sth = PREP("SELECT extattr FROM ghetto_ea_map WHERE hash=?");

    if (!_new_handle_sth ||
	!_new_nickname_sth || 
	!_add_to_group_sth ||
	!_add_subgroup_sth ||
	!_member_of_sth ||
	!_get_subgroups_sth ||
	!_lookup_frozen_label_sth ||
	!_new_frozen_label_sth ||
	!_thaw_label_sth ||
	!_make_login_sth ||
	!_req_privs_sth ||
	!_handle_desc_lookup_sth ||
	!_get_max_handle_sth ||
	!_handle_value_lookup_sth ||
	!_next_debug_id_sth || 
	!_lookup_handle_sth ||
	!_insert_group_labels_sth ||
	!_get_group_labels_sth ||
	!_touch_login_sth ||
	!_expire_login_sth ||
	!_insert_gea_sth || 
	!_lookup_gea_sth)
      return false;

    return true;
  }

  //-----------------------------------------------------------------------

  idd_t::idd_t () 
    : _n_threads (1), _port (default_port), _max_qlen (100),
      _handle_factory_init (false) {}

  //-----------------------------------------------------------------------

  idd_t::~idd_t () {}

  //-----------------------------------------------------------------------

  void 
  idd_t::launch (const str &cf)
  {
    if (!parseconfig (cf)) {
      warn << cf << ": config file contains errors.\n";
      exit (1);
    }

    if (_seed) {
      _handle_factory = New handle_factory_secure_t (_seed);
      warn << "Starting up in secure mode (with seed)\n";
    }  else {
      _handle_factory = New handle_factory_debug_t ();
      warn << "Starting up in insecure debug mode (without seed)\n";
    }

    //
    // 'ssrv_t' is a 'synchronous server' basetype, as defined in amt.h;
    // the idea is that it allows a server to do synchronous operations,
    // such as making MySQL queries through the mysql C interface. Calling
    // this constructor will go ahead and allocate a bunch of threads
    // with the wrapped in first argument. Those threads in turn should
    // connect to the DB and prepare and statements that they'll be 
    // executing.
    // 
    _idd_srv = New srv_t (wrap (&thread_t::alloc, this), flume_idd_prog_1,
			  MTD_PTHREADS, _n_threads, _max_qlen);

    //
    // This is the libasync side of the operation.  Allocate a TCP RPC server
    // on port '_port' and wait for incoming connections.  Handle all
    // incoming connections with the idd server object created above.
    //
    if (!pub_server (wrap (static_cast<my_ssrv_t *> (_idd_srv),
			   &my_ssrv_t::accept), _port)) {
      warn << "Cannot bind to port " << _port << "\n";
      exit (1);
    }
    warn << "process " << getpid () << " listening on port " << _port << "\n";

  }

  //-----------------------------------------------------------------------

  handle_t 
  idd_t::newh (thread_t *t, handle_prefix_t p, const str &n)
  {
    if (_seed) {
      return handle_factory ()->newh (p, n);
    } else {
      u_int64_t v = t->new_debug_id ();
      if (v > 0) 
	return handle_t (p, v);
    }
    return handle_t ();
  }

  //-----------------------------------------------------------------------

  u_int64_t
  thread_t::new_debug_id ()
  {
    u_int64_t r = 0;
    if (!_next_debug_id_sth->execute ()) {
      TWARN ("Debug ID insertion failed: " << _next_debug_id_sth->error ());
    } else {
      r = mysql.insert_id ();
    }
    return r;
  }

  //-----------------------------------------------------------------------

  u_int64_t
  thread_t::freeze_fresh_label (const str &s)
  {
    u_int64_t fid = 0;
    bool fail = false;
    u_int tries = 5;
    for (u_int i = 0; i < tries && !fail && fid == 0; i++) {
      handle_t h = _master_idd->newh (this, HANDLE_OPT_IDENTIFIER, NULL);
      if (!h) { 
	TWARN ("Failed to allocate a handle!\n");
	fail = true;
      } else if (_new_frozen_label_sth->execute (h.value (), s)) {
	fid = h.value ();
      } else if (!_new_frozen_label_sth->errnum () != ER_DUP_ENTRY) {
	TWARN ("Unexpected mysql error in freeze label: " 
	       << _new_frozen_label_sth->error ());
	fail = true;
      }
    }
    if (fail) {
      TWARN ("Giving up and failing on freeze operation");
    } else if (fid == 0) {
      TWARN ("Failed " << tries << " times to freeze a handle! "
	     "Something must be wrong.");
    }
    return fid;
  }

  //-----------------------------------------------------------------------

  bool
  thread_t::alloc_handle (handle_t *out, handle_prefix_t prefix, const str &n)
  {
    u_int tries = 5;
    for (u_int i = 0; i < tries; i++) {
      handle_t h = _master_idd->newh (this, prefix, n);
      if (!h) {
	TWARN ("Failed to allocate a handle!");
	return false;
      } else if (_new_handle_sth->execute (h.value (), prefix, n)) {
	*out = h;
	return true;
      } else if (_new_handle_sth->errnum () != ER_DUP_ENTRY) {
	TWARN ("Unexpected mysql error: " << _new_handle_sth->error ());
	return false;
      }
    }
    warn << "Failed " << tries << " times to allocate a handle! " 
	 << "Not very likely; there must be a bug...\n";
      
    return false;
  }

  //-----------------------------------------------------------------------

  flume_status_t 
  thread_t::insert_handle (const handle_t &in, const str &n)
  {
    flume_status_t s = FLUME_OK;
    bool rc = _new_handle_sth->execute (in.value (), in.prefix (), n);
    if (!rc) {
      if (_new_handle_sth->errnum () == ER_DUP_ENTRY) {
	s = FLUME_EEXIST;
      } else {
	TWARN ("Unexpected mysql error: " << _new_handle_sth->error ());
	s = FLUME_EIDD;
      }
    }
    return s;
  }

  //-----------------------------------------------------------------------

  void
  thread_t::handle_lookup_gea (svccb *sbp)
  {
    u_int64_t *arg = sbp->Xtmpl getarg<u_int64_t> ();
    ptr<lookup_gea_res_t> res = New refcounted<lookup_gea_res_t> ();
    str r;
    if (!_lookup_gea_sth->execute (*arg)) {
      res->set_status (FLUME_EIDD);
      TWARN("Lookup GEA failed: " << _lookup_gea_sth->error ());
    } else if (_lookup_gea_sth->fetch (&r) != ADB_OK) {
      res->set_status (FLUME_ENOENT);
      TWARN("Failed to find GEA for: " << *arg );
    } else {
      res->set_status (FLUME_OK);
      if (!str2xdr (*res->extattr, r)) {
	res->set_status (FLUME_EIDD);
	TWARN("Could not dearmor output from DB for GEA: " << *arg);
      }
    }
    reply (res);
  }

  //-----------------------------------------------------------------------

  void
  thread_t::handle_insert_gea (svccb *sbp)
  {
    insert_gea_arg_t *arg = sbp->Xtmpl getarg<insert_gea_arg_t> ();
    ptr<flume_status_t> st = New refcounted<flume_status_t> ();
    str dummy;

    if (!_lookup_gea_sth->execute (arg->hash)) {
      *st = FLUME_EIDD;
      TWARN("Error looking up in insert for " << arg->hash << ": " 
	    << _lookup_gea_sth->error ());
    } else if (_lookup_gea_sth->fetch (&dummy) == ADB_OK) {
      *st = FLUME_EEXIST; 
    } else {
      if (!_insert_gea_sth->execute (arg->hash, xdr2str (arg->extattr))) {
	*st = FLUME_EIDD;
	TWARN("Error inserting GEA " << arg->hash << ": " 
	      << _insert_gea_sth->error ());
      } else {
	*st = FLUME_OK;
      }
    }
    reply (st);
  }

  //-----------------------------------------------------------------------

  int64_t
  thread_t::get_max_handle ()
  {
    int64_t ret;
    if (!_get_max_handle_sth->execute ()) {
      ret = -1;
      TWARN ("Failed to get max handle: " << 
	     _get_max_handle_sth->error ());
    } else {
      int rc = _get_max_handle_sth->fetch (&ret);
      if (rc == ADB_NOT_FOUND) {
	TWARN ("handle table is empty");
	ret = 0;
      } else if (rc != ADB_OK) {
	TWARN ("Unexpected fetch result: " <<
	       _get_max_handle_sth->error ());
	ret = -1;
      }
    }
    return ret;
  }

  //-----------------------------------------------------------------------

  int
  thread_t::handle_desc_exists (handle_prefix_t prefx, const str &n)
  {
    int ret;
    if (!_handle_desc_lookup_sth->execute (prefx, n)) {
      ret = -1;
      TWARN ("Lookup handle by description failed: " << 
	     _handle_desc_lookup_sth->error ());
    } else if (_handle_desc_lookup_sth->fetch (&ret) != ADB_OK) {
      ret = -1;
      TWARN ("Fetch on handle lookup failed: " <<
	     _handle_desc_lookup_sth->error ());
    }
    return ret;
  }

  //-----------------------------------------------------------------------

  void
  thread_t::handle_new_nickname (svccb *sbp)
  {
    new_nickname_arg_t *arg = sbp->Xtmpl getarg<new_nickname_arg_t> ();
    ptr<flume_status_t> res = New refcounted<flume_status_t> ();

    if (_new_nickname_sth->execute (arg->nickname, arg->handle)) {
      *res = FLUME_OK;
    } else if (_new_nickname_sth->errnum () == ER_DUP_ENTRY) {
      *res = FLUME_EEXIST;
    } else {
      TWARN ("Unexpected error in new nickname: " 
	     << _new_nickname_sth->error ());
      *res = FLUME_EIDD;
    }
    reply (res);
  }

  //-----------------------------------------------------------------------

  int
  thread_t::handle_value_exists (handle_t h)
  {
    int ret;
    if (!_handle_value_lookup_sth->execute (h.value ())) {
      ret = -1;
      TWARN ("Lookup handle by value failed: " <<
	     _handle_value_lookup_sth->error ());
    } else if (_handle_value_lookup_sth->fetch (&ret) != ADB_OK) {
      ret = -1;
      TWARN ("Fetch on handle lookup failed: " <<
	     _handle_value_lookup_sth->error ());
    }
    return ret;
  }

  //-----------------------------------------------------------------------

  void
  thread_t::handle_new_handle (svccb *sbp)
  {
    // Call getarg as normal
    new_handle_arg_t *arg = sbp->Xtmpl getarg<new_handle_arg_t> ();

    ptr<new_handle_res_t> res = New refcounted<new_handle_res_t> ();
    if (!arg->name || arg->name.len () == 0) {
      TWARN ("Handle names must be defined; got a NULL/empty instead");
      res->set_status (FLUME_EINVAL);
    } else if (!is_persistent (arg->prefix)) {
      res->set_status (FLUME_EPERSISTENCE);
    } else {
      handle_t h;

      // Don't check if handle already exists; allow duplicate handle
      // descriptions.
      if (alloc_handle (&h, arg->prefix, arg->name)) {
	res->set_status (FLUME_OK);
	*res->base_h = h;
      } else {
	res->set_status (FLUME_EHANDLE);
      }
    }

    // Note that here we're calling amysql_thread_t::reply on a 
    // **refcounted** return value and not svccb::reply as
    // usual. Internally, the threaded library is having the main
    // thread (who runs in an async control loop) call svccb::reply
    // for you.
    reply (res);
  }

  //-----------------------------------------------------------------------

  void
  thread_t::handle_insert_handle (svccb *sbp)
  {
    insert_handle_arg_t *arg = sbp->Xtmpl getarg<insert_handle_arg_t> ();
    ptr<flume_status_t> res = New refcounted<flume_status_t> ();
    handle_t h = arg->handle;
    if (!arg->name || arg->name.len () == 0 || h.value () == 0) {
      *res = FLUME_EINVAL;
    } else if (!h.is_persistent ()) {
      *res = FLUME_EPERSISTENCE;
    } else {
      *res = insert_handle (h, arg->name);
    }
    reply (res);
  }

  //-----------------------------------------------------------------------
  
  bool
  thread_t::insert_group_labels (handle_t h, const frozen_labelset_t &ol)
  {
    if (!_insert_group_labels_sth->execute (h.value (), ol.S, ol.I, ol.O)) {
      TWARN ("Failed to insert group label data: " << 
	     _insert_group_labels_sth->error ());
      return false;
    }
    return true;
  }

  //-----------------------------------------------------------------------

  void
  thread_t::handle_new_group (svccb *sbp)
  {
    idd_new_group_arg_t *arg = sbp->Xtmpl getarg<idd_new_group_arg_t> ();
    ptr<new_group_res_t> res = New refcounted<new_group_res_t> ();
    handle_t h;
    
    // Groups have the "persistence" flag on for consistency, though
    // there is no such thing as a temporary group for now.
    handle_prefix_t typ = HANDLE_OPT_GROUP | HANDLE_OPT_PERSISTENT;
    
    if (!alloc_handle (&h, typ, arg->name)) {
      res->set_status (FLUME_EHANDLE);
    } else if (!insert_group_labels (h, arg->labels)) {
      res->set_status (FLUME_EINVAL);
    } else {
      res->set_status (FLUME_OK);
      res->group->base_h = h;
    }
    reply (res);
  }

  //-----------------------------------------------------------------------

  void
  thread_t::add_to_group (const handle_t &g, const x_handlevec_t &terms,
			  ptr<flume_status_t> res)
  {
    vec<handle_t> okh;
    *res = FLUME_OK;

    for (size_t i = 0; i < terms.size (); i++) {

      // strip off capability bits via "decap"
      handle_t h = (handle_t (terms[i])).decap ();

      if (!h.is_valid ()) {
	*res = FLUME_EHANDLE;
	TWARN ("Got invalid handle for group insertion: " << h.to_str ());
      } else if (h.is_persistent () && handle_value_exists (h) <= 0) {
	*res = FLUME_EHANDLE;
	TWARN ("Handle does not exist in DB: " << h.to_str ());
      }
    }
    
    if (*res != FLUME_OK) 
      return;

    for (size_t i = 0; i < terms.size (); i++) {

      handle_t h (terms[i]);

      if (!h.is_capability ()) {
	TWARN ("Can only add capabilities to groups; got handle instead: "
	       << h.to_str ());
      } else if (!h.is_persistent ()) {
	TWARN("Non-persistent handle skipped: " << h.to_str ());
      } else { 
	// Add groups to both the subgroups and the group table;
	// this is required in the case of adding groups to groups,
	// but wanting to select the group capability itself 
	// (not just scan the group).
	if (h.is_group ()) {
	  if (!_add_subgroup_sth->execute (g.value (), h.value ())) {
	    TWARN ("Subgroup addition error: " << _add_subgroup_sth->error ());
	    *res = FLUME_EIDD;
	  }
	}
	if (!_add_to_group_sth->execute (g.value (), h.value ())) {
	  TWARN ("Group addition error: " << _add_to_group_sth->error ());
	  *res = FLUME_EIDD;
	}
      }
    }
  }

  //-----------------------------------------------------------------------

  void
  thread_t::handle_operate_on_group (svccb *sbp)
  {
    operate_on_group_arg_t *arg = sbp->Xtmpl getarg<operate_on_group_arg_t> ();
    ptr<flume_status_t> res = New refcounted<flume_status_t> ();

    handle_t g = (handle_t (arg->group)).decap ();

    if (!g.is_group ()) {
      *res = FLUME_EMANAGEMENT;
      TWARN ("Require a group handle to act on a group; got '"
	     << g.to_str() << "' instead.");
    } else {
      switch (arg->op) {
      case GROUP_OPERATION_ADD:
	add_to_group (g, arg->terms, res);
	break;
      default:
	*res = FLUME_UNHANDLED;
	break;
      }
    }
    reply (res);
  }

  //-----------------------------------------------------------------------

  void
  thread_t::handle_member_of (svccb *sbp)
  {
    idd_member_of_arg_t *arg = sbp->Xtmpl getarg<idd_member_of_arg_t> ();
    ptr<idd_member_of_res_t> res = New refcounted<idd_member_of_res_t> ();

    capability_t c (arg->capability);
    handle_t g ((handle_t (arg->group)).decap ());

    if (!g.is_group ()) {
      TWARN("Expected a group handle; got instead: " << g.to_str ());
      res->set_ynm (YNM_NO);
    } else if (_member_of_sth->execute (c.value (), g.value ())) {
      int k;
      if (_member_of_sth->fetch (&k) != ADB_OK) {
	TWARN ("No rows returned from MemberOf query; weird.\n");
      } else if (k == 1) {
	res->set_ynm (YNM_YES);
      } else if (k == 0) {
	bool maybe = false;
	if (_get_subgroups_sth->execute (g.value ())) {
	  res->set_ynm (YNM_MAYBE);
	  u_int64_t sg;
	  while (_get_subgroups_sth->fetch (&sg) == ADB_OK) {
	    res->subgroups->push_back (sg);
	    maybe = true;
	  }
	  if (!maybe)
	    res->set_ynm (YNM_NO);
	} else {
	  TWARN ("Error in GetSubgroups: " << _get_subgroups_sth->error ());
	}
      } else {
	TWARN ("Unexpected result from MemberOf query: " << c);
      }
    } else {
      TWARN ("MemberOf query error: " << _member_of_sth->error ());
    }
    reply (res);
  }

  //-----------------------------------------------------------------------

  void
  thread_t::handle_freeze_label (svccb *sbp)
  {
    x_label_t *arg = sbp->Xtmpl getarg<x_label_t> ();
    ptr<freeze_label_res_t> res = 
      New refcounted<freeze_label_res_t> (FLUME_OK);

    str s = label_t::freeze (arg);

    for (size_t i = 0; i < arg->size () && res->status == FLUME_OK; i++) {
      handle_t h = handle_t ((*arg)[i]).decap ();
      if (!h.is_persistent ()) {
	TWARN ("Can't freeze non-persistent handle: " << h.to_str ());
	res->set_status (FLUME_EPERSISTENCE);
      } else if (handle_value_exists (h) <= 0) {
	TWARN ("Invalid handle given (not in DB): " << h.to_str ());
	res->set_status (FLUME_EPERSISTENCE);
      }
    }

    // The empty label is frozen to "0" by convention/default.
    if (arg->size () == 0) {
      *res->frozen = handle_t::frozen_empty ();
    } else if (res->status == FLUME_OK) {

      u_int64_t fid = 0;
      
      if (_lookup_frozen_label_sth->execute (s)) {
	adb_status_t rc = _lookup_frozen_label_sth->fetch (&fid);
	if (rc == ADB_NOT_FOUND) {
	  fid = freeze_fresh_label (s);
	} else if (rc != ADB_OK) {
	  TWARN ("Error in freezer lookup: " << 
		 _lookup_frozen_label_sth->error ());
	}
      }
      if (fid) {
	*res->frozen = fid;
      } else {
	res->set_status (FLUME_EIDD);
      }
    }
    reply (res);
  }

  //-----------------------------------------------------------------------

  void
  thread_t::handle_thaw_label (svccb *sbp)
  {
    frozen_label_t *arg = sbp->Xtmpl getarg<frozen_label_t> ();
    ptr<thaw_label_res_t> res = New refcounted<thaw_label_res_t> ();

    if (*arg == handle_t::frozen_empty ()) {
      // Empty set
      res->set_status (FLUME_OK);
      res->thawed->setsize (0);
    } else if (_thaw_label_sth->execute (*arg)) {
      str t;
      adb_status_t s = _thaw_label_sth->fetch (&t);
      if (s == ADB_NOT_FOUND) {
	res->set_status (FLUME_EPERSISTENCE);
      } else if (s != ADB_OK) {
	res->set_status (FLUME_EIDD);
	TWARN ("Thaw label query error: " << _thaw_label_sth->error ());
      } else {
	label_t l (t);
	res->set_status (FLUME_OK);
	l.to_xdr (res->thawed);
      }
    } else {
      res->set_status (FLUME_EIDD);
      TWARN ("Thaw label query error: " << _thaw_label_sth->error ());
    }
    reply (res);
  }

  //-----------------------------------------------------------------------

  void
  thread_t::handle_lookup_by_nickname (svccb *sbp)
  {
    nickname_t *arg = sbp->Xtmpl getarg<nickname_t> ();
    ptr<new_handle_res_t> res = New refcounted<new_handle_res_t> ();

    if (_lookup_handle_sth->execute (*arg)) {
      u_int64_t h;
      adb_status_t rc = _lookup_handle_sth->fetch (&h);
      if (rc == ADB_OK) {
	res->set_status (FLUME_OK);
	*res->base_h = h;
      } else {
	TWARN("Handle not found: " << *arg);
	res->set_status (FLUME_ENOENT);
      }
    } else {
      TWARN("Handle lookup error: " << _lookup_handle_sth->error ());
	  res->set_status (FLUME_EIDD);
    }
    reply (res);
  }

  //-----------------------------------------------------------------------

  void
  thread_t::handle_make_login (svccb *sbp)
  {
    idd_make_login_arg_t *arg = sbp->Xtmpl getarg<idd_make_login_arg_t> ();
    ptr<flume_status_t> res = New refcounted<flume_status_t> ();

    priv_tok_bin_t btok;
    tok2bin (arg->token, &btok);

    handle_t h (arg->larg.handle);
    if (!h.is_persistent ()) {
      *res = FLUME_EPERSISTENCE;
    } else if (!_make_login_sth->execute (btok, arg->larg.handle, 
					  arg->larg.duration, 
					  arg->larg.fixed)) {
      TWARN ("Make login failed: " << _make_login_sth->error ());
      *res = FLUME_EIDD;
    } else {
      *res = FLUME_OK;
    }
    reply (res);
  }

  //-----------------------------------------------------------------------

  void
  thread_t::handle_req_privs (svccb *sbp)
  {
    req_privs_arg_t *arg = sbp->Xtmpl getarg<req_privs_arg_t> ();
    ptr<req_privs_res_t> res = New refcounted<req_privs_res_t> (FLUME_EIDD);

    priv_tok_bin_t btok;
    tok2bin (arg->token, &btok);

    if (_req_privs_sth->execute (btok, arg->handle)) {
      u_int d, diff1, diff2, id;
      bool fixd, expired;
      adb_status_t s = 
	_req_privs_sth->fetch (&id, &d, &diff1, &diff2, &fixd, &expired);

      if (s == ADB_NOT_FOUND) {
	*res = FLUME_ENOENT;
      } else if (s != ADB_OK) {
	TWARN ("In login: " << _req_privs_sth->error ());
      } else if (d == 0 || (fixd && diff1 <= d) || (!fixd && diff2 < d)) {
	_touch_login_sth->execute (id);
	*res = FLUME_OK;
      } else {
	_expire_login_sth->execute (id);
	*res = FLUME_EEXPIRED;
      }
    } else {
      TWARN ("In login excute: " << _req_privs_sth->error ());
    }
    reply (res);
  }
  
  //-----------------------------------------------------------------------

  void
  thread_t::handle_get_group_labels (svccb *sbp)
  {
    x_handle_t *arg = sbp->Xtmpl getarg<x_handle_t> ();
    ptr<idd_get_group_labels_res_t> res = 
      New refcounted<idd_get_group_labels_res_t> (FLUME_OK);

    handle_t h = handle_t (*arg).decap ();

    if (_get_group_labels_sth->execute (h.value ())) {
      adb_status_t s = 
	_get_group_labels_sth->fetch (&res->labels->S, &res->labels->I,
				      &res->labels->O);
      if (s == ADB_NOT_FOUND) { 
	res->set_status (FLUME_ENOENT);
      } else if (s != ADB_OK) {
	TWARN ("In get group labels: " << _get_group_labels_sth->error ());
	res->set_status (FLUME_EIDD);
      }

    } else {
      res->set_status (FLUME_EIDD);
    }
    reply (res);
  }

  //-----------------------------------------------------------------------

  void
  thread_t::dispatch (svccb *sbp)
  {
    /*
     * Debug handles now generated via insert IDs
     *
     * handle_factory_init ();
     */

    switch (sbp->proc ()) {
    case IDD_NULL:
      replynull ();
      break;
    case IDD_OPERATE_ON_GROUP:
      handle_operate_on_group (sbp);
      break;
    case IDD_NEW_HANDLE:
      handle_new_handle (sbp);
      break;
    case IDD_NEW_GROUP:
      handle_new_group (sbp);
      break;
    case IDD_MEMBER_OF:
      handle_member_of (sbp);
      break;
    case IDD_FREEZE_LABEL:
      handle_freeze_label (sbp);
      break;
    case IDD_THAW_LABEL:
      handle_thaw_label (sbp);
      break;
    case IDD_REQ_PRIVS:
      handle_req_privs (sbp);
      break;
    case IDD_MAKE_LOGIN:
      handle_make_login (sbp);
      break;
    case IDD_LOOKUP_HANDLE_BY_NICKNAME:
      handle_lookup_by_nickname (sbp);
      break;
    case IDD_GET_GROUP_LABELS:
      handle_get_group_labels (sbp);
      break;
    case IDD_NEW_NICKNAME:
      handle_new_nickname (sbp);
      break;
    case IDD_INSERT_GEA:
      handle_insert_gea (sbp);
      break;
    case IDD_LOOKUP_GEA:
      handle_lookup_gea (sbp);
      break;
    case IDD_INSERT_HANDLE:
      handle_insert_handle (sbp);
      break;
    default:
      TWARN ("rejecting unhandled request...");
      reject ();
      break;
    }
  }

  //-----------------------------------------------------------------------

  bool
  idd_t::parseconfig (const str &cf)
  {
    _config_file = cf;
    conftab ct;
    bool ret;
    
    ct.add ("DbHost", &_db_host)
      .add ("DbUser", &_db_user)
      .add ("DbPassword", &_db_pw)
      .add ("DbName", &_db_name)
      .add ("NumThreads", &_n_threads, 0, 1000)
      .add ("Port", &_port, 0, 0x10000)
      .add ("Seed", &_seed)
      .add ("MaxQLen", &_max_qlen, 0, INT_MAX);

    if (!ct.run (cf, CONFTAB_VERBOSE)) {
      warn << cf << ": bailing out due to parse errors\n";
      ret = false;
    } else {
      ret = true;

#define CHECK(f,d) \
if (!f) { warn << cf << ": No '" d "' specified.\n"; ret = false; }

    CHECK (_db_host, "DbHost");
    CHECK (_db_user, "DbUser");
    CHECK (_db_pw,   "DbPassword");
    CHECK (_db_name, "DbName");

#undef CHECK

    }
    return ret;

  }

};
