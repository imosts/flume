// -*-c++-*-
#ifndef _IDD_IDD_H_
#define _IDD_IDD_H_ 1

#include "flume.h"
#include "arpc.h"
#include "flume_srv_const.h"
#include "unixutil.h"
#include "amt.h"
#include "amysql.h"
#include "flume_idd_prot.h"
#include "mystmt.h"
#include "flume_ev_labels.h"
#include "tame.h"

namespace idd {

  //-----------------------------------------------------------------------

  class my_ssrv_t;

  class my_ssrv_client_t : public ::ssrv_client_t {
  public:
    my_ssrv_client_t (my_ssrv_t *s, const rpc_program *const p,
		      ptr<axprt> x, const txa_prog_t *t);
    ~my_ssrv_client_t ();
    void dispatch (svccb *sbp) { dispatch_T (sbp); }
    void invalidate (const x_handle_t &x, cbv cb, CLOSURE);

    list_entry<my_ssrv_client_t> _lnk;
  protected:
    my_ssrv_t *_my_ssrv;
    ptr<axprt> _x;
    ptr<aclnt> _cli;
  private:
    void dispatch_T (svccb *sbp, CLOSURE);

  };

  //-----------------------------------------------------------------------

  class my_ssrv_t : public ssrv_t {
  public:
    my_ssrv_t (newthrcb_t c, const rpc_program &p, 
	       mtd_thread_typ_t typ = MTD_PTH, 
	       int nthr = MTD_NTHREADS, int mq = MTD_MAXQ, 
	       const txa_prog_t *tx = NULL) 
      : ssrv_t (c, p, typ, nthr, mq, tx) {}

    void accept (ptr<axprt_stream> x);
    void insert (my_ssrv_client_t *cli);
    void remove (my_ssrv_client_t *cli);
    void invalidate (const x_handle_t &h, cbv cb, CLOSURE);
    
  private:
    list<my_ssrv_client_t, &my_ssrv_client_t::_lnk> _my_list;
  };

  //-----------------------------------------------------------------------

  class idd_t;
  class thread_t : public amysql_thread_t {
  public:
    thread_t (mtd_thread_arg_t *a, idd_t *i);
    bool init ();
    void dispatch (svccb *sbp);
    static mtd_thread_t *alloc (idd_t *i, mtd_thread_arg_t *arg)
    {
      return New thread_t (arg, i);
    }
    int64_t get_max_handle ();
    u_int64_t new_debug_id ();

  protected:
    void handle_new_handle (svccb *sbp);
    void handle_new_group (svccb *sbp);
    void handle_member_of (svccb *sbp);
    void handle_freeze_label (svccb *sbp);
    void handle_thaw_label (svccb *sbp);
    void handle_make_login (svccb *sbp);
    void handle_req_privs (svccb *sbp);
    void handle_lookup_by_nickname (svccb *sbp);
    void handle_new_nickname (svccb *sbp);
    void handle_get_group_labels (svccb *sbp);
    void handle_insert_gea (svccb *sbp);
    void handle_lookup_gea (svccb  *sbp);
    void handle_insert_handle (svccb *sbp);

    void handle_factory_init ();

  private:
    bool alloc_handle (handle_t *out, handle_prefix_t prefix, const str &name);
    flume_status_t insert_handle (const handle_t &in, const str &n);
    void handle_operate_on_group (svccb *sbp);
    void add_to_group (const handle_t &g, 
		       const x_handlevec_t &terms,
		       ptr<flume_status_t> res);
    int handle_desc_exists (handle_prefix_t prfx, const str &d);
    int handle_value_exists (handle_t h);
    u_int64_t freeze_fresh_label (const str &s);
    bool insert_group_labels (handle_t h, const frozen_labelset_t &ol);

  private:
    idd_t *_master_idd;
    sth_t _new_handle_sth, 
      _add_to_group_sth, 
      _add_subgroup_sth,
      _member_of_sth, 
      _get_subgroups_sth,
      _lookup_frozen_label_sth,
      _new_frozen_label_sth,
      _thaw_label_sth,
      _make_login_sth,
      _req_privs_sth,
      _handle_desc_lookup_sth,
      _handle_value_lookup_sth,
      _get_max_handle_sth,
      _next_debug_id_sth,
      _lookup_handle_sth,
      _insert_group_labels_sth,
      _get_group_labels_sth,
      _new_nickname_sth,
      _touch_login_sth,
      _expire_login_sth,
      _insert_gea_sth,
      _lookup_gea_sth;
  };

  class srv_t : public my_ssrv_t {
  public:
    srv_t (newthrcb_t c, const rpc_program &p,
	   mtd_thread_typ_t typ, int nthr, int mq)
      : my_ssrv_t (c, p, typ, nthr, mq) {}
    
  };

  class idd_t {
  public:
    idd_t ();
    ~idd_t ();
    void launch (const str &f);

    const str &db_name () const { return _db_name; }
    const str &db_user () const { return _db_user; }
    const str &db_pw () const { return _db_pw; }
    const str &db_host () const { return _db_host; }

    handle_factory_t * handle_factory () { return _handle_factory ; }
    void handle_factory_init (thread_t *t);

    handle_t newh (thread_t *t, handle_prefix_t p, const str &n);

  private:
    srv_t *_idd_srv;

    bool parseconfig (const str &cf);
    str _config_file;
    str _db_host, _db_user, _db_pw, _db_name;
    str _seed;
    u_int _n_threads;
    int _port;
    u_int _max_qlen;
    handle_factory_t *_handle_factory;
    bool _handle_factory_init ;
  };

};




#endif /* _IDD_IDD_H_ */
