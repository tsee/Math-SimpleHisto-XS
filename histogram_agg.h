#ifndef histogram_agg_h_
#define histogram_agg_h_

#include "histogram.h"

STATIC
double
histo_median(pTHX_ simple_histo_1d* self)
{
  simple_histo_1d* cum_hist;
  double* data;
  unsigned int i, n, median_bin;
  double sum_below, sum_above, x;

  HS_ASSERT_CUMULATIVE(self);
  cum_hist = self->cumulative_hist;
  data = self->data;
  n = self->nbins;
  /* The bin which is >= 0.5, thus the +1 */
  median_bin = 1+histo_find_bin_nonconstant_internal(0.5, cum_hist->nbins, cum_hist->data);

  sum_below = 0.;
  for (i = 0; i < median_bin; ++i)
    sum_below += data[i];
  sum_above = 0.;
  for (i = median_bin+1; i < n; ++i)
    sum_above += data[i];
  /* The fraction of the median bin that is below the estimated median */
  x = 0.5 * ( (sum_above-sum_below)/data[median_bin] + 1 );

  /* median estimate = lower boundary of median bin + x * median bin size */
  if (self->bins == 0)
    return self->min + ( (double)median_bin + x ) * self->binsize;
  else /* variable bin sizes */
    return self->bins[median_bin] + (self->bins[median_bin+1] - self->bins[median_bin]) * x;
}

#endif

