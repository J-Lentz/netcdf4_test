PROG = test
FMS_ROOT = ../FMS

FC = ftn

CPPFLAGS = -I$(FMS_ROOT)/.mods
FFLAGS ?= -O3 -traceback -fopenmp

LDFLAGS += -L$(FMS_ROOT)/libFMS/.libs
LDLIBS += -lFMS

all: $(PROG)_read $(PROG)_write

$(PROG)_read: $(PROG).F90
	$(FC) $(CPPFLAGS) $(FFLAGS) -DREAD_TEST $(LDFLAGS) -o $@ $< $(LDLIBS)

$(PROG)_write: $(PROG).F90
	$(FC) $(CPPFLAGS) $(FFLAGS) -DWRITE_TEST $(LDFLAGS) -o $@ $< $(LDLIBS)

.PHONY: clean

clean:
	rm -f $(PROG)_read $(PROG)_write *.nc *.out
