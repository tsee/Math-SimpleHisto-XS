MODULE = Math::SimpleHisto::XS    PACKAGE = Math::SimpleHisto::XS


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

