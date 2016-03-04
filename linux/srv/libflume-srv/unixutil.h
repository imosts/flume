// -*-c++-*-

#ifndef _LIBFLUME_UNIXUTIL_H_
#define _LIBFLUME_UNIXUTIL_H_

//
// Stolen from okws/libpub/pubutil.h and pjail.h
//

#include "async.h"

int uname2uid (const str &un);
str uid2uname (int i);
int gname2gid (const str &gn);
bool isdir (const str &d);

bool dir_security_check (const str &p);
str apply_container_dir (const str &d, const str &e);
str re_fslash (const char *cp);
str dir_standardize (const str &s);
bool is_safe (const str &s);
str can_exec (const str &p);
int myopen (const char *arg, u_int mode = 0444);
bool can_read (const str &f);
void got_dir (str *out, vec<str> s, str loc, bool *errp);
bool ready_socket (const str &s);

struct flume_idpair_t {
  flume_idpair_t (const str &n) : name (n), id (-1) {}
  flume_idpair_t (int i) : id (i) {}
  virtual ~flume_idpair_t () {}
  virtual bool resolve () const = 0;

  operator bool () const
  { 
    // for anyonomous users/groups
    if (!name && id > 0) return true;

    // for standard users/groups that appear in /etc/(passwd|group)
    bool ret = name && resolve (); 
    if (name && !ret)
      warn << "Could not find " << typ () << " \"" << name << "\"\n";
    return ret;
  }
  virtual str typ () const = 0;

  str getname () const
  {
    if (name) return name;
    else return (strbuf () << id);
  }
  
  int getid () const 
  {
    if (id >= 0) return id;
    else if (!*this) return -1;
    else return id;
  }
protected:
  str name;
  mutable int id;
};

struct flume_usr_t : public flume_idpair_t {
  flume_usr_t (const str &n) : flume_idpair_t (n) {}
  flume_usr_t (int i) : flume_idpair_t (i) {}
  bool resolve () const { return ((id = uname2uid (name)) >= 0); }
  str typ () const { return "user"; }
};

struct flume_grp_t : public flume_idpair_t {
  flume_grp_t (const str &n) : flume_idpair_t (n) {}
  flume_grp_t (int i) : flume_idpair_t (i) {}
  bool resolve () const { return ((id = gname2gid (name)) >= 0); }
  str typ () const { return "group"; }
};

class jailable_t {
public:
  jailable_t (const str &j = NULL, int uid = -1) : 
    _jaildir (j), _jailed (false), _uid (uid >= 0 ? uid : getuid ()) {}
  bool chroot ();
  str jail2real (const str &fn, bool force = false) const;
  str nest_jails (const str &path) const;
  bool will_jail () const { return (_jailed || (_jaildir && !_uid)); }
  bool jail_mkdir (const str &d, mode_t mode, flume_usr_t *u, flume_grp_t *g);
  bool jail_mkdir_p (const str &d, mode_t mode, flume_usr_t *u, flume_grp_t *g);
  bool jail_cp (const str &fn, mode_t  mode, flume_usr_t *u, flume_grp_t *g);
  bool is_superuser () const { return _uid == 0; }
  int get_uid () const { return _uid; }
protected:
  bool fix_stat (const str &d, mode_t mode, flume_usr_t *u, flume_grp_t *g,
		 const struct stat &sb);
  str _jaildir;
  bool _jailed;
  int _uid;
};

class argv_t {
public:
  argv_t ();
  argv_t (const vec<str> &v, const char *const *seed = NULL);

  void init (const vec<str> &v, const char *const *seed = NULL);
  ~argv_t ();
  size_t size () const { return _v.size () - 1; }

  // BOOOOO; but getopt and everyone else seem to use char *const *
  // and not const char * const * as i suspect they should.
  operator char* const* () const { return dat (); }

  char *const* dat () const 
  { return const_cast<char *const *> (_v.base ()); }

private:
  vec<const char *> _v;
  vec<const char *> _free_me;
};

bool flume_cp (const str &src, const str &dest, int mode);

// strip comments after getline returns
void strip_comments (vec<str> *in);

// do the open flags connote a write?
bool flags_for_write (int f);
bool flags_for_read  (int f);

// do the open flags mutate the file during open?
bool flags_mutates (int i);
int flags_make_non_mutate (int i);

// supply reasonable params by default
int my_socketpair (int *fds);

template<class V, class U> void
vec2vec (const V &in, U *out)
{
  out->setsize (0);
  for (size_t i = 0; i < in.size (); i++) {
    out->push_back (in[i]);
  }

}

// Different on different platforms...
void getopt_reset ();

// convert a real 64-bit flmpid to a modified 32-bit flmpid that fits
// in a pid_t.
pid_t flmpid_to_flmpid32 (u_int64_t h);
bool is_flmpid32 (pid_t);


#endif /* _LIBFLUME_UNIXUTIL_H_ */
