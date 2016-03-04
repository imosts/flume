
// -*-c++-*-

#include "flume_prot.h"
#include "ihash.h"
#include "qhash.h"
#include "flume_bf60.h"
#include "tame.h"
#include "keyfunc.h"
#include "flume_ev_labels.h"

#ifndef __LIBFLUME_FILTER_H__
#define __LIBFLUME_FILTER_H__

/*
 * Given a label that is a subset of 'in', apply the given 'diff'
 * to the label, where 'sign' gives the sign of the operations
 * (whether add or subtract).
 */
class filter_t {
public:
  filter_t (const label_t &f, const label_t &r) : _find (f), _replace (r) {}
  filter_t (const x_filter_t &x) : _find (x.find), _replace (x.replace) {}
  filter_t () {}
  label_t *find () { return &_find; }
  label_t *replace () { return &_replace; }

  void to_xdr (x_filter_t *out) const;
  bool apply (label_t *l) const;
  void compute_delta (label_t *add, label_t *sub) const;

private:
  label_t _find;
  label_t _replace;
};

class filtervec_t {
public:
  filtervec_t () {}
  filtervec_t (const x_filtervec_t &x) 
  {
    for (size_t i = 0; i < x.size (); i++) {
      _v.push_back (filter_t (x[i]));
    }
  }
  void push_back (const filter_t &f) { _v.push_back (f); }
  void to_xdr (x_filtervec_t *x) const;
  bool apply (label_t *l) const;
  bool is_empty () const { return _v.size () == 0; }

private:
  vec<filter_t> _v;
};

class filterset_t {
public:
  filterset_t () {}
  filterset_t (const x_filterset_t &x) : _s (x.S), _i (x.I) {}
  void to_xdr (x_filterset_t *x) const;
  bool apply (labelset_t *l, bool clone = true) const;
  bool push_back (const filter_t &f, label_type_t typ);
private:
  filtervec_t _s, _i;
};


#endif /* __LIBFLUME_FILTER_H__ */
