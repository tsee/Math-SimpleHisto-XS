#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

typedef struct {
  double min;
  double max;
  unsigned int nbins;

  double width;
  double binsize;

  unsigned int nfills;
  double* data;
  double overflow;
  double underflow;
  double total;
} simple_histo_1d;


void
fill(simple_histo_1d* self, unsigned int n, double* x_in, double* w_in)
{
  unsigned int i, nbins = self->nbins;
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

MODULE = Math::SimpleHisto::XS    PACKAGE = Math::SimpleHisto::XS

REQUIRE: 2.2201

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
    Newxz(RETVAL->data, (int)RETVAL->nbins, double);
  OUTPUT:
    RETVAL


void
DESTROY(self)
    simple_histo_1d* self
  CODE:
    Safefree( (void*)self->data );
    Safefree( (void*)self );


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
        fill(self, n+1, x, NULL);
        Safefree(x);
      }
      else {
        double x = SvNV(ST(1));
        fill(self, 1, &x, NULL);
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
        fill(self, n+1, x, w);
        Safefree(x);
        Safefree(w);
      }
      else {
        double x = SvNV(ST(1));
        double w = SvNV(ST(2));
        fill(self, 1, &x, &w);
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
binsize(self)
    simple_histo_1d* self
  CODE:
    RETVAL = self->binsize;
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
    AV* av;
    SV* rv;
    int i, n;
    double* data;
  PPCODE:
    av = newAV();
    rv = (SV*)newRV((SV*)av);
    SvREFCNT_dec(av);
    n = self->nbins;
    av_fill(av, n-1);
    data = self->data;
    for (i = 0; i < n; ++i) {
      av_store(av, i, newSVnv(data[i]));
    }
    XPUSHs(sv_2mortal(rv));


double
bin_content(self, ibin)
    simple_histo_1d* self
    unsigned int ibin
  CODE:
    if (ibin < 0 || ibin >= self->nbins) {
      croak("Bin outside histogram range");
    }
    RETVAL = (self->data)[ibin];
  OUTPUT: RETVAL


void
bin_centers(self)
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
    binsize = self->binsize;
    x = self->min + 0.5*binsize;
    for (i = 0; i < n; ++i) {
      av_store(av, i, newSVnv(x));
      x += binsize;
    }
    XPUSHs(sv_2mortal(rv));


double
bin_center(self, ibin)
    simple_histo_1d* self
    unsigned int ibin
  CODE:
    if (ibin < 0 || ibin >= self->nbins) {
      croak("Bin outside histogram range");
    }
    RETVAL = self->min + ((double)ibin + 0.5) * self->binsize;
  OUTPUT: RETVAL


double
bin_lower_boundary(self, ibin)
    simple_histo_1d* self
    unsigned int ibin
  CODE:
    if (ibin < 0 || ibin >= self->nbins) {
      croak("Bin outside histogram range");
    }
    RETVAL = self->min + (double)ibin * self->binsize;
  OUTPUT: RETVAL


double
bin_upper_boundary(self, ibin)
    simple_histo_1d* self
    unsigned int ibin
  CODE:
    if (ibin < 0 || ibin >= self->nbins) {
      croak("Bin outside histogram range");
    }
    RETVAL = self->min + ((double)ibin + 1) * self->binsize;
  OUTPUT: RETVAL


void
bin_lower_boundaries(self)
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
    binsize = self->binsize;
    x = self->min;
    for (i = 0; i < n; ++i) {
      av_store(av, i, newSVnv(x));
      x += binsize;
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
    binsize = self->binsize;
    x = self->min;
    for (i = 0; i < n; ++i) {
      x += binsize;
      av_store(av, i, newSVnv(x));
    }
    XPUSHs(sv_2mortal(rv));


void
find_bin(self, x)
    simple_histo_1d* self
    double x
  PREINIT:
    dTARG;
  PPCODE:
    if (x >= self->max) {
      XSRETURN_UNDEF;
    }
    x -= self->min;
    if (x < 0) {
      XSRETURN_UNDEF;
    }
    XPUSHu( (UV)(x/self->binsize) );

