#include "histogram_agg.h"
#include "histogram.h"

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
  if (cum_hist->data[0] >= 0.5)
    median_bin = 0;
  else
    median_bin = 1+find_bin_nonconstant(0.5, cum_hist->nbins, cum_hist->data);

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

