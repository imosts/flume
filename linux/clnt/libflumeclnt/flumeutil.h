#ifndef FLUMEUTIL_H
#define FLUMEUTIL_H
#include "async.h"
#include "flume_prot.h"

int clear_label (label_type_t type);

/* Deal with labels */
bool contains_tag (vec<x_handle_t> &v, x_handle_t h);
x_label_t *label_from_vec (vec<x_handle_t> &v);
x_labelset_t *labelset_from_vecs (vec<x_handle_t> &stags, vec<x_handle_t> &itags, 
                                   vec<x_handle_t> &otags);

int flume_dump_labels (FILE *s);

#endif
