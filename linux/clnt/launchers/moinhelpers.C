#include "moinhelpers.h"
#include "generichelpers.h"
#include "flumeutil.h"

principal_t *_me;
principal_hash_t _name2tags;

static rxx pagename_rxx ("\\/((\\S+)\\:)(\\w+)");
static rxx split_IS_rxx ("(\\w+)\\:(\\w*)");

principal_t *me () { 
  return _me; 
}

str labelset_to_filename (x_labelset_t *ls) {
  char *f = flume_labelset_to_filename (ls);
  str s = str(f);
  free (f);
  return s;
}

principal_t *get_principal (str name) {
  return _name2tags[name];
}

x_handle_t
env_to_i_handle (const char *env, int opt) {
  x_handle_t h = 0;
  char *s = getenv (env);
  if (!s)
    fprintf (stderr, "Please set environment variable %s\n", env);
  if (handle_from_str (s, &h) < 0)
    fprintf (stderr, "could not parse %s = %s", env, s);
  
  h = handle_construct (HANDLE_OPT_DEFAULT_SUBTRACT | HANDLE_OPT_PERSISTENT | opt, h);
  return h;
}

int
add_env_itag_to_i (const char *env) {
  x_handle_t h = env_to_i_handle (env, 0);
  if (!h)
    return -1;
  if (flume_expand_label (LABEL_I, h) < 0) 
    return -2;
  return 0;
}

int
add_env_itag_to_o (const char *env, const char *env_pw) {
  x_handle_t h = env_to_i_handle (env, CAPABILITY_ADD);
  if (!h)
    return -1;
  
  char *pw = getenv (env_pw);
  if (!pw)
    return -2;
  if (flume_req_privs (h, pw) < 0)
    return -3;
  return 0;
}

str moin_cgi (bool frozen) {
  strbuf sb = strbuf () << MOIN_INSTANCE;
  if (frozen)
    sb << "/cgi-bin/moin";
  else
    sb << "/cgi-bin/moin.cgi";
  return str(sb);
}

void
add_uetag (vec<x_handle_t> &v, principal_t *p) {
  x_handle_t h = handle_construct (CAPABILITY_SUBTRACT | 
                                    HANDLE_OPT_PERSISTENT | 
                                    HANDLE_OPT_DEFAULT_ADD, 
                                    handle_base (p->uetag));
  v.push_back (h);
}

void
add_etag (vec<x_handle_t> *v, principal_t *p) {
  v->push_back (p->etag);
}

void
add_all_etags (vec<x_handle_t> &v) {
  /* Put user's personal etag & group etags into S */
  callback<void, principal_t *>::ref cb = wrap (add_etag, &v);
  _name2tags.traverse (cb);
}

int
add_moinpath_tags (label_type_t type, str path, vec<x_handle_t> &v) {
  /* Takes a string like this: /moin:useralex:PrivatePage and figures out
   * what tags are associated with the page.
   *  It calculates S and I tags from the page's URL
   *  It gets O tags by stating the page's directory on disk  */
  principal_t *p;
  str I_lab, S_lab, pagename;
  
  if (pagename_rxx.match (path)) {
    str s = pagename_rxx[2];
    pagename = pagename_rxx[3];

    if (split_IS_rxx.match (s)) {
      I_lab = split_IS_rxx[1];
      S_lab = split_IS_rxx[2];
    } else {
      S_lab = s;
    }
  } else
    pagename = path;

  switch (type) {
  case LABEL_S:
    if (S_lab && S_lab.len() > 0) {
      if (!(p = _name2tags[S_lab]))
        return -1;
      v.push_back (p->etag);
    }
    return 0;
  case LABEL_I:
    if (I_lab && I_lab.len() > 0) {
      x_handle_t h = 0;
      if (I_lab == CLASSIC_STR) 
        h = env_to_i_handle (CLASSIC_I_ENV, 0);
      else if (I_lab == RIGHTSIDEBAR_STR) 
        h = env_to_i_handle (RIGHTSIDEBAR_I_ENV, 0);
      if (!h)
        return -2;
      v.push_back (h);
    }
    return 0;
  case LABEL_O:
    {
      /* temporarily increase our S label and stat the file, assume we
       * start with S = {}, I = {} */
      int ret = -3;
      x_label_t *slab = moinpath_to_label (LABEL_S, path);

      if (slab && flume_set_label (slab, LABEL_S, 1) == 0) {
        /* stat the page directory */
        str dname = moinpath_to_dname (path);
        x_labelset_t *ls = labelset_alloc ();
        if (flume_stat_file (ls, dname.cstr()) == 0) {
          if (ls->O) 
            for (unsigned i=0; i<ls->O->len; i++)
              v.push_back (ls->O->val[i]);
        } else 
          fprintf (stderr, "failed to stat %s\n", dname.cstr());
        
        clear_label (LABEL_S);
        ret = 0;
      }
      label_free (slab);
      return ret;
    }
  default:
    return -4;
  }
}

x_label_t *
moinpath_to_label (label_type_t type, str path) {
  vec<x_handle_t> v;
  if (add_moinpath_tags (type, path, v) < 0)
    return NULL;
  else
    return label_from_vec (v);
}

str
moinpath_to_dname (str path) {
  /* takes a string like this: /useralex:PrivatePage and returns
   * the directory name of the page on disk like this:
   * /disk/yipal/moin-pages/si4aaaaaaaaba.h25aaaaaaaaba/useralex:PrivatePage */

  /* create a labelset from the page's URL */
  vec<x_handle_t> itags, stags, otags;
  add_moinpath_tags (LABEL_S, path, stags);
  add_moinpath_tags (LABEL_I, path, itags);
  if (itags.size () == 0) {
    // moin is default
    x_handle_t h = env_to_i_handle (MOIN_I_ENV, 0);
    if (!h)
      fprintf (stderr, "could not get MOIN_I_ENV\n");
    itags.push_back (h);
  }

  x_labelset_t *ls = labelset_from_vecs (stags, itags, otags);
  str ls_dir = labelset_to_filename (ls);
  labelset_free (ls);
  return str (strbuf ("%s/%s/%s", PAGEDIR, ls_dir.cstr(), path.cstr()));
}

int
check_link_labels (str path) {
  /* check if the user will have enough privs to read this file.
   * This check is not for security, but to provide a nice err msg 
   */
  vec<x_handle_t> s;
  return add_moinpath_tags (LABEL_S, path, s);
}

principal_t *
read_tags (str un, str uid)
{
  return (_me = read_user_tags (un, uid, &_name2tags));
}
