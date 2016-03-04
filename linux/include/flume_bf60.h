/* -*-c++-*- */
/* $Id: bf60.h,v 1.2 2005-04-14 18:52:41 dziegler Exp $ */

/*
 *
 * Copyright (C) 1998 David Mazieres (dm@uun.org)
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


#ifndef _BF60_H_
#define _BF60_H_

#define BF_N 16

#include "async.h"

struct bf_ctx {
  u_int32_t P[BF_N + 2];
  u_int32_t S[4][256];
};
typedef struct bf_ctx bf_ctx;

void bf_setkey (bf_ctx *bfc, const void *key, size_t keybytes);
void bf_encipher (const bf_ctx *bfc, u_int32_t *xl, u_int32_t *xr);
void bf_decipher (const bf_ctx *bfc, u_int32_t *xl, u_int32_t *xr);
u_int64_t bf60_encipher (bf_ctx *bfc, u_int64_t val);
u_int64_t bf60_decipher (bf_ctx *bfc, u_int64_t val);
u_int64_t bf61_encipher (bf_ctx *bfc, u_int64_t val);
u_int64_t bf61_decipher (bf_ctx *bfc, u_int64_t val);
u_int64_t bf64_encipher (bf_ctx *bfc, u_int64_t val);
u_int64_t bf64_decipher (bf_ctx *bfc, u_int64_t val);

#endif /* _BF60_H_ */
