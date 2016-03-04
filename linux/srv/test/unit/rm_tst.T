
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
#include "flume_prot.h"
#include "tame_autocb.h"
#include "tame_io.h"
#include "asyncutil.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

enum { 
  CMD_APPEND_TO_FILE = 101,
  CMD_SET_LABEL = 102,
  CMD_GET_LABEL = 103,
  CMD_CREATE_FILE = 104,
  CMD_MKDIR = 105,
  CMD_SYNCHRONOUS_WRITE = 106,
  CMD_ASYNCHRONOUS_WRITE = 107,
  CMD_CLOSE_FILE = 108,
  CMD_READ_FILE = 109,
  CMD_STAT_FILE = 110,
  CMD_MAKE_UNIXSOCKET = 111,
  CMD_CONNECT_UNIXSOCKET = 112,
  CMD_MAKE_SOCKETPAIR = 113,
  CMD_CLAIM_SOCKETPAIR = 114,
  CMD_CHDIR = 115,
  CMD_UNLINK_FILE = 116,
  CMD_LINK_FILE = 117,
  CMD_RENAME = 118,
  CMD_SYMLINK = 119,
  CMD_FAKE_CONFINEMENT = 120,
  CMD_GET_CONFINED = 121,
  CMD_GETCWD = 122,
  CMD_FREEZE_LABEL = 123,
  CMD_MAKE_NICKNAME = 124,
  CMD_LOOKUP_BY_NICKNAME = 125,
  CMD_MAKE_LOGIN = 126
};

//-----------------------------------------------------------------------

class rm_test_t;
class sockfd_t;

//-----------------------------------------------------------------------


class fd_t : public virtual refcount {
public:
  fd_t (int f);
  virtual ~fd_t ();
  int fd () const { return _fd; }
  virtual void close (cbb cb);
  bool is_open () const { return _state != STATE_CLOSED; }

  virtual ptr<sockfd_t> to_sockfd () { return NULL; }
  
  typedef enum { STATE_OPEN, STATE_EOF, STATE_CLOSED } fd_state_t;

  ihash_entry<fd_t> _lnk;
  const int _fd;
protected:
  fd_state_t _state;
};

//-----------------------------------------------------------------------

qhash<int, ptr<fd_t> > fdtab;

//-----------------------------------------------------------------------

fd_t::fd_t (int f) : _fd (f), _state (STATE_OPEN)
{
  fdtab.insert (f, mkref (this));
}

//-----------------------------------------------------------------------

fd_t::~fd_t ()
{
  assert ( _state == STATE_CLOSED );
}

//-----------------------------------------------------------------------

void
fd_t::close (cbb cb)
{
  ptr<fd_t> hold (mkref (this));
  assert (_state != STATE_CLOSED);
  ::close (_fd);
  _state = STATE_CLOSED;
  fdtab.remove (_fd);
  hold = NULL;
  cb->trigger (true);
}

//-----------------------------------------------------------------------

class filefd_t : public fd_t {
public:
  filefd_t (int fd) : fd_t (fd) {}
};

//-----------------------------------------------------------------------

class sockfd_t : public fd_t {
public:
  sockfd_t (rm_test_t *rmt, int fd): 
    fd_t (fd),
    _rm_tst (rmt),
    _write (_fd, selwrite),
    _read (_fd, selread) {}

  ~sockfd_t () { _call_on_close = NULL; }
  
  void set_call_on_close (cbv c)
  {
    assert (!_call_on_close);
    _call_on_close = c;
  }

  void clear_call_on_close () { _call_on_close = NULL; }

  ptr<sockfd_t> to_sockfd () { return mkref (this); }

  void close (cbb cb) { close_T (cb); }

  tame::iofd_t &write() { return _write; }
  tame::iofd_t &read () { return _read; }

private:
  void close_T (cbb cb, CLOSURE);
  rm_test_t *_rm_tst;
  tame::iofd_t _write, _read;

  cbv::ptr _call_on_close;
};

//-----------------------------------------------------------------------

class rm_test_t : public test_harness_t {
public:
  rm_test_t (const str &s) 
    : test_harness_t (), _sock (s), _hlp (flume_prog_1, _sock) {}
  void run (CLOSURE);
  void handle_op (const vec<str> &s, cbb cb) { handle_op_T (s, cb); }
  void set_label (const vec<str> &s, cbb cb, CLOSURE);
  void get_label (const vec<str> &s, cbb cb, CLOSURE);
  void get_label_on_file (const vec<str> &s, cbb cb, CLOSURE);
  void create_file (const vec<str> &s, cbb cb, CLOSURE);
  void make_dir (const vec<str> &s, cbb cb, CLOSURE);
  void read_file (const vec<str> &s, cbb cb, CLOSURE);
  void append_to_file (const vec<str> &s, cbb cb, CLOSURE);
  void flume_stat_file (const vec<str> &s, cbb cb, CLOSURE);
  void make_unixsocket (const vec<str> &s, cbb cb, CLOSURE);
  void unixsocket_connect (const vec<str> &s, cbb cb, CLOSURE);
  void write_bytes (const vec<str> &s, bool waitreply, cbb cb, CLOSURE);
  void close_file (const vec<str> &s, cbb, CLOSURE);
  void make_uposp (const vec<str> &s, cbb cb, CLOSURE);
  void handle_claim_uposp (const vec<str> &s, cbb cb, CLOSURE);
  void flume_chdir (const vec<str> &s, cbb cb, CLOSURE);
  void flume_getcwd (const vec<str> &s, cbb cb, CLOSURE);
  void flume_unlink (const vec<str> &s, cbb cb, CLOSURE);
  void flume_link (const vec<str> &s, cbb cb, CLOSURE);
  void flume_rename (const vec<str> &s, cbb cb, CLOSURE);
  void flume_symlink (const vec<str> &s, cbb cb, CLOSURE);
  void fake_confinement (const vec<str> &s, cbb cb, CLOSURE);
  void get_confined (const vec<str> &s, cbb cb, CLOSURE);
  void freeze_label (const vec<str> &s, cbb cb, CLOSURE);
  void make_nickname (const vec<str> &s, cbb cb, CLOSURE);
  void lookup_by_nickname (const vec<str> &s, cbb cb, CLOSURE);
  void make_login (const vec<str> &s, cbb cb, CLOSURE);

  void cmd_init ();
  void do_unlink (const str &f, cbb cb, CLOSURE);
  helper_t *conn () { return &_hlp; }

protected:
  
  void claim_uposp (handle_t h, cbb cb, CLOSURE);

  void open_file (const str &a, int mode, int flags, cbi cb,
		  const labelset_t *ls = NULL, CLOSURE);

  void mkdir (const str &d, int mode, cbi cb,
	      const labelset_t *ls, CLOSURE);

  bool is_open (int fdn) 
  { 
    ptr<fd_t> *fd;
    return ((fd = fdtab[fdn]) && (*fd)->is_open ());
  }

  void register_fd (int fd, const handle_t &x, cbb cb, CLOSURE);

  void add_to_group_op (handle_t m, const x_handlevec_t *x, cbb cb)
  { add_to_group_op_T (m, x, cb); }

  void new_group_op (const str &name, const labelset_t &ls, 
		     new_group_res_t *res, cbb cb)
  { new_group_op_T (name, ls, res, cb); }
  
public:
  class srv_t {
  public:
    srv_t (rm_test_t *t, int f) : 
      _rm_tst (t), 
      _fd (New refcounted<sockfd_t> (_rm_tst, f)) {}

    virtual ~srv_t () { _fd = NULL; }
    void serve_loop (CLOSURE);
    virtual void serve_action (cbb) = 0;
    virtual const char *serve_desc () const = 0;
    virtual void finish (cbv cb) { cb->trigger (); }
  protected:
    rm_test_t *_rm_tst;
    ptr<sockfd_t> _fd;
  };

  class listen_srv_t : public srv_t {
  public:
    listen_srv_t (rm_test_t *t, int f, const str &path) : 
      srv_t (t, f) , _path (path) {}
    void serve_action (cbb cb) { serve_action_T (cb); }

    static void serve (rm_test_t *t, int f, const str &path)
    {
      (New listen_srv_t (t, f, path))->serve_loop ();
    }
    void finish (cbv cb) { finish_T (cb); }

    const char *serve_desc () const { return "listening"; }
  private:
    void finish_T (cbv cb, CLOSURE);
    void serve_action_T (cbb cb, CLOSURE);
    const str _path;
  };

  class unidir_srv_t : public srv_t {
  public:
    unidir_srv_t (rm_test_t *t, int f) : srv_t (t, f) {}
    void serve_action (cbb cb) { serve_action_T (cb); }
    const char * serve_desc () const { return "serving requests"; }

    virtual bool reply () { return true; }
    
    static void serve (rm_test_t *t, int f)
    {
      (New unidir_srv_t (t, f))->serve_loop ();
    }
  private:
    void serve_action_T (cbb cb, CLOSURE);
  };

  class bidir_srv_t : public unidir_srv_t {
  public:
    bidir_srv_t (rm_test_t *t, int f) : unidir_srv_t (t, f), _reply_no (1) {}
    bool reply ();
    static void serve (rm_test_t *t, int f)
    {
      (New bidir_srv_t (t, f))->serve_loop ();
    }
  private:
    int _reply_no;
  };

private:
  void handle_op_T (const vec<str> &s, cbb cb, CLOSURE);
  void add_to_group_op_T (handle_t m, const x_handlevec_t *x, cbb cb, CLOSURE);

  void new_handle_proc (int *i, str *n) const { PROC(i, n, NEW_HANDLE); }
  void group_op_proc (int *i, str *n) const { PROC(i, n, OPERATE_ON_GROUP); }
  void lookup_proc (int *i, str *n) const 
  { PROC( i, n, LOOKUP_HANDLE_BY_NICKNAME); }
  void req_privs_proc (int *i, str *n) const { PROC(i, n, REQ_PRIVS); }
  str progname () const { return "flumerm"; }

  void convert_args_to_label (const vec<str> &args, size_t argind, 
			      x_label_t *out, cbb done, CLOSURE);
  void parse_set_label (const vec<str> &args, set_label_arg_t *arg, cbb cb,
			CLOSURE);
  void new_group_op_T (const str &name, const labelset_t &ls,
		       new_group_res_t *res, cbb cb, CLOSURE);

  const str _sock;
  helper_unix_t _hlp;
};

//-----------------------------------------------------------------------

tamed void
rm_test_t::convert_args_to_label (const vec<str> &args, size_t argind, 
				  x_label_t *out, cbb done)
{
  tvars {
    handle_t h;
    bool ret (true);
    bool ok;
    size_t i;
  }
  for (i = argind; i < args.size (); i++) {
    twait { str2handle (args[i], &h, mkevent (ok)); }
    if (ok) {
      out->push_back (h);
    } else {
      ret = false;
    }
  }
  done->trigger (ret);
}

//-----------------------------------------------------------------------

static bool
parse_get_label (const vec<str> &args, size_t &argid, get_label_arg_t *arg)
{
  int ch;
  argv_t argv (args);
  optind = 1;
  int fd_tmp;

  arg->specifiers.set_scope (LABEL_SCOPE_PROCESS);
  while ((ch = getopt (argv.size (), argv, "f:")) != -1) {
    switch (ch) {
    case 'f':
      if (!convertint (optarg, &fd_tmp)) {
	warn << "Cannot convert arg into fd: " << optarg << "\n";
	return false;
      } else {
	arg->specifiers.set_scope (LABEL_SCOPE_FD);
	*arg->specifiers.fd = fd_tmp;
      }
      break;
    default:
      warn << "Unexpected option passed to command\n";
      return false;
    }
  }
  argid = optind;
      
  if (argid < args.size ()) {
    char c = args[argid][0];
    switch (c) {
    case 'S':
      arg->type = LABEL_S;
      break;
    case 'I':
      arg->type = LABEL_I;
      break;
    case 'O':
      arg->type = LABEL_O;
      break;
    default:
      warn << "Unknown label type given: " << args[argid] << "\n";
      return false;
    }
    if (arg->specifiers.scope == LABEL_SCOPE_FD && arg->type == LABEL_O) {
      warn << "Cannot get/set O label on an FD.\n";
      return false;
    }
    argid ++;
  } else {
    return false;
  }
  return true;
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::add_to_group_op_T (handle_t g, const x_handlevec_t *x, cbb cb)
{
  tvars {
    clnt_stat err;
    flume_status_t res;
    operate_on_group_arg_t arg;
    bool rc (false);
  }
  arg.group = g;
  arg.op = GROUP_OPERATION_ADD;
  arg.terms = *x;
  twait { conn ()->call (OPERATE_ON_GROUP, &arg, &res, mkevent (err)); }
  if (err) {
    warn << "Error in OPERATE_ON_GROUP: " << err << "\n";
  } else if (res != FLUME_OK) {
    warn << "Non-OK res from OPERATE_ON_GROUP: " << int (res) << "\n";
  } else {
    rc = true;
  }
  cb->trigger (rc);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::parse_set_label (const vec<str> &args, set_label_arg_t *arg, cbb cb)
{
  tvars {
    size_t argid;
    bool ret;
  }
  if (parse_get_label (args, argid, &arg->which)) {
    twait { 
      convert_args_to_label (args, argid, &arg->new_label, mkevent (ret)); 
    }
  } else {
    ret = false;
  }
  cb->trigger (ret);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::open_file (const str &path, int mode, int flags, cbi cb,
		      const labelset_t *ls)
{
  tvars {
    file_arg_t arg;
    file_res_t res;
    clnt_stat err;
    int ret (-1);
  }  

  arg.c_args.path = path;
  arg.c_args.mode = mode;
  arg.c_args.flags = flags;

  if (ls) {
    arg.xls.alloc ();
    ls->to_xdr (arg.xls);
  }

  twait { conn ()->call (OPEN_FILE, &arg, &res, mkevent (err)); }
  if (err) {
    warn << "In OPEN_FILE: " << err << "\n";
  } else if (res.status != FLUME_PATH_OK) {
    warn << "Non-OK return from OPEN_FILE: " << res.status << "\n";
  } else {
    aout << "Opened file ('" << *res.path << "')\n";
    ret = _hlp.unix_x ()->recvfd ();
  }
  cb->trigger (ret);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::new_group_op_T (const str &name, const labelset_t &ls,
			   new_group_res_t *res, cbb cb)
{
  tvars {
    new_group_arg_t arg;
    bool rc (false);
    clnt_stat err;
  }

  arg.name = name;
  ls.to_xdr (&arg.labels);
  twait { conn ()->call (NEW_GROUP, &arg, res, mkevent (err)); }
  if (err) {
    warn << "In NEW_GROUP: " << err << "\n";
  } else if (res->status != FLUME_OK) {
    warn << "Non-OK return from NEW_GROUP: "<< res->status << "\n";
  } else {
    rc = true;
  }
  cb->trigger (rc);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::flume_link (const vec<str> &args, cbb cb)
{
  tvars {
    file_arg_t arg;
    file_res_t res;
    clnt_stat err;
    bool ok (true);
  }

  if (args.size () == 3) {
    arg.c_args.path = args[1];
    arg.c_args.path_src.alloc ();
    *arg.c_args.path_src = args[2];
    twait { conn ()->call (FLUME_LINK, &arg, &res, mkevent (err)); }
    if (err) {
      warn << "RPC error in FLUME_LINK: " << err << "\n";
    } else if (res.status != FLUME_OK) {
      warn << "Unexpected return status: " << int (res.status) << "\n";
    } else {
      aout << "Link from " << args[2] << " -> " << args[1] << " succeeded.\n";
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::flume_rename (const vec<str> &args, cbb cb)
{
  tvars {
    file_arg_t arg;
    file_res_t res;
    clnt_stat err;
    bool ok (true);
  }
  if (args.size () == 3) {
    arg.c_args.path = args[2];
    arg.c_args.path_src.alloc ();
    *arg.c_args.path_src = args[1];
    twait { conn ()->call (FLUME_RENAME, &arg, &res, mkevent (err)); }
    if (err) {
      warn << "RPC error in FLUME_RENAME: " << err << "\n";
    } else if (res.status != FLUME_OK) {
      warn << "Unexpected return status: " << int (res.status) << "\n";
    } else {
      aout << "Rename from " << args[1] << " -> " 
	   << args[2] << " succeeded.\n";
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::flume_symlink (const vec<str> &args, cbb cb)
{
  tvars {
    file_arg_t arg;
    file_res_t res;
    clnt_stat err;
    bool ok (true);
  }
  if (args.size () == 3) {
    arg.c_args.path = args[2];
    arg.c_args.path_src.alloc ();
    *arg.c_args.path_src = args[1];
    twait { conn ()->call (FLUME_SYMLINK, &arg, &res, mkevent (err)); }
    if (err) {
      warn << "RPC error in FLUME_SYMLINK: " << err << "\n";
    } else if (res.status != FLUME_OK) {
      warn << "Unexpected return status: " << int (res.status) << "\n";
    } else {
      aout << "Symlink from " << args[2] << " -> " 
	   << args[1] << " succeeded.\n";
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::do_unlink (const str &f, cbb cb)
{
  tvars {
    file_arg_t arg;
    file_res_t res;
    clnt_stat err;
    bool ok (false);
  }
  arg.c_args.path = f;
  arg.c_args.mode = 0;
  arg.c_args.flags = 0;
  twait { conn ()->call (FLUME_UNLINK_FILE, &arg, &res, mkevent (err)); }
  if (err) {
    warn << "RPC error in FLUME_UNLINK_FILE: " << err << "\n";
  } else if (res.status != FLUME_OK) {
    warn << "Unexpected return status: " << int(res.status) << "\n";
  } else {
    ok = true;
  } 
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::flume_unlink (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok, dummy;
  }
  if (args.size () == 2) {
    twait { do_unlink (args[1], mkevent (dummy)); }
    ok = true;
  } else {
    ok = false;
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
sockfd_t::close_T (cbb cb)
{
  tvars {
    flume_status_t res;
    clnt_stat err;
    bool rc (true);
    ptr<sockfd_t> hold;
  }
  hold = mkref (this);
  assert (_state != STATE_CLOSED);

  twait { _rm_tst->conn ()->call (FLUME_CLOSE, &_fd, &res, mkevent (err)); }
  if (err) {
    warn << "RPC error in FLUME_CLOSE: " << err << "\n";
    rc = false;
  } else if (res != FLUME_OK) {
    warn << "Unexpected return status from FLUME_CLOSE: " << int (res) << "\n";
    rc = false;
  }

  twait { fd_t::close (mkevent (rc)); }

  safevtrig (&_call_on_close);
  hold = NULL;

  cb->trigger (rc);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::close_file (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok (true), rc;
    ptr<fd_t> *fdp, fd;
    int fdn;
  }

  if (args.size () == 2 && convertint (args[1], &fdn)) {
    fdp = fdtab[fdn];
    if (!fdp) {
      warn << "FD not found: " << fdn << "\n";
    } else {
      fd = *fdp;
      twait { fd->close (mkevent (rc)); }
      fd = NULL;
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::make_nickname (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok (true);
    new_nickname_arg_t arg;
    flume_status_t res;
    clnt_stat err;
    handle_t h;
  }

  if (args.size () == 3) {
    twait { str2handle (args[1], &h, mkevent (ok)); }
    if (ok) {
      arg.handle = h;
      arg.nickname = args[2];
      twait { conn ()->call (FLUME_NEW_NICKNAME, &arg, &res, mkevent (err)); }
      if (err) {
	warn << "RPC error in MAKE_NICKNAME: " << err << "\n";
      } else if (res != FLUME_OK) {
	warn << "Non-OK status from RM: " << int (res) << "\n";
      } else {
	aout << "nickname: " << args[2] << " -> " << h.to_str () << "\n";
      }
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::lookup_by_nickname(const vec<str> &args, cbb cb)
{
  tvars {
    bool ok (true);
    new_handle_res_t res;
    clnt_stat err;
    nickname_t n;
    handle_t h;
  }

  if (args.size () == 2) {
    n = args[1];
    twait { 
      conn ()->call (LOOKUP_HANDLE_BY_NICKNAME, &n, &res, mkevent (err)); 
    }
    if (err) { 
      warn << "RPC error in LOOKUP_HANDLE: " << err << "\n";
    } else if (res.status != FLUME_OK) {
      warn << "Non-OK status from RM: " << res.status << "\n";
    } else {
      h = handle_t (*res.base_h);
      aout << "Lookup (" << n << ") -> " << h.to_str () << "\n";
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::freeze_label (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok (true);
    str out;
    clnt_stat err;
    armor_type_t base (ARMOR_32);
    size_t ind (1);
    label_type_t typ;
    label_t l;
    freeze_label_res_t res;
    int rc;
    x_label_t xl;
  }
  if (args.size () > 1) {
    if (args[ind] == "-6") {
      base = ARMOR_16;
      ind++;
    }
    twait { parse_label (args, &ind, &l, &typ, mkevent (rc)); }
    if (rc != 1) {
      ok = false;
    } else {
      l.to_xdr (&xl);
      twait { conn ()->call (FLUME_FREEZE_LABEL, &xl, &res, mkevent (err)); }
      if (err) {
	warn << "RPC error in FREEZE_LABEL: " << err << "\n";
      } else if (res.status != FLUME_OK) {
	warn << "Non-OK result from FREEZE_LABEL: " << int (res.status) 
	     << "\n";
      } else {
	out = handle_t (*res.frozen).to_str (base);
	aout << "Result: " << out << "\n";
      }
    }
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::flume_getcwd (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok (true);
    fs_path_t cwd;
    clnt_stat err;
  }
  if (args.size () == 1) {
    twait { conn ()->call (FLUME_GETCWD, NULL, &cwd, mkevent (err)); }
    if (err) {
      warn << "Error in FLUME_GETCWD: " << err << "\n";
    } else {
      aout << "Cwd: " << cwd << "\n";
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::flume_chdir (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok (true);
    file_arg_t arg;
    file_res_t res;
    clnt_stat err;
  }

  if (args.size () == 2) {
    arg.c_args.path = args[1];
    twait { conn ()->call (FLUME_CHDIR, &arg, &res, mkevent (err)); }
    if (err) {
      warn << "Error on FLUME_CHDIR: " << err << "\n";
    } else if (res.status != FLUME_OK) {
      warn << "Unexected resulte from FLUME_CHDIR: " << int (res.status) 
	   << "\n";
    } else {
      aout << "Chdir to " << args[1] << " succeessful.\n";
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::claim_uposp (handle_t h, cbb cb)
{
  tvars {
    x_handle_t x (h);
    claim_res_t res;
    clnt_stat err;
    bool ok (false);
    int fd;
  }
  twait { conn ()->call (FLUME_CLAIM_FD, &x, &res, mkevent (err)); }
  if (err) {
    warn << "Error in FLUME_CLAIM_FD: " << err << "\n";
  } else if (res.status != FLUME_OK) {
    warn << "Unexpected result from FLUME_CLAIM_FD: " 
	 << int (res.status) << "\n";
  } else if ((fd = _hlp.unix_x ()->recvfd ()) < 0) {
    warn << "Failed to read FD from RM.\n";
  } else {
    aout << "Got new FD=" << fd << " with duplex=" << res.ok->duplex << "\n";
    twait { register_fd (fd, res.ok->opaque_h, mkevent (ok)); }
    if (ok) {
      if (int (res.ok->duplex) & int (DUPLEX_THEM_TO_ME)) 
	unidir_srv_t::serve (this, fd);
    }
  }
  cb->trigger (ok);
}


//-----------------------------------------------------------------------

tamed void
rm_test_t::handle_claim_uposp (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok (true), rc;
    handle_t h;
  }

  if (args.size () == 2 && h.from_str (args[1])) {
    twait { claim_uposp (h, mkevent (rc)); }
  } else {
    ok = false;
  }
  cb->trigger (ok);

}

//-----------------------------------------------------------------------

tamed void
rm_test_t::make_uposp (const vec<str> &args, cbb cb)
{
  tvars {
    int fd;
    bool ok (true);
    int duplex (0);
    size_t i;
    pipe_res_t res;
    pipe_arg_t parg;
    socketpair_arg_t sarg;
    clnt_stat err;
    bool rc;
  }
  for (i = 1; i < args.size (); i++) {
    if (strchr (args[i], 'r')) { duplex |= int (DUPLEX_THEM_TO_ME); }
    if (strchr (args[i], 'w')) { duplex |= int (DUPLEX_ME_TO_THEM); }
  }
  if (duplex == 0) {
    warn ("must specify r, w or both (for reading/writing/socket)\n");
    ok = false;
  } else {
    if (duplex == int(DUPLEX_FULL)) {
      sarg.domain = AF_UNIX;
      sarg.type = SOCK_STREAM;
      sarg.protocol = 0;
      twait { conn ()->call (FLUME_SOCKETPAIR, &sarg, &res, mkevent (err)); }
    } else {
      parg.writing = (duplex & int(DUPLEX_ME_TO_THEM));
      twait { conn ()->call (FLUME_PIPE, &parg, &res, mkevent (err)); }
    }
    if (err) {
      warn << "Error in PIPE/SOCKETPAIR: " << err << "\n";
    } else if (res.status != FLUME_OK) {
      warn << "Error in PIPE/SOCKETPAIR, status=" << res.status << "\n";
    } else {
      fd = _hlp.unix_x ()->recvfd ();
      twait { register_fd (fd, res.hpair->my_end, mkevent (rc)); }
      if (rc) {
	strbuf b ("New socketpair/pipe: (%d, 0x%" PRIx64 ")", fd, 
		  res.hpair->their_end);
	aout << b << "\n";
	if (duplex & int (DUPLEX_THEM_TO_ME)) {
	  unidir_srv_t::serve (this, fd);
	}
      }
    }
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::register_fd (int fd, const handle_t &x, cbb cb)
{
  tvars {
    register_fd_arg_t arg;
    flume_status_t res;
    clnt_stat err;
    bool ok (false);
  }
  arg.rm_side = x.value ();
  arg.proc_side = fd;
  twait { conn ()->call (FLUME_REGISTER_FD, &arg, &res, mkevent (err)); }
  if (err) {
    warn << "In FLUME_REGISTER_FD: " << err << "\n";
  } else if (res != FLUME_OK) {
    warn << "REGISTER_FD failed with status: " << res<< "\n";
  } else {
    ok = true;
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::write_bytes (const vec<str> &args, bool waitreply, cbb cb)
{
  tvars {
    ssize_t rc;
    int fdn;
    bool dummy;
    bool ok (true);
    bool read_ok (true);
    const char *cp, *endp;
    ssize_t bufsz (256);
    mstr buf (bufsz);
    ptr<sockfd_t> sfd;
    ptr<fd_t> *fd;
  }

  if (args.size () != 3 || !convertint (args[1], &fdn)) {
    ok = false;
  } else if (!(fd = fdtab[fdn]) || !(*fd)->is_open ()) {
    warn << "File descriptor is not open: " << fdn << "\n";
  } else if (!(sfd = (*fd)->to_sockfd ())) {
    warn << "File descriptor is not a socket; it should be\n";
  } else {
    
    assert (fdn == sfd->fd ());

    cp = args[2].cstr ();
    endp = cp + args[2].len ();


    while (cp < endp && read_ok) {
      twait { sfd->write ().on (mkevent ()); }

      rc = write (fdn, cp, endp - cp);
      if (rc < 0) {
	if (errno != EAGAIN) {
	  warn ("Write error writing out to fd=%d\n", fdn);
	  read_ok = false;
	} 
      } else {
	cp += rc;
      }
    }

    if (read_ok && waitreply) {
      twait { sfd->read ().on (mkevent ()); }
      rc = read (fdn, buf.cstr (), bufsz);
      if (rc == 0) {
	warn ("EOF on fd=%d\n", fdn);
	twait { sfd->close (mkevent (dummy)); }
      } else if (rc < 0) {
	warn ("Failed to read bytes on fd=%d: %m\n", fdn);
      } else {
	buf.setlen (rc);
	aout << "Reply from server: " << buf << "\n";
      }
    }
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::make_unixsocket (const vec<str> &args, cbb cb)
{
  tvars {
    str path;
    bool ok (true);
    file_arg_t arg;
    file_res_t res;
    clnt_stat err;
    listen_arg_t listen_arg;
    flume_status_t stat;
    handle_t h;
    int fd;
    bool rc;
    size_t ind;
    labelset_t ls;
    int lrc (0);
  }
  
  if (args.size () >= 2) {
    ind = 1;
    path = args[ind++];
    arg.c_args.path = path;
    arg.c_args.mode = 0644;
    arg.c_args.flags = 0;

    if (args.size () > 2) {
      twait { parse_labels (args, &ind, &ls, mkevent (lrc)); }
      if (lrc >= 0) {
	arg.xls.alloc ();
	ls.to_xdr (arg.xls);
      } else {
	warn << "Failed to parse labels..\n";
	ok = false;
      }
    }

    if (lrc >= 0) {
      twait { conn ()->call (FLUME_UNIXSOCKET, &arg, &res, mkevent (err)); }
      if (err) {
	warn << "In FLUME_UNIXSOCKET: " << err << "\n";
      } else if (res.status != FLUME_FDPASS_OK_OPAQUE) {
	warn << "Non-OK return from FLUME_UNIXSOCKET: " << res.status << "\n";
      } else {
	fd = _hlp.unix_x ()->recvfd ();
	h = *res.opaque_h;
	twait { register_fd (fd, h, mkevent (rc)); }
	if (rc) {
	  listen_arg.fd = fd;
	  listen_arg.queue_len = 10;
	  twait { 
	    conn ()->call (FLUME_LISTEN, &listen_arg, &stat, mkevent (err)); 
	  }
	  if (err) {
	    warn << "In FLUME_LISTEN: " << err << "\n";
	  } else if (stat != FLUME_OK) {
	    warn << "Non-OK return from FLUME_LISTEN: " << stat << "\n";
	  } else {
	    aout << "Socket on " << path << ": fd=" << fd << "\n";
	    listen_srv_t::serve (this, fd, path);
	  }
	}
      }
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::listen_srv_t::finish_T (cbv cb)
{
  tvars {
    bool rc;
  }
  twait { _rm_tst->do_unlink (_path, mkevent (rc)); }
  if (!rc) {
    warn << "Unlink failed on socket: " << _path << "\n";
  }
  cb->trigger ();
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::srv_t::serve_loop ()
{
  tvars {
    rendezvous_t<bool> G (__FILE__, __LINE__);
    bool go (true);
    bool stop_trig (false);
    bool dummy;
  }
  warn << "Listening on fd=" << _fd->fd () << " for " 
       << serve_desc () << "\n";

  _fd->set_call_on_close (mkevent (G, true));
  
  while (go) {
    _fd->read ().on (mkevent (G,false)); 
    twait (G, stop_trig);

    go = false;
    if (stop_trig) {
      _fd->read ().off ();
      warn << "Got stop trigger for fd=" << _fd->fd () << "\n";
    } else {
      twait { serve_action (mkevent (go)); }
    }
  }

  warn << "Leaving listen loop for fd=" << _fd->fd () << "\n";

  // If we got a "stop trigger", it's because someone else already
  // closed this FD; no need to close it again!
  if (!stop_trig) {
    _fd->clear_call_on_close ();
    twait { _fd->close (mkevent (dummy)); }
  }

  twait { finish (mkevent ()); }
  delete (this);
}

//-----------------------------------------------------------------------

tamed void 
rm_test_t::listen_srv_t::serve_action_T (cbb cb)
{
  tvars {
    u_int64_t val;
    bool go (false);
    ssize_t rc, sz (sizeof (val));
    handle_t h;
    int fd;
  }

  fd = _fd->fd ();

  rc = read (fd, static_cast<void *> (&val), sz);
  if (rc < 0) {
    warn ("Read on fd=%d failed: %m\n", fd);
  } else if (rc == 0) {
    warn ("EOF of fd=%d\n", fd);
  } else if (rc != sz) {
    warn << "Expected " << sz << " bytes but got " << rc << " bytes\n";
  } else {
    h = val;
    twait { _rm_tst->claim_uposp (h, mkevent (go)); }
  }
  cb->trigger (go);
}

//-----------------------------------------------------------------------

#define BUFSZ 8192

tamed void
rm_test_t::unidir_srv_t::serve_action_T (cbb cb)
{
  bool go = false;
  char buf[BUFSZ];
  int fd;

  fd = _fd->fd ();

  ssize_t rc = read (fd, buf, BUFSZ);
  if (rc < 0) {
    warn ("Read error on fd=%d: %m\n", fd);
  } else if (rc == 0) {
    warn ("EOF on fd=%d\n", fd);
  } else {
    str b (buf, rc);
    aout << "Got req on fd=" << fd << ":" << b << "\n";
    go = reply ();
  }
  cb->trigger (go);
}

//-----------------------------------------------------------------------

bool
rm_test_t::bidir_srv_t::reply ()
{  
  bool go = false ;
  char buf[BUFSZ];
  int n = snprintf (buf, BUFSZ-1, "Reply %d", _reply_no++);
  int rc;
  n++; // add a 0-byte
  int fd = _fd->fd ();

  rc = write (fd, buf, n);
  if (rc < 0) {
    warn ("Write failed on fd=%d: %m\n", fd);
  } else if (rc != n) {
    warn << "Short write on fd=" << fd << "\n";
  } else {
    go = true;
  }
  return go;
} 

//-----------------------------------------------------------------------

tamed void
rm_test_t::append_to_file (const vec<str> &args, cbb cb)
{
  tvars {
    str path, content;
    bool ok (true);
    int nfd;
  }
  if (args.size () == 3) {
    path = args[1];
    content = args[2];
    twait { open_file (path, 0, O_WRONLY|O_APPEND, mkevent (nfd)); }
    if (nfd >= 0) {
      strbuf b;
      b << content << "\n";
      int rc = b.tosuio ()->output (nfd);
      if (rc < 0) {
	warn ("Write to file %s failed: %m\n", path.cstr ());
      }
      close (nfd);
      aout << "Appended to file " << path << ": '" << content << "'\n";
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);

}

//-----------------------------------------------------------------------

tamed void
rm_test_t::read_file (const vec<str> &args, cbb cb)
{
  tvars {
    str path;
    bool ok (true);
    int rc;
    size_t bufsz (1024);
    char *buf;
    int nfd;
  }

  if (args.size () == 2) {
    path = args[1];
    twait { open_file (path, 0, O_RDONLY, mkevent (nfd)); }
    if (nfd >= 0) {
      aout << "File output for " << path << ":\n";
      buf = New char[bufsz];
      while ((rc = read (nfd, buf, bufsz)) != 0) {
	aout->write (buf, bufsz);
      }
      delete [] buf;
      close (nfd);
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::mkdir (const str &d, int mode, cbi cb, const labelset_t *ls)
{
  tvars {
    file_arg_t arg;
    file_res_t res;
    clnt_stat err;
    int rc (-1);
  }

  arg.c_args.path = d;
  arg.c_args.mode = mode;

  if (ls) {
    arg.xls.alloc ();
    ls->to_xdr (arg.xls);
  }

  twait { conn ()->call (FLUME_MKDIR, &arg, &res, mkevent (err)); }
  if (err) {
    warn << "In MKDIR: " << err << "\n";
  } else if (res.status != FLUME_OK) {
    warn << "MKDIR returned Non-OK status: " << res.status << "\n";
  } else {
    rc = 0;
  }
  cb->trigger (rc);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::make_dir (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok (true);
    str d;
    size_t ind;
    int rc;
    labelset_t ls;
  }
  
  if (args.size () > 1) {
    ind = 1;
    d = args[ind++];

    twait { parse_labels (args, &ind, &ls, mkevent (rc)); }

    if (rc >= 0) {
      twait { mkdir (d, 0644, mkevent (rc), &ls); }
      if (rc >= 0) {
	aout << "Made directory: " << d << "\n";
      }
    }
  } else {
    ok = false;
  }

  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::create_file (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok (false);
    str p;
    str contents;
    size_t ind;
    int rc;
    holdvar autocb_t<bool> acb (cb, ok);
    int nfd;
    labelset_t ls;
  }

  if (args.size () < 3) 
    return;

  ind = 1;
  p = args[ind++];
  contents = args[ind++];

  twait { parse_labels (args, &ind, &ls, mkevent (rc)); }

  if (rc < 0) 
    return;

  ok = true;

  twait { open_file (p, 0644, O_CREAT|O_WRONLY, mkevent (nfd), &ls); }

  if (nfd >= 0) {
    strbuf b;
    b << contents << "\n";
    b.tosuio ()->output (nfd);
    close (nfd);
    aout << "Wrote out to file: " << p << "\n";
  }
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::flume_stat_file (const vec<str> &args, cbb cb)
{
  tvars {
    file_arg_t arg;
    file_res_t res;
    clnt_stat err;
    str p;
    bool ok (true);
  }
  if (args.size () == 2) {
    p = args[1];
    arg.c_args.path = p;
    arg.c_args.mode = 0;
    arg.c_args.flags = 0;

    twait { conn ()->call (FLUME_STAT_FILE, &arg, &res, mkevent (err)); }
    if (err) {
      warn << "Error in FLUME_STAT_FILE: " << err << "\n";
    } else if (res.status == FLUME_OK) {
      warn << "File found but does not have extended attributes.\n";
    } else if (res.status != FLUME_LABEL_OK) {
      warn << "Non-OK return from FLUME_STAT_FILE: " << res.status << "\n";
    } else {
      labelset_t ls (*res.label);
      aout << "FlumeStat (" <<  p << "):\n"
	   << ls.to_str ();
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);
}
//-----------------------------------------------------------------------

tamed void
rm_test_t::get_confined (const vec<str> &args, cbb cb)
{
  tvars {
    bool res;
    clnt_stat err;
    bool ok (true);
  }
  if (args.size () == 1) {
    twait { conn ()->call (FLUME_GET_CONFINED, NULL, &res, mkevent (err)); }
    if (err) {
      warn << "RPC error in FLUME_GET_CONFINED: " << err << "\n";
    } else {
      aout << "Confinement is " << int (res) << "\n";
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);

}

//-----------------------------------------------------------------------

tamed void
rm_test_t::fake_confinement (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok (true);
    int i;
    bool arg;
    flume_status_t res;
    clnt_stat err;
  }
  if (args.size () == 2 && convertint (args[1], &i)) {
    arg = i;
    twait { conn ()->call (FLUME_FAKE_CONFINEMENT, &arg, &res, mkevent (err)); }
    if (err) {
      warn << "RPC Error in FAKE_CONFINEMENT: " << err << "\n";
    } else if (res != FLUME_OK) {
      warn << "Non-OK return from FAKE_CONFINEMENT: " << int (res) << "\n";
    } else {
      aout << "FAKE CONFINEMENT(" << i << ") succeeded.\n";
    }
  } else {
    ok = false;
  }
  cb->trigger (ok);
}


//-----------------------------------------------------------------------


tamed void
rm_test_t::make_login (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok;
    make_login_arg_t arg;
    make_login_res_t res;
    handle_t h;
    clnt_stat err;
  }

  if (args.size () != 2) {
    ok = false;
  } else {
    twait { str2handle (args[1], &h, mkevent (ok)); }
    if (ok) {
      arg.handle = h;
      arg.duration = 0;
      arg.fixed = 0;
      arg.desired_tok_typ = PRIV_TOK_STR;
      twait { conn ()->call (MAKE_LOGIN, &arg, &res, mkevent (err)); }
      if (err) {
	warn << "In MAKE_LOGIN: " << err << "\n";
      } else if (res.status != FLUME_OK) {
	warn << "MAKE_LOGIN error: Status = " << int(res.status) << "\n";
      } else if (res.token->typ != PRIV_TOK_STR) {
	warn << "MAKE_LOGIN returned wrong type of token.\n";
      } else {
	aout << "Successful login: " << args[1] << " -> " 
	     << *res.token->strtok << "\n";
      }
    }
  }
  cb->trigger (ok);
}


//-----------------------------------------------------------------------

tamed void
rm_test_t::set_label (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok;
    set_label_arg_t arg;
    flume_res_t res;
    clnt_stat err;
  }

  twait { parse_set_label (args, &arg, mkevent (ok)); }

  if (ok) {
    twait { conn ()->call (SET_LABEL, &arg, &res, mkevent (err)); }
    if (err) {
      warn << "** In SET_LABEL: " << err << "\n";
    } else if (res.status != FLUME_OK) {
      warn << "** flumerm error in SET_LABEL: " << res.status << "\n";
    } else {
      aout << "Label set successful.\n";
    }
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::get_label (const vec<str> &args, cbb cb)
{
  tvars {
    bool ok;
    get_label_arg_t arg;
    get_label_res_t res;
    clnt_stat err;
    size_t dummy;
  }

  if ((ok = parse_get_label (args, dummy, &arg))) {
    twait { conn ()->call (GET_LABEL, &arg, &res, mkevent (err)); }
    if (err) {
      warn << "** In GET_LABEL: " << err << "\n";
    } else if (res.status != FLUME_OK) {
      warn << "** flumerm error in GET_LABEL: " << res.status << "\n";
    } else {
      label_t l (*res.label);
      aout << "Label returned: " << l.to_str () << "\n";
    }
  }
  cb->trigger (ok);
}

//-----------------------------------------------------------------------

tamed void
rm_test_t::handle_op_T (const vec<str> &args, cbb cb)
{
  tvars { 
    bool handled (true);
    bool ok;
    int a;
  }
  a = str2cmd (args[0]);

  switch (a) {
  case CMD_APPEND_TO_FILE:
    {
      twait { append_to_file (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: A[ppend-to-file] <path> <content>             "
	  "(append stuff to a file)\n";
      }
      break;
    }
  case CMD_SET_LABEL:
    {
      twait { set_label (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: s[et-label] [-f<fd>] [S|I|O] <h1> <h2> ...    "
	  "(set process or FD label)\n";
      }
      break;
    }
  case CMD_GET_LABEL:
    {
      twait { get_label (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: f[etch-label] [-f<fd> [S|I|O]                 "
	  "(get process or FD label)\n";
      }
      break;
    }
  case CMD_CREATE_FILE:
    {
      twait { create_file (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: c[reate-file] <path> <contents> [<s-label>] "
	  "[<o-label>]     (create a new file)\n";
      }
      break;
    }
  case CMD_MKDIR:
    {
      twait { make_dir (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: M[ake-Dir] <path> [<s-label>] [<o-label>]    "
	  "(create a new directory)\n";
      }
      break;
    }
  case CMD_SYNCHRONOUS_WRITE:
    {
      twait { write_bytes (args, true, mkevent (ok)); }
      if (!ok) {
	warn << "usage: W[rite-bytes] <fd> <bytes>                   "
	  "(write bytes to a server socket/wait for reply)\n";
      }
      break;
    }
  case CMD_ASYNCHRONOUS_WRITE:
    {
      twait { write_bytes (args, false, mkevent (ok)); }
      if (!ok) {
	warn << "usage: w[rite-bytes] <fd> <bytes>                   "
	  "(write bytes to a server socket)\n";
      }
      break;
    } 
  case CMD_CLOSE_FILE:
    {
      twait { close_file (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: k[lose] <fd>                                "
	  "(close FD)\n";
      }
      break;
    }
  case CMD_READ_FILE:
    {
      twait { read_file (args,  mkevent (ok)); }
      if (!ok) {
	warn << "usage: r[ead-file] <path>                          "
	  "(read a file)\n";
      }
      break;
    }
  case CMD_STAT_FILE:
    {
      twait { flume_stat_file (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: p[eek-at-file-label] <path>                 "
	  "(stat a file for FLUME labels)\n";
      }
      break;
    }
  case CMD_MAKE_UNIXSOCKET:
    {
      twait { make_unixsocket (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: S[ocket-create] <file>                      "
	  "(make a new socket on the FS)\n";
      }
      break;
    }

  case CMD_MAKE_LOGIN:
    {
      twait { make_login (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: m[ake-login] <handle>   "
	  "(make a login token from a handle)\n";
      }
      break;
    }

  case CMD_MAKE_SOCKETPAIR:
    {
      twait { make_uposp (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: u[nix-pipe-or-socketpair] [r|w]             "
	  "(make a pipe or socketpair)\n";
      }
      break;
    }

  case CMD_CLAIM_SOCKETPAIR:
    {
      twait { handle_claim_uposp (args, mkevent (ok)); }
      if (!ok) { 
	warn << "usage: K[laim] <handle>                            "
	  "(claim a Unix socketpair or handle endpoint)\n";
      }
      break;
    }

  case CMD_CHDIR:
    {
      twait { flume_chdir (args, mkevent (ok)); }
      if (!ok) {

      }
      break;
    }

  case CMD_UNLINK_FILE:
    {
      twait { flume_unlink (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: unlink <filename>\n";
      }
      break;
    }

  case CMD_LINK_FILE:
    {
      twait { flume_link (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: link <to> <from>\n";
      }
      break;
    }
    
  case CMD_RENAME:
    {
      twait { flume_rename (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: link <to> <from>\n";
      }
      break;
    }

  case CMD_SYMLINK:
    {
      twait { flume_symlink (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: symlink <to> <from>\n";
      }
      break;
    }

  case CMD_FAKE_CONFINEMENT:
    {
      twait { fake_confinement (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: fake <0|1>\n";
      }
      break;
    }

  case CMD_GET_CONFINED:
    {
      twait { get_confined (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: getconfined\n";
      }
      break;
    }

  case CMD_GETCWD:
    {
      twait { flume_getcwd (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: getcwd\n";
      }
      break;
    }

  case CMD_FREEZE_LABEL:
    {
      twait { freeze_label (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: freeze [-h] <label>\n";
      }
      break;
    }

  case CMD_MAKE_NICKNAME:
    {
      twait { make_nickname (args, mkevent (ok)); }
      if (!ok){
	warn << "usage: mknickname <handle> <nick>\n";
      }
      break;
    }

  case CMD_LOOKUP_BY_NICKNAME:
    {
      twait { lookup_by_nickname (args, mkevent (ok)); }
      if (!ok) {
	warn << "usage: lookup <nickanme>\n";
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
rm_test_t::run ()
{
  tvars {
    bool ok;
  }

  twait { _hlp.connect (mkevent (ok)); }
  if (!ok) {
    warn << "Cannot connect to socket: " << _sock << "\n";
    exit (1);
  }
  twait { serveloop (mkevent ()); }
  exit (0);
}

//-----------------------------------------------------------------------

static void
usage () 
{
  warnx << "usage: " << progname << " [<cfg-file>]\n";
  exit (0);
}

void
rm_test_t::cmd_init ()
{
  test_harness_t::cmd_init ();
  add_cmd (CMD_APPEND_TO_FILE, "append", "append bytes to a file");
  add_cmd (CMD_SET_LABEL, "setl", "set a given label");
  add_cmd (CMD_GET_LABEL, "getl", "get a given label");
  add_cmd (CMD_CREATE_FILE, "creat", "write given bytes to a new file");
  add_cmd (CMD_MKDIR, "mkdir", "make a new directory");
  add_cmd (CMD_SYNCHRONOUS_WRITE, "swrite", "write bytes and wait for answer");
  add_cmd (CMD_ASYNCHRONOUS_WRITE, "awrite", "write bytes but don't wait");
  add_cmd (CMD_CLOSE_FILE, "close", "close an open file descriptor");
  add_cmd (CMD_READ_FILE, "read", "read bytes out of a file");
  add_cmd (CMD_STAT_FILE, "stat", "stat a flume file for its labels");
  add_cmd (CMD_MAKE_UNIXSOCKET, "usocket", "make a named unix socket");
  add_cmd (CMD_CONNECT_UNIXSOCKET, "ucon", "connect to a name unix socket");
  add_cmd (CMD_MAKE_SOCKETPAIR, "socketpair", "make a unix socketpair");
  add_cmd (CMD_CLAIM_SOCKETPAIR, "claim", "claim an end of a unix socketpair");
  add_cmd (CMD_CHDIR, "chdir", "change directories");
  add_cmd (CMD_UNLINK_FILE, "unlink", "unlink a filename");
  add_cmd (CMD_LINK_FILE, "link", "hardlink file B to point to A.");
  add_cmd (CMD_RENAME, "rename", "rename file A to B.");
  add_cmd (CMD_SYMLINK, "symlink", "symlink entry B to point to A.");
  add_cmd (CMD_FAKE_CONFINEMENT, "fake", "'fake' confinement");
  add_cmd (CMD_GET_CONFINED, "getconfined", "get confinement flag");
  add_cmd (CMD_GETCWD, "getcwd", "get current working directory");
  add_cmd (CMD_FREEZE_LABEL, "freeze", "freeze a label to str repr");
  add_cmd (CMD_LOOKUP_BY_NICKNAME, "lookup", "lookup handle by nickname");
  add_cmd (CMD_MAKE_NICKNAME, "mknick", "make a new nickname");
  add_cmd (CMD_MAKE_LOGIN, "mkl", "make a login token");
}

//-----------------------------------------------------------------------

int
main (int argc, char *argv[])
{
  str s = rm::socket_file;
  setprogname (argv[0]);

  if (argc == 2) {
    s = argv[1];
  } else if (argc != 1) {
    usage ();
  }

  rm_test_t *t = New rm_test_t (s);
  t->cmd_init ();
  t->run ();
  amain ();
  return (0);
}
