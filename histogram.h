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

  clone->bins = src->bins;
  if (src->bins != NULL) {
    Newx(clone->bins, n+1, double);
    Copy(src->bins, clone->bins, n+1, double);
  }

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

STATIC
SV*
histo_data_av(pTHX_ simple_histo_1d* self) {
  AV* av;
  int i, n;
  double* data;
  SV* rv;

  av = newAV();
  rv = (SV*)newRV((SV*)av);
  SvREFCNT_dec(av);

  n = self->nbins;
  av_fill(av, n-1);
  data = self->data;
  for (i = 0; i < n; ++i) {
    av_store(av, i, newSVnv(data[i]));
  }

  return rv;
}

STATIC
unsigned int
histo_find_bin_nonconstant_internal(double x, unsigned int nbins, double* bins)
{
  /* TODO optimize */
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

#endif
