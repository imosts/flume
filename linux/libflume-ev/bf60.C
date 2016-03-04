/* -*-c++-*- */
/* $Id: bf60.c,v 1.2 2005-04-14 18:52:41 dziegler Exp $ */

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

/* This code is derived from a public domain implementation of
 * blowfish found on the net.  I don't remember the original author.
 * By this point, the code has probably been hacked beyond
 * recognition, anyway.  */

#include "flume_bf60.h"
#include "blowfish_data.h"

inline u_int32_t
bf_F (const bf_ctx *bfc, u_int32_t x)
{
  return ((bfc->S[0][x >> 24] + bfc->S[1][x >> 16 & 0xff])
	  ^ bfc->S[2][x >> 8 & 0xff]) + bfc->S[3][x & 0xff];
}

void
bf_encipher (const bf_ctx *bfc, u_int32_t *xl, u_int32_t *xr)
{
  u_int32_t Xl = *xl;
  u_int32_t Xr = *xr;
  int i;

  for (i = 0; i < BF_N;) {
    Xl ^= bfc->P[i++];
    Xr ^= bf_F (bfc, Xl);

    Xr ^= bfc->P[i++];
    Xl ^= bf_F (bfc, Xr);
  }

  *xr = Xl ^ bfc->P[BF_N];
  *xl = Xr ^ bfc->P[BF_N + 1];
}

void
bf_decipher (const bf_ctx *bfc, u_int32_t *xl, u_int32_t *xr)
{
  u_int32_t Xl = *xl;
  u_int32_t Xr = *xr;
  int i;

  for (i = BF_N + 1; i > 1;) {
    Xl ^= bfc->P[i--];
    Xr ^= bf_F (bfc, Xl);

    Xr ^= bfc->P[i--];
    Xl ^= bf_F (bfc, Xr);
  }

  *xr = Xl ^ bfc->P[1];
  *xl = Xr ^ bfc->P[0];
}

void
bf_initstate (bf_ctx *bfc)
{
  const u_int32_t *idp = pihex;
  int i, j;

  /* Load up the initialization data */
  for (i = 0; i < BF_N + 2; ++i)
    bfc->P[i] = *idp++;
  for (i = 0; i < 4; ++i)
    for (j = 0; j < 256; ++j)
      bfc->S[i][j] = *idp++;
}

void
bf_keysched (bf_ctx *bfc, const void *_key, size_t keybytes)
{
  const u_int8_t *key = (const u_int8_t *) (_key);
  unsigned i, keypos;
  u_int32_t datal, datar;

  if (keybytes > 0)
    for (i = 0, keypos = 0; i < BF_N + 2; ++i) {
      u_int32_t data = 0;
      int k;
      for (k = 0; k < 4; ++k) {
	data = (data << 8) | key[keypos++];
	if (keypos >= keybytes)
	  keypos = 0;
      }
      bfc->P[i] ^= data;
    }

  datal = 0;
  datar = 0;

  for (i = 0; i < BF_N + 2; i += 2) {
    bf_encipher (bfc, &datal, &datar);
    bfc->P[i] = datal;
    bfc->P[i + 1] = datar;
  }

  for (i = 0; i < 4; ++i) {
    int j;
    for (j = 0; j < 256; j += 2) {
      bf_encipher (bfc, &datal, &datar);
      bfc->S[i][j] = datal;
      bfc->S[i][j + 1] = datar;
    }
  }
}

void
bf_setkey (bf_ctx *bfc, const void *key, size_t keybytes)
{
  bf_initstate (bfc);
  bf_keysched (bfc, key, keybytes);
}

u_int64_t
bf60_encipher (bf_ctx *bfc, u_int64_t val)
{
  u_int32_t Xl = (val >> 30) & 0x3fffffff;
  u_int32_t Xr = val & 0x3fffffff;
  int i;

  for (i = 0; i < BF_N;) {
    Xl ^= bfc->P[i++] & 0x3fffffff;
    Xr ^= bf_F (bfc, Xl) & 0x3fffffff;

    Xr ^= bfc->P[i++] & 0x3fffffff;
    Xl ^= bf_F (bfc, Xr) & 0x3fffffff;
  }

  Xl ^= bfc->P[BF_N] & 0x3fffffff;
  Xr ^= bfc->P[BF_N + 1] & 0x3fffffff;
  return (u_int64_t) Xr << 30 | Xl;
}

u_int64_t
bf60_decipher (bf_ctx *bfc, u_int64_t val)
{
  u_int32_t Xl = (val >> 30) & 0x3fffffff;
  u_int32_t Xr = val & 0x3fffffff;
  int i;

  for (i = BF_N + 1; i > 1;) {
    Xl ^= bfc->P[i--] & 0x3fffffff;
    Xr ^= bf_F (bfc, Xl) & 0x3fffffff;

    Xr ^= bfc->P[i--] & 0x3fffffff;
    Xl ^= bf_F (bfc, Xr) & 0x3fffffff;
  }

   Xl ^= bfc->P[1] & 0x3fffffff;
   Xr ^= bfc->P[0] & 0x3fffffff;
   return (u_int64_t) Xr << 30 | Xl;
}

u_int64_t
bf61_encipher (bf_ctx *bfc, u_int64_t val)
{
  u_int32_t Xl = (val >> 29) & 0x3fffffff;
  u_int32_t Xr = val & 0x7fffffff;
  int i;

  for (i = 0; i < BF_N;) {
    Xl ^= bfc->P[i++] & 0x3fffffff;
    Xr ^= bf_F (bfc, Xl) & 0x7fffffff;

    Xr ^= bfc->P[i++] & 0x7fffffff;
    Xl ^= bf_F (bfc, Xr) & 0x3fffffff;
  }

  Xl ^= bfc->P[BF_N] & 0x3fffffff;
  Xr ^= bfc->P[BF_N + 1] & 0x7fffffff;
  return (u_int64_t) Xr << 30 | Xl;
}

u_int64_t
bf61_decipher (bf_ctx *bfc, u_int64_t val)
{
  u_int32_t Xl = (val >> 30) & 0x7fffffff;
  u_int32_t Xr = val & 0x3fffffff;
  int i;

  for (i = BF_N + 1; i > 1;) {
    Xl ^= bfc->P[i--] & 0x7fffffff;
    Xr ^= bf_F (bfc, Xl) & 0x3fffffff;

    Xr ^= bfc->P[i--] & 0x3fffffff;
    Xl ^= bf_F (bfc, Xr) & 0x7fffffff;
  }

   Xl ^= bfc->P[1] & 0x7fffffff;
   Xr ^= bfc->P[0] & 0x3fffffff;
   return (u_int64_t) Xr << 31 | Xl;
}

u_int64_t
bf64_encipher (bf_ctx *bfc, u_int64_t val) {
  u_int32_t Xl = val >> 32;
  u_int32_t Xr = val;
  int i;

  for (i = 0; i < BF_N;) {
    Xl ^= bfc->P[i++];
    Xr ^= bf_F (bfc, Xl);

    Xr ^= bfc->P[i++];
    Xl ^= bf_F (bfc, Xr);
  }

  Xl ^= bfc->P[BF_N];
  Xr ^= bfc->P[BF_N + 1];
  return (u_int64_t) Xr << 32 | Xl;
}

u_int64_t
bf64_decipher (bf_ctx *bfc, u_int64_t val) {
  u_int32_t Xl = val >> 32;
  u_int32_t Xr = val;
  int i;

  for (i = BF_N + 1; i > 1;) {
    Xl ^= bfc->P[i--];
    Xr ^= bf_F (bfc, Xl);

    Xr ^= bfc->P[i--];
    Xl ^= bf_F (bfc, Xr);
  }

	Xl ^= bfc->P[1];
	Xr ^= bfc->P[0];
	return (u_int64_t) Xr << 32 | Xl;
}

#if 0
#include <stdio.h>
int
main (int argc, char **argv)
{
  char key[] = "should be random";
  bf_ctx bfc;
  u_int64_t i;

  bf_setkey (&bfc, key, sizeof (key));
  //for (i = 0x1ffffffffffffff0ULL; i < 0x1ffffffffffffff0ULL + 100; i++) {
  for (i = 0; i < 100; i++) {
    u_int64_t j = bf61_encipher (&bfc, i);
    printf ("%016qx E-> %016qx D-> %016qx\n", i, j, bf61_decipher (&bfc, j));
  }
}
#endif
