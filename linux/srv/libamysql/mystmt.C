/* $Id: mystmt.C 697 2005-02-03 00:46:39Z max $ */

/*
 *
 * Copyright (C) 2002-2004 Maxwell Krohn (max@okcupid.com)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2, or (at
 * your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
 * USA
 *
 */

#include "mystmt.h"
#include <sys/time.h>
#include <time.h>

#if defined(HAVE_MYSQL_BINDFUNCS) && defined(HAVE_MYSQL_BIND)

sth_prepared_t::~sth_prepared_t ()
{
  if (bnds) delete [] bnds;
  if (sth) mysql_stmt_close (sth);
}

void
sth_prepared_t::clearfetch ()
{
  // clear out all fetches if we're STORING results but haven't
  // fetch any records, or if we're not storing results and there
  // are more records left to fetch
  if (state == AMYSQL_EXEC ||
      (state == AMYSQL_FETCH && (opts & AMYSQL_USERES))) 
    while (fetch2 (true) == ADB_OK) ;
}

str
sth_prepared_t::dump (mybind_param_t **arr, u_int n) 
{
  strbuf b;
  b << " q-> " << qry << "\n";
  b << " p-> ";
  for (u_int i = 0; i < n; i++) {
    if (i != 0)
      b << ", ";
    b << arr[i]->to_str ();
  }
  return b;
}


bool
sth_prepared_t::execute2 (MYSQL_BIND *b, mybind_param_t **arr, u_int n)
{
  // will clear any pending fetch()'s or any unused rows in
  // the case of mysql_use_result
  //
  clearfetch ();

  if (b && arr && n) {
    bind (b, arr, n);
    if (mysql_stmt_bind_param (sth, b) != 0) {
      err = strbuf ("bind error: ") << mysql_stmt_error (sth);
	  errno_n = mysql_stmt_errno (sth);
      return false;
    }
  }
  if (mysql_stmt_execute (sth) != 0) {
    err = strbuf ("execute error: ") << mysql_stmt_error (sth);
    errno_n = mysql_stmt_errno (sth);
    state = AMYSQL_NONE;
    return false;
  }
  state = AMYSQL_EXEC;
  return true;
}

bool
sth_prepared_t::bind_result ()
{
  if (!bnds)
    bnds = New MYSQL_BIND[res_n];
  assert (res_arr);
  for (u_int i = 0; i < res_n; i++)
    res_arr[i].bind (&bnds[i]);
  if (mysql_stmt_bind_result (sth, bnds) != 0) {
    err = strbuf ("bind failed: ") << mysql_stmt_error (sth);
	errno_n = mysql_stmt_errno (sth);
    return false;
  }
  return true;
}

void
sth_prepared_t::bind (MYSQL_BIND *b, mybind_param_t **a, u_int n)
{
  for (u_int i = 0; i < n; i++)
    a[i]->bind (&b[i]);
}

adb_status_t
sth_prepared_t::fetch2 (bool bnd)
{
  // state machine update
  if (state == AMYSQL_EXEC) {
    state = AMYSQL_FETCH;
    if (!(opts & AMYSQL_USERES)) {
      int rc = mysql_stmt_store_result (sth);
      if (rc != 0) {
	err = strbuf ("stmt_store error (") << rc << "): " 
					    << mysql_stmt_error (sth);
	errno_n = mysql_stmt_errno (sth);
	state = AMYSQL_NONE;
	return ADB_ERROR;
      }
    }
  }

  if (bnd && !bind_result ())
    return ADB_BIND_ERROR;

  int rc = mysql_stmt_fetch (sth);
  if (rc == MYSQL_NO_DATA) {
    state = AMYSQL_FETCH_DONE;
    return ADB_NOT_FOUND;
  } else if (rc != 0) {
    err = strbuf("fetch error:  ") << mysql_stmt_error (sth);
    errno_n = mysql_stmt_errno (sth);
    state = AMYSQL_NONE;
    return ADB_ERROR;
  }
  assign ();
  return ADB_OK;
}

#endif //  HAVE_MYSQL_BINDFUNCS && HAVE_MYSQL_BIND

void
mystmt_t::alloc_res_arr (u_int n)
{
  // reallocate if the old array is not big enough.
  if (res_n < n && res_arr) {
    delete [] res_arr;
    res_arr = NULL;
  }

  res_n = n;
  if (!res_arr)
    res_arr = New mybind_res_t[n];
}

bool
mystmt_t::execute1 (MYSQL_BIND *b, mybind_param_t **arr, u_int n)
{
  struct timeval t1;
  if (lqt) 
    gettimeofday (&t1, NULL);
  bool rc = execute2 (b, arr, n);
  if (lqt) {
    struct timeval t2;
    gettimeofday (&t2, NULL);
    long sd = (t2.tv_sec - t1.tv_sec) * 1000;
    sd += (t2.tv_usec - t1.tv_usec) / 1000;
    if (sd > long (lqt)) {
      warn << "* Long Query: " << sd << "ms\n";
      warn << "**  " << dump (arr, n) << "\n";
    }
  }
  return rc;
}


void
sth_parsed_t::clearfetch ()
{
  if (state == AMYSQL_EXEC) {
    assert (!myres);
    myres = (opts & AMYSQL_USERES) ? mysql_use_result (mysql)
      : mysql_store_result (mysql);
    if (myres) 
      warn << "exec() called without fetch() on query: " << last_qry << "\n";
    state = AMYSQL_FETCH;
  }
  if (state == AMYSQL_FETCH && (opts & AMYSQL_USERES)) 
    while (mysql_fetch_row (myres)) ;

  if (myres) {
    mysql_free_result (myres);
    myres = NULL;
  }

  if (state == AMYSQL_FETCH)
    state = AMYSQL_FETCH_DONE;
}

adb_status_t 
sth_parsed_t::fetch2 (bool bnd)
{
  if (!myres) {
    state = AMYSQL_FETCH;
    myres = (opts & AMYSQL_USERES) ? mysql_use_result (mysql) :
      mysql_store_result (mysql);

    if (myres) 
      my_res_n = mysql_num_fields (myres);
    else {
      err = strbuf ("MySQL result error: ") << mysql_error (mysql);
      errno_n = mysql_errno (mysql);
      state = AMYSQL_NONE;
      return ADB_ERROR;
    }
  }
  MYSQL_ROW row = mysql_fetch_row (myres);
  if (!row) {
    state = AMYSQL_FETCH_DONE;
    return ADB_NOT_FOUND;
  }
  length_arr = mysql_fetch_lengths (myres);

  row_to_res (&row);
  return ADB_OK;
}

void
sth_parsed_t::row_to_res (MYSQL_ROW *row)
{
  u_int lim = min (my_res_n, res_n);
  for (u_int i = 0; i < lim; i++) {
    res_arr[i].read_str ((*row)[i], length_arr ? length_arr[i] : 0);
  }
}

void
mystmt_t::assign ()
{
  for (u_int i = 0; i < res_n; i++) 
    res_arr[i].assign ();
}

mystmt_t::~mystmt_t ()
{
  if (res_arr) delete [] res_arr;
}


sth_parsed_t::~sth_parsed_t ()
{
  if (myres) {
    mysql_free_result (myres);
    myres = NULL;
  }
  dealloc_bufs ();
}

void
sth_parsed_t::alloc_bufs ()
{
  if (!bufs && n_iparam) {
    bufs = New char *[n_iparam];
    memset ((void *)bufs, 0, sizeof (char *) * n_iparam);
    lens = New u_int[n_iparam];
    memset ((void *)lens, 0, sizeof (int) * n_iparam);
  }
}

void
sth_parsed_t::dealloc_bufs ()
{
  if (bufs) {
    for (u_int i = 0; i < n_iparam; i++) 
      if (bufs[i]) delete [] bufs[i];
    delete [] bufs;
  }
}

bool
sth_parsed_t::parse ()
{
  const char *p1, *p2;
  p1 = qry.cstr ();
  int len;
  int len_left = qry.len ();
  if (len_left == 0 || p1[0] == '?')
    return false;
    
  while (p1 && *p1 && (p2 = strchr (p1, '?'))) {
    n_iparam++;
    if ((len = p2 - p1) > 0) {
      qry_parts.push_back (str (p1, len));
      p1 = p2 + 1;
    }
    len_left -= (len + 1);
  }
  if (p1 && *p1 && len_left)
    qry_parts.push_back (str (p1, len_left));

  return true;
}

str
sth_parsed_t::make_query (mybind_param_t **aarr, u_int n)
{
  alloc_bufs ();
  strbuf b;
  for (u_int i = 0; i < n; i++) {
    b << qry_parts[i];
    aarr[i]->to_qry (mysql, &b, &bufs[i], &lens[i]);
  }
  for (u_int i = n; i < qry_parts.size (); i++)
    b << qry_parts[i];

  return b;
}

bool
sth_parsed_t::execute2 (MYSQL_BIND *dummy, mybind_param_t **aarr, u_int n)
{

  //
  // will clear any pending fetch()'s or any unused rows in the
  // case of mysql_use_result.
  //
  // will also clear and free myres.
  //
  clearfetch ();

  if (n != n_iparam) {
    err = strbuf("cannot prepare query: wrong number of "
		 "input parameters (n = ") 
		   << n << ", n_iparam = " << n_iparam << ")";
    return false;
  }
  str q = make_query (aarr, n);

  last_qry = q;
  if (mysql_real_query (mysql, q.cstr (), q.len ()) != 0) {
    err = strbuf ("Query execution error: ") << mysql_error (mysql) << "\n";
    errno_n = mysql_errno (mysql);
    state = AMYSQL_NONE;
    return false;
  }
  state = AMYSQL_EXEC;
  return true;
}

str
sth_parsed_t::dump (mybind_param_t **aarr, u_int n)
{
  return make_query (aarr, n);
}
