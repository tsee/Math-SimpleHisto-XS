#ifndef histogram_agg_h_
#define histogram_agg_h_

#include "histogram.h"

/* Calculate the median of a histogram. */
double
histo_median(pTHX_ simple_histo_1d* self);

/* Calculate the mean of a histogram. */
double
histo_mean(pTHX_ simple_histo_1d* self);

#endif

