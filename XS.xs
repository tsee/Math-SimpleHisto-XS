#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "histogram.h"
#include "const-c.inc"

#define HS_ASSERT_BIN_RANGE(self, i) STMT_START {                                     \
  if (/* i < 0 || */ i >= self->nbins) {                                              \
    croak("Bin %u outside histogram range (highest bin index is %u", i, self->nbins); \
  } } STMT_END

#define HS_CLONE_GET_CLASS(classname, src, where) STMT_START {                        \
  if (!sv_isobject(src))                                                              \
    croak("Cannot call ##where##() on non-object");                                   \
  classname = sv_reftype(SvRV(src), TRUE);                                            \
  if ( !sv_isobject(src) || (SvTYPE(SvRV(src)) != SVt_PVMG) )                         \
    croak( "%s::##where##() -- self is not a blessed SV reference", classname);       \
  } STMT_END


MODULE = Math::SimpleHisto::XS    PACKAGE = Math::SimpleHisto::XS

REQUIRE: 2.2201

INCLUDE: const-xs.inc

simple_histo_1d*
_new_histo(CLASS, nbins, min, max)
    char *CLASS
    unsigned int nbins;
    double min;
    double max;
  CODE:
    if (min == max) {
      croak("histogram width cannot be 0");
    }
    else if (nbins == 0) {
      croak("Cannot create histogram with 0 bins");
    }
    Newx(RETVAL, 1, simple_histo_1d);
    if( RETVAL == NULL ){
      warn("unable to malloc simple_histo_1d");
      XSRETURN_UNDEF;
    }
    if (min > max) {
      double tmp = min;
      min = max;
      max = tmp;
    }
    RETVAL->nbins = nbins;
    RETVAL->min = min;
    RETVAL->max = max;
    RETVAL->width = max-min;
    RETVAL->binsize = RETVAL->width/(double)nbins;
    RETVAL->overflow = 0.;
    RETVAL->underflow = 0.;
    RETVAL->total = 0.;
    RETVAL->nfills = 0;
    RETVAL->bins = NULL;
    Newxz(RETVAL->data, (int)RETVAL->nbins, double);
  OUTPUT:
    RETVAL

simple_histo_1d*
_new_histo_bins(CLASS, bins)
    char *CLASS
    AV* bins;
  PREINIT:
    unsigned int nbins, i;
    double* bins_ary;
    SV** elem;
  CODE:
    nbins = av_len(bins); /* av_len is like $#{}, but bins has nbins+1 elements */
    Newx(RETVAL, 1, simple_histo_1d);
    if( RETVAL == NULL ){
      warn("unable to malloc simple_histo_1d");
      XSRETURN_UNDEF;
    }

    RETVAL->nbins = nbins;
    Newx(bins_ary, nbins+1, double);
    RETVAL->bins = bins_ary;

    for (i = 0; i <= nbins; ++i) {
      elem = av_fetch(bins, i, 0);
      if (elem == NULL) {
        croak("Shouldn't happen");
      }
      bins_ary[i] = SvNV(*elem);
      if (i != 0 && bins_ary[i-1] >= bins_ary[i]) {
        Safefree(bins_ary);
        Safefree(RETVAL);
        croak("Bin edge %u is higher than bin edge %u. Must be strictly monotonically increasing", i-1, i);
      }
    }
    RETVAL->min = bins_ary[0];
    RETVAL->max = bins_ary[nbins];
    RETVAL->width = RETVAL->max - RETVAL->min;
    RETVAL->binsize = 0.;
    RETVAL->overflow = 0.;
    RETVAL->underflow = 0.;
    RETVAL->total = 0.;
    RETVAL->nfills = 0;
    Newxz(RETVAL->data, (int)RETVAL->nbins, double);
  OUTPUT:
    RETVAL


void
DESTROY(self)
    simple_histo_1d* self
  CODE:
    Safefree( (void*)self->data );
    if (self->bins != NULL)
      Safefree(self->bins);
    Safefree( (void*)self );

simple_histo_1d*
clone(self)
    SV* self
  PREINIT:
    char* CLASS;
  INIT:
    HS_CLONE_GET_CLASS(CLASS, self, clone);
  CODE:
    RETVAL = histo_clone(aTHX_ (simple_histo_1d*)SvIV((SV*)SvRV(self)), 0);
  OUTPUT: RETVAL


simple_histo_1d*
new_alike(self)
    SV* self
  PREINIT:
    char* CLASS;
  INIT:
    HS_CLONE_GET_CLASS(CLASS, self, new_alike);
  CODE:
    RETVAL = histo_clone(aTHX_ (simple_histo_1d*)SvIV((SV*)SvRV(self)), 1);
  OUTPUT: RETVAL


void
normalize(self, normalization = 1.)
    simple_histo_1d* self
    double normalization
  PREINIT:
    unsigned int i, n;
    double* data;
    double factor;
  CODE:
    if (normalization <= 0.) {
      croak("Cannot normalize to %f", normalization);
    }
    if (self->total == 0.) {
      croak("Cannot normalize histogram without data");
    }
    n = self->nbins;
    data = self->data;
    factor = normalization / self->total;
    for (i = 0; i < n; ++i)
      data[i] *= factor;
    self->total = normalization;
    self->overflow *= factor;
    self->underflow *= factor;


void
fill(self, ...)
    simple_histo_1d* self
  CODE:
    if (items == 2) {
      SV* const x_tmp = ST(1);
      SvGETMAGIC(x_tmp);
      if (SvROK(x_tmp) && SvTYPE(SvRV(x_tmp)) == SVt_PVAV) {
        int i, n;
        SV** sv;
        double* x;
        AV* av = (AV*)SvRV(x_tmp);
        n = av_len(av);
        Newx(x, n+1, double);
        for (i = 0; i <= n; ++i) {
          sv = av_fetch(av, i, 0);
          if (sv == NULL) {
            Safefree(x);
            croak("Shouldn't happen");
          }
          x[i] = SvNV(*sv);
        }
        histo_fill(self, n+1, x, NULL);
        Safefree(x);
      }
      else {
        double x = SvNV(ST(1));
        histo_fill(self, 1, &x, NULL);
      }
    }
    else if (items == 3) {
      SV* const x_tmp = ST(1);
      SV* const w_tmp = ST(2);
      SvGETMAGIC(x_tmp);
      SvGETMAGIC(w_tmp);
      if (SvROK(x_tmp) && SvTYPE(SvRV(x_tmp)) == SVt_PVAV) {
        int i, n;
        SV** sv;
        double *x, *w;
        AV *xav, *wav;
        if (!SvROK(w_tmp) || SvTYPE(SvRV(x_tmp)) != SVt_PVAV) {
          croak("Need array of weights if using array of x values");
        }
        xav = (AV*)SvRV(x_tmp);
        wav = (AV*)SvRV(w_tmp);
        n = av_len(xav);
        if (av_len(wav) != n) {
          croak("x and w array lengths differ");
        }

        Newx(x, n+1, double);
        Newx(w, n+1, double);
        for (i = 0; i <= n; ++i) {
          sv = av_fetch(xav, i, 0);
          if (sv == NULL) {
            Safefree(x);
            Safefree(w);
            croak("Shouldn't happen");
          }
          x[i] = SvNV(*sv);

          sv = av_fetch(wav, i, 0);
          if (sv == NULL) {
            Safefree(x);
            Safefree(w);
            croak("Shouldn't happen");
          }
          w[i] = SvNV(*sv);
        }
        histo_fill(self, n+1, x, w);
        Safefree(x);
        Safefree(w);
      }
      else {
        double x = SvNV(ST(1));
        double w = SvNV(ST(2));
        histo_fill(self, 1, &x, &w);
      }
    }
    else {
      croak("Invalid number of arguments to fill(self, ...)");
    }


double
min(self)
    simple_histo_1d* self
  CODE:
    RETVAL = self->min;
  OUTPUT: RETVAL

double
max(self)
    simple_histo_1d* self
  CODE:
    RETVAL = self->max;
  OUTPUT: RETVAL

double
width(self)
    simple_histo_1d* self
  CODE:
    RETVAL = self->width;
  OUTPUT: RETVAL

double
overflow(self)
    simple_histo_1d* self
  CODE:
    RETVAL = self->overflow;
  OUTPUT: RETVAL

double
underflow(self)
    simple_histo_1d* self
  CODE:
    RETVAL = self->underflow;
  OUTPUT: RETVAL

double
total(self)
    simple_histo_1d* self
  CODE:
    RETVAL = self->total;
  OUTPUT: RETVAL

unsigned int
nbins(self)
    simple_histo_1d* self
  CODE:
    RETVAL = self->nbins;
  OUTPUT: RETVAL

double
binsize(self, ibin = 0)
    simple_histo_1d* self
    unsigned int ibin
  CODE:
    HS_ASSERT_BIN_RANGE(self, ibin);
    if (self->bins == NULL)
      RETVAL = self->binsize;
    else
      RETVAL = self->bins[ibin+1] - self->bins[ibin];
  OUTPUT: RETVAL

unsigned int
nfills(self)
    simple_histo_1d* self
  CODE:
    RETVAL = self->nfills;
  OUTPUT: RETVAL


void
all_bin_contents(self)
    simple_histo_1d* self
  PREINIT:
    SV* rv;
  PPCODE:
    rv = histo_data_av(aTHX_ self);
    XPUSHs(sv_2mortal(rv));

void
set_all_bin_contents(self, new_data)
    simple_histo_1d* self
    AV* new_data
  PREINIT:
    unsigned int n, i;
    double* data;
    SV** elem;
  CODE:
    n = self->nbins;
    if ((unsigned int)(av_len(new_data)+1) != n) {
      croak("Length of new data is %u, size of histogram is %u. That doesn't work.", (unsigned int)(av_len(new_data)+1), n);
    }
    data = self->data;
    for (i = 0; i < n; ++i) {
      elem = av_fetch(new_data, i, 0);
      if (elem == NULL) {
        croak("Shouldn't happen");
      }
      self->total -= data[i];
      data[i] = SvNV(*elem);
      self->total += data[i];
    }

double
bin_content(self, ibin)
    simple_histo_1d* self
    unsigned int ibin
  CODE:
    HS_ASSERT_BIN_RANGE(self, ibin);
    RETVAL = self->data[ibin];
  OUTPUT: RETVAL


void
bin_centers(self)
    simple_histo_1d* self
  PREINIT:
    AV* av;
    SV* rv;
    int i, n;
    double x;
  PPCODE:
    av = newAV();
    rv = (SV*)newRV((SV*)av);
    SvREFCNT_dec(av);
    n = self->nbins;
    av_fill(av, n-1);
    if (self->bins == NULL) {
      double binsize = self->binsize;
      x = self->min + 0.5*binsize;
      for (i = 0; i < n; ++i) {
        av_store(av, i, newSVnv(x));
        x += binsize;
      }
    }
    else {
      double* bins = self->bins;
      for (i = 0; i < n; ++i) {
        x = 0.5*(bins[i] + bins[i+1]);
        av_store(av, i, newSVnv(x));
      }
    }
    XPUSHs(sv_2mortal(rv));


double
bin_center(self, ibin)
    simple_histo_1d* self
    unsigned int ibin
  CODE:
    HS_ASSERT_BIN_RANGE(self, ibin);
    if (self->bins == NULL)
      RETVAL = self->min + ((double)ibin + 0.5) * self->binsize;
    else
      RETVAL = 0.5*(self->bins[ibin] + self->bins[ibin+1]);
  OUTPUT: RETVAL


double
bin_lower_boundary(self, ibin)
    simple_histo_1d* self
    unsigned int ibin
  CODE:
    HS_ASSERT_BIN_RANGE(self, ibin);
    if (self->bins == NULL)
      RETVAL = self->min + (double)ibin * self->binsize;
    else
      RETVAL = self->bins[ibin];
  OUTPUT: RETVAL


double
bin_upper_boundary(self, ibin)
    simple_histo_1d* self
    unsigned int ibin
  CODE:
    if (/*ibin < 0 ||*/ ibin >= self->nbins)
      croak("Bin outside histogram range");
    if (self->bins == NULL)
      RETVAL = self->min + ((double)ibin + 1) * self->binsize;
    else
      RETVAL = self->bins[ibin+1];
  OUTPUT: RETVAL


void
bin_lower_boundaries(self)
    simple_histo_1d* self
  PREINIT:
    AV* av;
    SV* rv;
    int i, n;
  PPCODE:
    av = newAV();
    rv = (SV*)newRV((SV*)av);
    SvREFCNT_dec(av);
    n = self->nbins;
    av_fill(av, n-1);
    if (self->bins == NULL) {
      double binsize = self->binsize;
      double x = self->min;
      for (i = 0; i < n; ++i) {
        av_store(av, i, newSVnv(x));
        x += binsize;
      }
    }
    else {
      double* bins = self->bins;
      for (i = 0; i < n; ++i) {
        av_store(av, i, newSVnv(bins[i]));
      }
    }
    XPUSHs(sv_2mortal(rv));


void
bin_upper_boundaries(self)
    simple_histo_1d* self
  PREINIT:
    AV* av;
    SV* rv;
    int i, n;
    double x, binsize;
  PPCODE:
    av = newAV();
    rv = (SV*)newRV((SV*)av);
    SvREFCNT_dec(av);
    n = self->nbins;
    av_fill(av, n-1);
    if (self->bins == NULL) {
      binsize = self->binsize;
      x = self->min;
      for (i = 0; i < n; ++i) {
        x += binsize;
        av_store(av, i, newSVnv(x));
      }
    }
    else {
      double* bins = self->bins;
      for (i = 0; i < n; ++i) {
        av_store(av, i, newSVnv(bins[i+1]));
      }
    }
    XPUSHs(sv_2mortal(rv));


unsigned int
find_bin(self, x)
    simple_histo_1d* self
    double x
  CODE:
    if (x >= self->max || x < self->min) {
      XSRETURN_UNDEF;
    }
    RETVAL = histo_find_bin(self, x);
  OUTPUT: RETVAL


void
set_bin_content(self, ibin, content)
    simple_histo_1d* self
    unsigned int ibin
    double content
  PPCODE:
    HS_ASSERT_BIN_RANGE(self, ibin);
    self->total += content - self->data[ibin];
    self->data[ibin] = content;

void
set_underflow(self, content)
    simple_histo_1d* self
    double content
  PPCODE:
    self->underflow = content;

void
set_overflow(self, content)
    simple_histo_1d* self
    double content
  PPCODE:
    self->overflow = content;


void
set_nfills(self, nfills)
    simple_histo_1d* self
    unsigned int nfills
  PPCODE:
    self->nfills = nfills;


double
integral(self, from, to, type = 0)
    simple_histo_1d* self
    double from
    double to
    int type
  PREINIT:
    double* data;
    unsigned int i, n;
    double binsize;
    bool invert = 0;
  CODE:
    /* TODO nonconstant bins */
    if (from > to) {
      binsize = from; /* abuse as temp var */
      from = to;
      to = binsize;
      invert = 1;
    }

    data = self->data;
    binsize = self->binsize;

    /* FIXME handle both to/from being off limits on the same side*/
    if (to >= self->max)
      to = self->max;
    if (from < self->min)
      from = self->min;

    /*for (i = 1; i < self->nbins; ++i)
      printf("%u: %f ", i, data[i]);
    printf("\n");
    */

    switch(type) {
      case INTEGRAL_CONSTANT:
        if (self->bins == NULL) {
          /* first (fractional) bin */
          from = (from - self->min) / binsize;
          i = (int)from;
          from -= (double)i;

          /* last (fractional) bin */
          to = (to - self->min) / binsize;
          n = (int)to;
          to -= (double)n;
          if (i == n) {
            RETVAL = (to-from) * data[i];
          }
          else {
            RETVAL = data[i] * (1.-from)
                     + data[n] * to;
            ++i;
            for (; i < n; ++i)
              RETVAL += data[i];
          }
        }
        else { /* variable bin size */
          /* TODO optimize */
          double* bins = self->bins;
          unsigned int nbins = self->nbins;

          i = histo_find_bin_nonconstant_internal(from, nbins, bins);
          binsize = (bins[i+1]-bins[i]);
          RETVAL = (bins[i+1]-from)/binsize * data[i]; /* distance from 'from' to upper boundary of bin times data in bin */

          n = histo_find_bin_nonconstant_internal(to, nbins, bins);
          if (i == n) {
            RETVAL -= (bins[i+1]-to)/binsize * data[i];
          }
          else {
            ++i;
            for (; i < n; ++i) {
              RETVAL += data[i];
            }
            binsize = bins[n+1]-bins[n];
            RETVAL += data[n] * (to-bins[n])/binsize;
          }
        }
        break;
      default:
        croak("Invalid integration type");
    };
    if (invert)
      RETVAL *= -1.;
  OUTPUT: RETVAL


double
mean(self)
    simple_histo_1d* self
  PREINIT:
    double x;
    double* data;
    unsigned int i, n;
  CODE:
    if (self->total == 0)
      XSRETURN_UNDEF;

    RETVAL = 0.;
    data = self->data;
    n = self->nbins;
    if (self->bins == NULL) {
      double binsize = self->binsize;
      x = self->min + 0.5*binsize;
      for (i = 0; i < n; ++i) {
        RETVAL += data[i] * x;
        x += binsize;
      }
    }
    else { /* non-constant binsize */
      double* bins = self->bins;
      for (i = 0; i < n; ++i) {
        x = 0.5*(bins[i] + bins[i+1]);
        RETVAL += data[i] * x;
      }
    }
    RETVAL /= self->total;
  OUTPUT: RETVAL


#void
#binary_dump(self)
#    simple_histo_1d* self
#  PREINIT:
#    char* out;
#    SV* outSv;
#    double* tmp;
#    unsigned int size;
#  PPCODE:
#    size = sizeof(simple_histo_1d) + sizeof(double)*self->nbins;
#    outSv = newSVpvs("");
#    SvGROW(outSv, size+1);
#    printf("   %u\n", SvLEN(outSv));
#    out = SvPVX(outSv);
#    SvLEN_set(outSv, size);
#    printf("%u\n", SvLEN(outSv));
#    /*Newx(out, size+1, char);*/
#    tmp = self->data;
#    self->data = NULL;
#    Copy(self, out, sizeof(simple_histo_1d), char);
#    Copy(tmp, out+sizeof(simple_histo_1d), sizeof(double)*self->nbins, char);
#    out[size] = '\0';
#    printf("%u\n", SvLEN(outSv));
#    self->data = tmp;
#    XPUSHs(sv_2mortal(outSv));


void
_get_info(self)
    simple_histo_1d* self
  PREINIT:
    SV* data_ary;
    SV* bins_ary;
  PPCODE:
    /* min, max, nbins, nfills, overflow, underflow, dataref, binsref*/
    EXTEND(SP, 8);
    mPUSHn(self->min);
    mPUSHn(self->max);
    mPUSHu(self->nbins);
    mPUSHu(self->nfills);
    mPUSHn(self->overflow);
    mPUSHn(self->underflow);
    data_ary = histo_data_av(aTHX_ self);
    XPUSHs(sv_2mortal(data_ary));
    if (self->bins == NULL)
      bins_ary = &PL_sv_undef;
    else
      bins_ary = sv_2mortal(histo_bins_av(aTHX_ self));
    XPUSHs(bins_ary);


simple_histo_1d*
cumulative(self)
    simple_histo_1d* self
  PREINIT:
    char* CLASS;
  INIT:
    HS_CLONE_GET_CLASS(CLASS, self, cumulative);
  CODE:
    RETVAL = histo_cumulative(aTHX_ self);
  OUTPUT: RETVAL
