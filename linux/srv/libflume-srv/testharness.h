
// -*-c++-*-
/* $Id: tame.h 2077 2006-07-07 18:24:23Z max $ */

#ifndef _LIBFLUME_TESTHARNESS_H_
#define _LIBFLUME_TESTHARNESS_H_

#include "async.h"
#include "tame.h"
#include "aios.h"
#include "pslave.h"
#include "flume_ev_labels.h"
#include "list.h"
#include "ihash.h"

class qcb_t {
public:
  qcb_t (cbv c, int f) : _cb (c), _fd (f) {}
  void call () { _cb->trigger (); }
  list_entry<qcb_t> _lnk;
  ihash_entry<qcb_t> _hlnk;

  cbv _cb;
  int _fd;
};

class test_harness_t {
public:
  virtual ~test_harness_t () {}
  test_harness_t () {}

protected:
  void new_handle (const vec<str> &s, cbb cb, CLOSURE);
  void lookup_handle (const str &s, handle_t *h, cbb cb);
  void str2handle (const str &s, handle_t *h, cbb cb, CLOSURE);
  void req_privs (const vec<str> &s, cbb cb, CLOSURE);

  void parse_label (const vec<str> &args, size_t *index,
		    label_t *l, label_type_t *t, cbi cb, CLOSURE);

  void parse_labels (const vec<str> &args, size_t *index,
		     labelset_t *ls, cbi cb, CLOSURE);

  void add_to_group (const vec<str> &s, cbb cb, CLOSURE);
  void new_group (const vec<str> &s, cbb cb, CLOSURE);
  
  virtual void handle_op (const vec<str> &s, cbb cb) = 0;
  void handle_op_std (const vec<str> &s, cbb, CLOSURE);

  void cmd_init ();

  void handle_op (str s, cbv cb, CLOSURE);
  
  void serveloop (cbv cb, CLOSURE);

  virtual helper_t *conn () = 0;
  virtual void new_handle_proc (int *i, str *n) const = 0;
  virtual void lookup_proc (int *i, str *n) const = 0;
  virtual void req_privs_proc (int *i, str *n) const = 0;
  virtual str progname () const = 0;
  virtual void new_group_op (const str &n, const labelset_t &ls, 
			     new_group_res_t *res, cbb cb) = 0;
  virtual void add_to_group_op (handle_t g, const x_handlevec_t *x, 
				cbb cb) = 0;

  virtual void stop_serve () {}

  void insert_handle (const handle_id_t &i, const handle_t &h);
  void insert_handle (handle_prefix_t p, const str &name, const handle_t &h);
  bool lookup_handle (const handle_id_t &i, handle_t *r) const;
  bool lookup_handle (handle_prefix_t p, const str &name, handle_t *r) const;

  qhash<handle_id_t, handle_t> _named_handles;
  qhash<handle_t, handle_id_t> _handle_rev_lookup;

  struct cmd_pair_t {
    cmd_pair_t (int id, const str &n) : _id (id), _name (n) {}
    int _id;
    const str _name;
  };

  struct cmd_t {
    cmd_t (int id, const str &n, const char *d)
      : _id (id), _name (n), _desc (d) {}

    int _id;
    const str _name;
    const char *_desc;
  };

  int str2cmd (const str &arg);
  void add_cmd (int id, const str &cmd, const char *desc);
  void add_alias (int it, const str &cmd);
  void display_help ();

  vec<cmd_pair_t> _command_lookup;
  vec<cmd_t> _commands;
  
};

enum { CMD_NEW_HANDLE = 1,
       CMD_NEW_GROUP = 2,
       CMD_ADD_TO_GROUP = 3,
       CMD_REQ_PRIVS = 5,
       CMD_HELP = 6 };

#define PROC(islot, sslot, p) do { *sslot = #p; *islot = p; } while (0)

#endif /* _LIBFLUME_TESTHARNESS_H_ */
