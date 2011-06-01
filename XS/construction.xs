MODULE = Math::SimpleHisto::XS    PACKAGE = Math::SimpleHisto::XS

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


simple_histo_1d*
clone(self)
    SV* self
  ALIAS:
    new_alike = 1
  PREINIT:
    const char* CLASS;
  INIT:
    HS_CLONE_GET_CLASS(CLASS, self, clone);
  CODE:
    RETVAL = histo_clone(aTHX_ (simple_histo_1d*)SvIV((SV*)SvRV(self)), ix);
  OUTPUT: RETVAL


simple_histo_1d*
cumulative(self)
    SV* self
  PREINIT:
    const char* CLASS;
  INIT:
    HS_CLONE_GET_CLASS(CLASS, self, cumulative);
  CODE:
    RETVAL = histo_cumulative(aTHX_ (simple_histo_1d*)SvIV((SV*)SvRV(self)));
  OUTPUT: RETVAL


simple_histo_1d*
new_from_bin_range(self, bin_start, bin_end)
    SV* self
    unsigned int bin_start
    unsigned int bin_end
  ALIAS:
    new_alike_from_bin_range = 1
  PREINIT:
    const char* CLASS;
  INIT:
    HS_CLONE_GET_CLASS(CLASS, self, clone);
  CODE:
    RETVAL = histo_clone_from_bin_range(aTHX_ (simple_histo_1d*)SvIV((SV*)SvRV(self)), ix, bin_start, bin_end);
  OUTPUT: RETVAL

