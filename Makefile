########################################################################
#
#                           MAKEFILE FOR ADC                         
#
########################################################################

#-----------------------------------------------------------------------
# Compiler flags
#-----------------------------------------------------------------------

#
# gfortran
#
F90	= gfortran
F77	= gfortran
CC	= gcc
F90OPTS = -cpp -g -ffixed-line-length-none -ffree-line-length-none -fopenmp -O3 -fbacktrace
CCOPTS  = -g -O0

#
# intel
#
#F90	 = ifort
#F77	 = ifort
#CC	 = icc
#F90OPTS = -cpp -g -assume byterecl -free -fopenmp -traceback -O3 -unroll0
#CCOPTS  = -g -O0

#-----------------------------------------------------------------------
# External libraries
#-----------------------------------------------------------------------
LIBS= -L/usr/lib64 ${LIB_LAPACK} ${LIB_BLAS}

#-----------------------------------------------------------------------
# Define object files
#-----------------------------------------------------------------------

########################################################################
# ADC code
########################################################################
MULTI = multi/accuracy.o \
	multi/printing.o \
	multi/timer.o \
	multi/lapack.o \
	multi/dgefa.o \
	multi/dgedi.o \
	multi/math.o \
	multi/matrix_tools.o \
	multi/os_integral_operators.o \
	multi/gamess_internal.o \
	multi/import_gamess.o \
	multi/integral_tools.o \
	multi/integrals_mo2e.o \
        multi/diis.o \
        multi/sort_tools.o \
        multi/block_diag.o \
        multi/biorthogonal_tools.o \
        multi/scf_tools.o \
        multi/fock_tools.o 

INCLUDE=include/constants.o \
	include/parameters.o \
	include/channels.o \

UTILITIES=utilities/timingmod.o \
	utilities/misc.o \

IOMODULES=iomodules/iomod.o \
	iomodules/parsemod.o \
	iomodules/rdinput.o \
	iomodules/read_param.o \

QCLIB=	qclib/vpqrsmod.o \
	qclib/rungamess.o \
	qclib/load_electronic_structure.o \
	qclib/scf_electronic_structure.o 

EIGEN=  eigen/matvecmul.o \
	eigen/expokit.o \
	eigen/sillib.o \
	eigen/block_davidson.o \
	eigen/relaxation.o \
	eigen/fvecprop.o \
	eigen/diagmod.o \
	eigen/block_lanczos.o 

ADCLIB= adclib/defaults.o \
	adclib/orbindx.o \
	adclib/filetools.o \
	adclib/adc_ph.o \
	adclib/dipole_ph.o \
	adclib/D_matrix.o \
	adclib/sym_allowed_exc.o \
	adclib/select_fano.o \
	adclib/get_matrix.o \
	adclib/get_matrix_dipole_complete.o \
	adclib/get_moment.o \
	adclib/fspacetrial.o \
	adclib/fspace2.o \
        adclib/guessvecs.o \
	adclib/photoionisation.o \
	adclib/Propagate.o \
	adclib/dyson_calc.o \
	adclib/dyson_io.o \
	adclib/target_matching.o \
	adclib/mp2.o \
	adclib/adc2common.o 

ADC_MAIN=adc/adc1_opa.o \
	adc/adc2_opa.o \
	adc/adc2_ener.o \
	adc/adc2_dyson.o \
	adc/adc2_rixs.o \
	adc/adc2_tpa.o \
	adc/adc2_autospec.o \
	adc/adc.o

ADC =   $(INCLUDE) \
	$(IOMODULES) \
	$(UTILITIES) \
	$(QCLIB) \
	$(EIGEN) \
	$(ADCLIB) \
	$(ADC_MAIN)

OBJECTS = $(MULTI) $(ADC)

ADC_OBJ=accuracy.o \
	printing.o \
	timer.o \
	lapack.o \
	dgefa.o \
	dgedi.o \
	math.o \
	matrix_tools.o \
	os_integral_operators.o \
	gamess_internal.o \
	import_gamess.o \
	integral_tools.o \
	integrals_mo2e.o \
        diis.o \
        sort_tools.o \
        block_diag.o \
        biorthogonal_tools.o \
        scf_tools.o \
        fock_tools.o \
        constants.o \
	parameters.o \
	channels.o \
	misc.o \
	iomod.o \
	parsemod.o \
	rdinput.o \
	timingmod.o \
	defaults.o \
	orbindx.o \
	vpqrsmod.o \
	rungamess.o \
	load_electronic_structure.o \
        scf_electronic_structure.o \
	filetools.o \
	adc_ph.o \
	dipole_ph.o \
	D_matrix.o \
	read_param.o \
	sym_allowed_exc.o \
	select_fano.o \
	get_matrix.o \
	get_matrix_dipole_complete.o \
	get_moment.o \
	fspacetrial.o \
	fspace2.o \
	block_davidson.o \
	matvecmul.o \
	expokit.o \
	sillib.o \
	relaxation.o \
	fvecprop.o \
	diagmod.o \
	block_lanczos.o \
	photoionisation.o \
	Propagate.o \
        dyson_calc.o \
	dyson_io.o \
	target_matching.o \
	mp2.o \
	adc2common.o \
        guessvecs.o \
	adc1_opa.o \
	adc2_opa.o \
	adc2_ener.o \
	adc2_dyson.o \
	adc2_rixs.o \
	adc2_tpa.o \
	adc2_autospec.o \
	adc.o

########################################################################
# Stieltjes imaging code
########################################################################
STIELTJES_AP = mpfun/second.o \
	mpfun/mpfuna.o \
	mpfun/mpfunbq.o \
	mpfun/mpfunc.o \
	mpfun/mpfund.o \
	mpfun/mpfune.o \
	mpfun/mpfunfq1.o \
	mpfun/mpmodule.o \
	include/constants.o \
	include/channels.o \
	iomodules/iomod.o \
	iomodules/parsemod.o \
	stieltjes_ap/pythag.o \
	stieltjes_ap/tql2.o \
        stieltjes_ap/simod.o \
        stieltjes_ap/stieltjes_ap.o 

STIELTJES_AP_OBJ = second.o \
	mpfuna.o \
	mpfunbq.o \
	mpfunc.o \
	mpfund.o \
	mpfune.o \
	mpfunfq1.o \
	mpmodule.o \
	constants.o \
	channels.o \
	iomod.o \
	parsemod.o \
	pythag.o \
	tql2.o \
        simod.o \
        stieltjes_ap.o

########################################################################
# Monotonicity-constrained spline interpolation code
########################################################################
MCSPLINE = include/constants.o \
	include/channels.o \
	iomodules/iomod.o \
	iomodules/parsemod.o \
	stieltjes_ap/mcspmod.o \
	stieltjes_ap/mcspline.o

MCSPLINE_OBJ = constants.o \
	channels.o \
	iomod.o \
	parsemod.o \
	mcspmod.o \
	mcspline.o

########################################################################
# Numerical Hessian code
########################################################################
NUMHESS = include/constants.o \
	include/channels.o \
	iomodules/iomod.o \
	iomodules/parsemod.o \
	numhess/hessmod.o \
	numhess/prepmod.o \
	numhess/calcmod.o \
	numhess/numhess.o

NUMHESS_OBJ = constants.o \
	channels.o \
	iomod.o \
	parsemod.o \
	hessmod.o \
	prepmod.o \
	calcmod.o \
	numhess.o

########################################################################
# RIXS plotting code
########################################################################
RIXSPLT = include/constants.o \
	include/channels.o \
	iomodules/iomod.o \
	iomodules/parsemod.o \
	rixsplt/rixsmod.o \
	rixsplt/rixsplt.o

RIXSPLT_OBJ = constants.o \
	channels.o \
	iomod.o \
	parsemod.o \
	rixsmod.o \
	rixsplt.o

#-----------------------------------------------------------------------
# Rules to create the programs
#-----------------------------------------------------------------------
adc: $(OBJECTS)
	$(F90) $(F90OPTS) $(ADC_OBJ) $(LIBS) -o adc.x 
	rm -f *.o *~ *.mod 2>/dev/null

stieltjes_ap: $(STIELTJES_AP)
	$(F90) $(F90OPTS) $(STIELTJES_AP_OBJ) $(LIBS) -o stieltjes_ap.x
	rm -f *.o *~ *.mod

mcspline: $(MCSPLINE)
	$(F90) $(F90OPTS) $(MCSPLINE_OBJ) -o mcspline.x
	rm -f *.o *~ *.mod

numhess: $(NUMHESS)
	$(F90) $(F90OPTS) $(NUMHESS_OBJ) $(LIBS) -o numhess.x
	rm -f *.o *~ *.mod

rixsplt: $(RIXSPLT)
	$(F90) $(F90OPTS) $(RIXSPLT_OBJ) $(LIBS) -o rixsplt.x
	rm -f *.o *~ *.mod

%.o: %.f90
	$(F90) -c $(F90OPTS) $<

%.o: %.f
	$(F77) -c $(F77OPTS) $<

%.o: %.c
	$(CC) $(CCOPTS)  -c $<

clean_all:
	rm -f *.o *~ *.mod
