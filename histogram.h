#ifndef histogram_h_
#define histogram_h_

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
} simple_histo_1d;


STATIC
simple_histo_1d*
histo_clone(pTHX_ simple_histo_1d* src, bool empty)
{
  simple_histo_1d* clone;
  double *data, *data_src;

  data_src = src->data;
  Newx(clone, 1, simple_histo_1d);

  if (!empty) {
    unsigned int i;
    Newx(data, src->nbins, double);
    for (i = 0; i < src->nbins; ++i)
      data[i] = data_src[i];
    clone->nfills = src->nfills;
    clone->overflow = src->overflow;
    clone->underflow = src->underflow;
    clone->total = src->total;
  }
  else {
    Newxz(data, src->nbins, double); /* zero it all */
    clone->nfills = 0.;
    clone->overflow = 0.;
    clone->underflow = 0.;
    clone->total = 0.;
  }
  clone->data = data;

  clone->nbins = src->nbins;
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
void
histo_fill(simple_histo_1d* self, unsigned int n, double* x_in, double* w_in)
{
  unsigned int i;
  double min = self->min, max = self->max, binsize = self->binsize, x, w;
  double *data = self->data;

  for (i = 0; i < n; ++i) {
    self->nfills++;
    x = x_in[i];
    if (w_in == NULL)
      w = 1;
    else
      w = w_in[i];
    if (x >= max) {
      self->overflow += w;
      continue;
    }
    x -= min;
    if (x < 0) {
      self->underflow += w;
      continue;
    }
    self->total += w;
    data[(int)(x/binsize)] += w;
  }
}

#endif
