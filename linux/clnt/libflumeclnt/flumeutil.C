#include "async.h"
#include "flume_prot.h"
extern "C" { 
#include "flume_clnt.h"
}

int clear_label (label_type_t type) {
  x_label_t *empty = label_alloc (0);
  int rc = flume_set_label (empty, type, 0);
  label_free (empty);
  return rc;
}

bool
contains_tag (vec<x_handle_t> &v, x_handle_t h) {
  for (unsigned i=0; i<v.size(); i++)
    if (v[i] == h)
      return true;
  return false;
}

x_label_t *
label_from_vec (vec<x_handle_t> &v) {
  x_label_t *lab = label_alloc (v.size());
  for (unsigned i=0; i<v.size(); i++)
    if (label_set (lab, i, v[i]) < 0) {
      label_free (lab);
      return NULL;
    }
  return lab;
}

x_labelset_t *
labelset_from_vecs (vec<x_handle_t> &stags, vec<x_handle_t> &itags, 
                    vec<x_handle_t> &otags) {
  x_label_t *slab = label_from_vec (stags);
  x_label_t *ilab = label_from_vec (itags);
  x_label_t *olab = label_from_vec (otags);

  x_labelset_t *ls = labelset_alloc ();
  labelset_set_S (ls, slab);
  labelset_set_I (ls, ilab);
  labelset_set_O (ls, olab);

  label_free (slab);
  label_free (ilab);
  label_free (olab);
  return (slab && ilab && olab) ? ls : NULL;
}


int
flume_dump_labels (FILE *s)
{
  int ret = 0;
  x_label_t *lab = label_alloc (0);

  if (flume_get_label (lab, LABEL_S) < 0) {
    ret = -1;
    goto done;
  } else {
    label_print2 (s, "S label", lab);
    fprintf (s, "\n");
  }

  if (flume_get_label (lab, LABEL_I) < 0) {
    ret = -1;
    goto done;
  } else {
    label_print2 (s, "I label", lab);
    fprintf (s, "\n");
  }

  if (flume_get_label (lab, LABEL_O) < 0) {
    ret = -1;
    goto done;
  } else {
    label_print2 (s, "O label", lab);
    fprintf (s, "\n");
  }

 done:
  label_free (lab);
  return ret;
}
