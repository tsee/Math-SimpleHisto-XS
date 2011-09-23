#ifndef histogram_h_
#define histogram_h_

#include "EXTERN.h"
#include "perl.h"
#include "hist_constants.h"

struct simple_histo_1d_struct {
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

  /* Optional ptr to cumulative histo.
   * If this isn't 0, we need to deallocate in the parent
   * object's DESTROY. This isn't serialized nor cloned
   * ever since it can be recalculated.
   * Needs to be invalidated using HS_INVALIDATE_CUMULATIVE
   * on almost every operation on the histogram!
   * Not currently invalidated when setting the under-/overflow.
   */
  /* The stored cumulative hist MUST be normalized in such a way
   * that the last bin content is == 1. This is like ->cumulative(1) */
  struct simple_histo_1d_struct* cumulative_hist;
};

typedef struct simple_histo_1d_struct simple_histo_1d;

/* deallocates a histogram. Requires a THX */
#define HS_DEALLOCATE(hist)               \
    STMT_START {                          \
      simple_histo_1d* histptr = (hist);  \
      Safefree( (void*)histptr->data );   \
      if (histptr->bins != NULL)          \
        Safefree(histptr->bins);          \
      Safefree( (void*)histptr );         \
    } STMT_END


/* deallocates the cumulative histogram if necessary. Requires a THX */
#define HS_INVALIDATE_CUMULATIVE(self)          \
    STMT_START {                                \
      if ((self)->cumulative_hist) {            \
        HS_DEALLOCATE((self)->cumulative_hist); \
        (self)->cumulative_hist = 0;            \
      }                                         \
    } STMT_END

/* allocates the cumulative histogram if necessary. Requires a THX */
#define HS_ASSERT_CUMULATIVE(self)                                \
    STMT_START {                                                  \
      simple_histo_1d* selfptr = (self);                          \
      if (!(selfptr->cumulative_hist))                            \
        self->cumulative_hist = histo_cumulative(aTHX_ self, 1.); \
    } STMT_END


simple_histo_1d*
histo_alloc_new_fixed_bins(pTHX_ unsigned int nbins, double min, double max);

simple_histo_1d*
histo_clone(pTHX_ simple_histo_1d* src, bool empty);

simple_histo_1d*
histo_clone_from_bin_range(pTHX_ simple_histo_1d* src, bool empty,
                           unsigned int bin_start, unsigned int bin_end);

unsigned int
histo_find_bin_nonconstant_internal(double x, unsigned int nbins, double* bins);

unsigned int
histo_find_bin(simple_histo_1d* self, double x);

void
histo_fill(simple_histo_1d* self, unsigned int n, double* x_in, double* w_in);

/* Calculates the cumulative histogram of the source histogram.
 * If the prenormalization is > 0, the output histogram will be
 * normalized to that value before calculating the cumulative. */
simple_histo_1d*
histo_cumulative(pTHX_ simple_histo_1d* src, double prenormalization);

void
histo_multiply_constant(simple_histo_1d* self, double constant);

#endif
