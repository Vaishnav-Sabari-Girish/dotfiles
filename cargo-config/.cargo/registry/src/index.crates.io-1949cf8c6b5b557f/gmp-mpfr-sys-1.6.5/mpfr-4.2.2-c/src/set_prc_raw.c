/* mpfr_set_prec_raw -- reset the precision of a floating-point number

Copyright 2000-2001, 2004, 2006-2025 Free Software Foundation, Inc.
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

void
mpfr_set_prec_raw (mpfr_ptr x, mpfr_prec_t p)
{
  MPFR_ASSERTN (MPFR_PREC_COND (p));
  MPFR_ASSERTN (p <= (mpfr_prec_t) MPFR_GET_ALLOC_SIZE(x) * GMP_NUMB_BITS);
  MPFR_PREC(x) = p;
}
