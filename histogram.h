#ifndef histogram_h_
#define histogram_h_

#include "EXTERN.h"
#include "perl.h"
#include "hist_constants.h"

typedef struct {
  /* parameters */
  double min;
  double max;
  unsigned int nbins;

  /* derived */
  double width;
  double binsize;

  /* content */
  unsigned int nfills;
  double overflow;
  double underflow;
  /* derived content */
  double total;

  /* main data store */
  double* data;
  /* Exists with nbins+1 elements if we do not have constant binsize */
  double* bins;
} simple_histo_1d;


STATIC
simple_histo_1d*
histo_clone(pTHX_ simple_histo_1d* src, bool empty)
{
  simple_histo_1d* clone;
  unsigned int n = src->nbins;

  Newx(clone, 1, simple_histo_1d);

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


STATIC
SV*
histo_ary_to_AV_internal(pTHX_ unsigned int n, double* ary) {
  AV* av;
  unsigned int i;
  SV* rv;

  av = newAV();
  rv = (SV*)newRV((SV*)av);
  SvREFCNT_dec(av);

  av_fill(av, n-1);
  for (i = 0; i < n; ++i) {
    av_store(av, (int)i, newSVnv(ary[i]));
  }

  return rv;
}

STATIC
SV*
histo_data_av(pTHX_ simple_histo_1d* self) {
  return histo_ary_to_AV_internal(aTHX_ self->nbins, self->data);
}

STATIC
SV*
histo_bins_av(pTHX_ simple_histo_1d* self) {
  return histo_ary_to_AV_internal(aTHX_ self->nbins+1, self->bins);
}

STATIC
unsigned int
histo_find_bin_nonconstant_internal(double x, unsigned int nbins, double* bins)
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


STATIC
unsigned int
histo_find_bin(simple_histo_1d* self, double x)
{
  if (self->bins == NULL) {
    return( (x-self->min) / self->binsize );
  }
  else {
    return histo_find_bin_nonconstant_internal(x, self->nbins, self->bins);
  }
}

STATIC
void
histo_fill(simple_histo_1d* self, unsigned int n, double* x_in, double* w_in)
{
  unsigned int i;
  double min = self->min, max = self->max, binsize = self->binsize, x, w;
  double *data = self->data;
  double *bins = self->bins;

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
      data[histo_find_bin_nonconstant_internal(x, self->nbins, self->bins)] += w;
    }
  }
}

STATIC
simple_histo_1d*
histo_cumulative(pTHX_ simple_histo_1d* src)
{
  unsigned int i, nbins;
  simple_histo_1d* cum;
  double* cum_data;
  double total;

  nbins = src->nbins;
  cum = histo_clone(aTHX_ src, 0);
  cum_data = cum->data;
  total = cum_data[0];

  for (i = 1; i < nbins; ++i) {
    cum_data[i] += cum_data[i-1];
    total += cum_data[i];
  }
  cum->total = total;

  return cum;
}

STATIC
void
histo_multiply_constant(simple_histo_1d* self, double constant)
{
  unsigned int i, n;
  double * data;
  n = self->nbins;
  data = self->data;
  for (i = 0; i < n; ++i)
    data[i] *= constant;
  self->total *= constant;
  self->overflow *= constant;
  self->underflow *= constant;
}

#endif
