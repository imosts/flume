
#include "filter.h"

void
filter_t::to_xdr (x_filter_t *out) const
{
  _find.to_xdr (&out->find);
  _replace.to_xdr (&out->replace);
}

void
filtervec_t::to_xdr (x_filtervec_t *x) const
{
  x->setsize (_v.size ());
  for (size_t i = 0; i < _v.size (); i++) {
    _v[i].to_xdr (&(*x)[i]);
  }
}

void
filterset_t::to_xdr (x_filterset_t *x) const
{
  _s.to_xdr (&x->S);
  _i.to_xdr (&x->I);
}

bool
filtervec_t::apply (label_t *l) const
{
  bool ret = false;
  for (size_t i = 0; i < _v.size (); i++) {
    if (_v[i].apply (l))
      ret = true;
  }
  return ret;
}

bool
filterset_t::apply (labelset_t *l, bool do_clone) const
{
  if (!_s.is_empty ()) {
    if (do_clone) 
      l->clone_S ();
    _s.apply (l->S ());
  }
  if (!_i.is_empty ()) {
    if (do_clone) 
      l->clone_I (); 
    _i.apply (l->I ());
  }
  return true;
}

bool
filter_t::apply (label_t *l) const
{
  bool ret = false;
  if (l && l->is_infinite ()) {
    ret = true;
  } else if (_find.is_empty () || (l && _find.subset_of (l))) {
    ret = true;
    hset_iterator_t s (_find.map ());
    const handle_t *h;
    while ((h = s.next ())) {
      l->remove (*h);
    }
    hset_iterator_t a (_replace.map ());
    while ((h = a.next ())) {
      l->insert (*h);
    }
  }
  return ret;
}

bool
filterset_t::push_back (const filter_t &f, label_type_t typ)
{
  bool ret = true;
  switch (typ) {
  case LABEL_S:
    _s.push_back (f);
    break;
  case LABEL_I:
    _i.push_back (f);
    break;
  default:
    ret = false;
    break;
  }
  return ret;
}

void
filter_t::compute_delta (label_t *add, label_t *sub) const
{
  _replace.subtract (_find, add);
  _find.subtract (_replace, sub);
}
