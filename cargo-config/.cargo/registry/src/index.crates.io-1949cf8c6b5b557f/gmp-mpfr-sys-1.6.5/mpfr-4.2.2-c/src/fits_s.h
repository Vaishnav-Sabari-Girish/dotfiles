/* mpfr_fits_*_p -- test whether an mpfr fits a C signed type.

Copyright 2003-2025 Free Software Foundation, Inc.
Contributed by the Pascaline and Caramba projects, INRIA.

This file is part of the GNU MPFR Library.

The GNU MPFR Library is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 3 of the License, or (at your
option) any later version.

The GNU MPFR Library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public License
along with the GNU MPFR Library; see the file COPYING.LESSER.
If not, see <https://www.gnu.org/licenses/>. */

#include "mpfr-impl.h"

/* The original version of this file came from GMP's mpf/fits_s.h;
   it has been adapted for MPFR.  In particular, the result can be
   rounded away from zero. */

int
FUNCTION (mpfr_srcptr f, mpfr_rnd_t rnd)
{
  mpfr_flags_t saved_flags;
  mpfr_exp_t e;
  int prec;
  mpfr_t x;
  int neg;
  int res;

  if (MPFR_UNLIKELY (MPFR_IS_SINGULAR (f)))
    /* Zero always fit */
    return MPFR_IS_ZERO (f) ? 1 : 0;

  /* now it fits if either
     (a) MINIMUM <= f <= MAXIMUM
     (b) or MINIMUM <= round(f, prec(slong), rnd) <= MAXIMUM */

  e = MPFR_GET_EXP (f);
  if (e < 1)
    return 1; /* |f| < 1: always fits */

  neg = MPFR_IS_NEG (f);

  /* let EXTREMUM be MAXIMUM if f > 0, and MINIMUM if f < 0 */

  /* first compute prec(EXTREMUM), this could be done at configure time,
     but the result can depend on neg (the loop is moved inside the "if"
     to give the compiler a better chance to compute prec statically) */
  if (neg)
    {
      unsigned TYPE s;
      /* In C90, the division on negative integers isn't well-defined. */
      s = SAFE_ABS (unsigned TYPE, MINIMUM);
      for (prec = 0; s != 0; s /= 2, prec ++);
    }
  else
    {
      TYPE s;
      s = MAXIMUM;
      for (prec = 0; s != 0; s /= 2, prec ++);
    }

  /* EXTREMUM needs prec bits, i.e. 2^(prec-1) <= |EXTREMUM| < 2^prec */

   /* if e <= prec - 1, then f < 2^(prec-1) <= |EXTREMUM| */
  if (e <= prec - 1)
    return 1;

  /* if e >= prec + 1, then f >= 2^prec > |EXTREMUM| */
  if (e >= prec + 1)
    return 0;

  MPFR_ASSERTD (e == prec);

  /* hard case: first round to prec bits, then check */
  saved_flags = __gmpfr_flags;
  mpfr_init2 (x, prec);
  /* for RNDF, it suffices to check it fits when rounded away from zero */
  mpfr_set (x, f, (rnd == MPFR_RNDF) ? MPFR_RNDA : rnd);
  /* Warning! Due to the rounding, x can be an infinity. Here we use
     the fact that singular numbers have a special exponent field,
     thus well-defined and different from e, in which case this means
     that the number does not fit. That's why we use MPFR_EXP, not
     MPFR_GET_EXP. */
  res = neg ? (mpfr_cmp_si (x, MINIMUM) >= 0) : (MPFR_EXP (x) == e);
  mpfr_clear (x);
  __gmpfr_flags = saved_flags;
  return res;
}
