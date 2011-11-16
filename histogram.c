#include "histogram.h"


simple_histo_1d*
histo_alloc_new_fixed_bins(pTHX_ unsigned int nbins, double min, double max)
{
  simple_histo_1d* rv;
  if (min == max)
    croak("histogram width cannot be 0");
  else if (nbins == 0)
    croak("Cannot create histogram with 0 bins");

  Newx(rv, 1, simple_histo_1d);
  if (rv == 0)
    croak("unable to malloc simple_histo_1d");

  if (min > max) {
    double tmp = min;
    min = max;
    max = tmp;
  }
  rv->nbins = nbins;
  rv->min = min;
  rv->max = max;
  rv->width = max-min;
  rv->binsize = rv->width/(double)nbins;
  rv->overflow = 0.;
  rv->underflow = 0.;
  rv->total = 0.;
  rv->nfills = 0;
  rv->bins = 0;
  rv->cumulative_hist = 0;
  Newxz(rv->data, (int)rv->nbins, double);
  return rv;
}


simple_histo_1d*
histo_clone(pTHX_ simple_histo_1d* src, bool empty)
{
  simple_histo_1d* clone;
  unsigned int n = src->nbins;

  Newx(clone, 1, simple_histo_1d);
  clone->cumulative_hist = 0;

  if (src->bins != NULL) {
    Newx(clone->bins, n+1, double);
    Copy(src->bins, clone->bins, n+1, double);
  }
  else
    clone->bins = NULL;

  if (!empty) {
    Newx(clone->data, n, double);
    Copy(src->data, clone->data, n, double);

    clone->nfills = src->nfills;
    clone->overflow = src->overflow;
    clone->underflow = src->underflow;
    clone->total = src->total;
  }
  else {
    Newxz(clone->data, n, double); /* zero it all */
    clone->nfills = 0.;
    clone->overflow = 0.;
    clone->underflow = 0.;
    clone->total = 0.;
  }

  clone->nbins = n;
  clone->min = src->min;
  clone->max = src->max;
  clone->width = src->width;
  clone->binsize = src->binsize;

  return clone;
}


unsigned int
find_bin_nonconstant(double x, unsigned int nbins, double* bins)
{
  /* TODO optimize */
  unsigned int mid;
  double mid_val;
  unsigned int imin = 0;
  unsigned int imax = nbins;
  while (1) {
    mid = imin + (imax-imin)/2;
    mid_val = bins[mid];
    if (mid_val == x)
      return mid;
    else if (mid_val > x) {
      if (mid == 0)
        return 0;
      imax = mid-1;
      if (imin > imax)
        return mid-1;
    }
    else {
      imin = mid+1;
      if (imin > imax)
        return imin-1;
    }
  }
}

/* These are left in for later optimization/testing */
/*
STATIC
unsigned int
histo_find_bin_nonconstant_internal2(double x, unsigned int nbins, double* bins)
{
  unsigned int imin = 0;
  unsigned int imax = nbins;
  unsigned int i = (unsigned int)(imax/2);
  while (1) {
    if (bins[i] >= x)
      imax = i;
    else {
      imin = i + (bins[i+1] == x);
      if (bins[i+1] >= x)
        break;
    }
    if (imin == imax)
      break;
    i = (unsigned int) ((imax+imin)/2);
  }
  return imin;
}
*/


/*
STATIC
unsigned int
histo_find_bin_nonconstant_internal3(double x, unsigned int nbins, double* bins)
{
  unsigned int mid;
  double mid_val;
  unsigned int imin = 0;
  unsigned int imax = nbins;
  while (imin <= imax) {
    mid = imin + (imax-imin)/2;
    mid_val = bins[mid];

    if (mid_val < x) {
      imin = mid + 1;
    }
    else if (mid_val > x) {
      imax = mid - 1;
    }
    else {
      return mid;
    }
  }
  return 0;
}
*/



simple_histo_1d*
histo_clone_from_bin_range(pTHX_ simple_histo_1d* src, bool empty,
                           unsigned int bin_start, unsigned int bin_end)
{
  simple_histo_1d* clone;
  unsigned int i, n = src->nbins;
  unsigned int nbinsnew = bin_end-bin_start+1;
  if (bin_start > bin_end) {
    i = bin_end;
    bin_end = bin_start;
    bin_start = i;
  }
  if (bin_end >= n)
    bin_end = n-1;

  Newx(clone, 1, simple_histo_1d);
  clone->cumulative_hist = 0;
  Newx(clone->data, nbinsnew, double);
  clone->nbins = nbinsnew;

  if (!empty) {
    clone->nfills = src->nfills;
    clone->underflow = src->underflow;
    clone->overflow = src->overflow;
    clone->total = 0.;

    for (i = 0; i < bin_start; ++i)
      clone->underflow += src->data[i];

    for (i = bin_start; i <= bin_end; ++i) {
      clone->data[i-bin_start] = src->data[i];
      clone->total += src->data[i];
    }

    for (i = bin_end+1; i < n; ++i)
      clone->overflow += src->data[i];
  }
  else { /* empty */
    clone->nfills = 0.;
    clone->overflow = 0.;
    clone->underflow = 0.;
    clone->total = 0.;
  }

  clone->binsize = src->binsize;
  if (src->bins == 0) {
    clone->bins = 0;
    clone->min = src->min + (double)bin_start * clone->binsize;
    clone->max = src->max - (double)(n - bin_end -1) * clone->binsize;
  }
  else {
    double *bins_start;
    Newx(clone->bins, nbinsnew+1, double);
    bins_start = src->bins + bin_start;
    Copy(bins_start, clone->bins, nbinsnew+1, double);
    clone->min = clone->bins[0];
    clone->max = clone->bins[nbinsnew];
  }
  clone->width = clone->max - clone->min;

  return clone;
}


unsigned int
histo_find_bin(simple_histo_1d* self, double x)
{
  if (self->bins == NULL) {
    return( (x-self->min) / self->binsize );
  }
  else {
    return find_bin_nonconstant(x, self->nbins, self->bins);
  }
}


void
histo_fill(simple_histo_1d* self, unsigned int n, const double* x_in, const double* w_in)
{
  unsigned int i;
  double min = self->min, max = self->max, binsize = self->binsize, x, w;
  double *data = self->data;
  double *bins = self->bins;

  HS_INVALIDATE_CUMULATIVE(self);

  for (i = 0; i < n; ++i) {
    self->nfills++;
    x = x_in[i];

    if (w_in == NULL) w = 1;
    else              w = w_in[i];

    if (x >= max) {
      self->overflow += w;
      continue;
    }
    else if (x < min) {
      self->underflow += w;
      continue;
    }

    self->total += w;
    if (bins == NULL) {
      data[(int)((x-min)/binsize)] += w;
    }
    else {
      data[find_bin_nonconstant(x, self->nbins, self->bins)] += w;
    }
  }
}


void
histo_fill_by_bin(simple_histo_1d* self, const unsigned int n, const int* ibin_in, const double* w_in)
{
  unsigned int i;
  int ibin;
  double w;
  double *data = self->data;
  const int nbins = (int)self->nbins;

  HS_INVALIDATE_CUMULATIVE(self);

  for (i = 0; i < n; ++i) {
    self->nfills++;
    ibin = ibin_in[i];

    if (w_in == NULL) w = 1;
    else              w = w_in[i];

    if (ibin < 0) {
      self->underflow += w;
      continue;
    }
    else if (ibin >= nbins) {
      self->overflow += w;
      continue;
    }

    self->total += w;
    data[ibin] += w;
  }
}



simple_histo_1d*
histo_cumulative(pTHX_ simple_histo_1d* src, double prenormalization)
{
  unsigned int i, nbins;
  simple_histo_1d* cum;
  double* cum_data;
  double total;

  nbins = src->nbins;
  cum = histo_clone(aTHX_ src, 0);

  if (prenormalization <= 0.) {
    cum_data = cum->data;
    total = cum_data[0];

    for (i = 1; i < nbins; ++i) {
      cum_data[i] += cum_data[i-1];
      total += cum_data[i];
    }
  }
  else {
    cum_data = cum->data;
    prenormalization = prenormalization/cum->total;
    cum_data[0] *= prenormalization;
    total = cum_data[0];

    for (i = 1; i < nbins; ++i) {
      cum_data[i] = cum_data[i]*prenormalization + cum_data[i-1];
      total += cum_data[i];
    }
  }
  cum->total = total;

  return cum;
}


void
histo_multiply_constant(simple_histo_1d* self, double constant)
{
  unsigned int i, n;
  double * data;
  HS_INVALIDATE_CUMULATIVE(self); /* Rescaling invalidates the cache. */
  n = self->nbins;
  data = self->data;
  for (i = 0; i < n; ++i)
    data[i] *= constant;
  self->total *= constant;
  self->overflow *= constant;
  self->underflow *= constant;
}

#define MY_FLOAT_EQ_EPS(a, b, eps) ((a) + (eps) > (b) && (a) - (eps) < (b))
#define MY_FLOAT_EQ(a, b) (MY_FLOAT_EQ_EPS(a, b, 1.e-12))

#define MY_FLOAT_NE_EPS(a, b, eps) ((a) + (eps) <= (b) || (a) - (eps) >= (b))
#define MY_FLOAT_NE(a, b) (MY_FLOAT_NE_EPS(a, b, 1.e-12))

bool
histo_add_histogram(simple_histo_1d* target, simple_histo_1d* to_add)
{
  unsigned int i, n;
  double *d_target;
  double *d_to_add;

  /* we're optimistic */
  n = target->nbins;

  if (target->bins == NULL) {
    /* fixed bins */
    if ( to_add->bins != NULL
         || target->nbins != target->nbins
         || MY_FLOAT_NE(target->min, to_add->min)
         || MY_FLOAT_NE(target->max, to_add->max) )
      return 0;
  }
  else { /* variable bins */
    if ( to_add->bins == NULL 
          || target->nbins != to_add->nbins)
      return 0;

    /* abuse double*'s a bit */
    d_target = target->bins;
    d_to_add = to_add->bins;

    for (i = 0; i < n; ++i) {
      if (MY_FLOAT_NE(d_target[i], d_to_add[i])) {
        printf("%u\n", i);
        return 0;
      }
    }
  }

  HS_INVALIDATE_CUMULATIVE(target); /* Adding invalidates the cache. */

  d_target = target->data;
  d_to_add = to_add->data;

  for (i = 0; i < n; ++i)
    d_target[i] += d_to_add[i];

  target->total     += to_add->total;
  target->overflow  += to_add->overflow;
  target->underflow += to_add->underflow;
  target->nfills    += to_add->nfills;

  return 1;
}

