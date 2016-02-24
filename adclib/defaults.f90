  module defaults

  contains

!#######################################################################

    subroutine set_defaults

      use constants
      use parameters
      use channels

      implicit none

!-----------------------------------------------------------------------
! General ADC parameters
!-----------------------------------------------------------------------
      method=0
      method_f=0
      denord=2
      nirrep=0
      nirrep2=0
      statenumber=-1
      tranmom=''
      tranmom2=''
      norder=2
      motype='incore'
      dlim=0.0d0
      ltdm_gs2i=.true.
      lifrzcore=.false.
      lffrzcore=.false. 
      ldiagfinal=.false.
      hinit=1
      maxmem=250.0d0

!-----------------------------------------------------------------------
! CVS-ADC parameters
!-----------------------------------------------------------------------      
      lcvs=.false.
      lcvsfinal=.false.
      icore=0
      iexpfrz=0

!-----------------------------------------------------------------------
! Ionisation potential calculation parameters
!-----------------------------------------------------------------------      
      lfakeip=.false.
      ifakeorb=0

!-----------------------------------------------------------------------
! Diagonalisation parameters
!-----------------------------------------------------------------------
      ! Initial space
      davstates=0
      maxiter=0
      dmain=0
      davtol=1d-7
      ladc1guess=.false.
      davname='SCRATCH/davstates'
      precon=1
      maxsubdim=-1
      ldfl=.true.
      solver=1
      
      ! Final space
      davstates_f=0
      maxiter_f=0
      dmain_f=0
      davtol_f=1d-7
      ladc1guess_f=.false.
      davname_f='SCRATCH/davstates_final'
      precon_f=1
      maxsubdim_f=-1
      ldfl_f=.true.
      solver_f=1
      
      ! Common
      ndavcalls=0
      eigentype=1

!-----------------------------------------------------------------------
! Relaxation parameters
!-----------------------------------------------------------------------
      ! Initial space
      kdim=10
      stepsize=10.0d0      
      lnoise=.false.
      rlxortho=2
      siltol=1e-5
      
     ! Final space
      kdim_f=10
      stepsize_f=10.0d0
      lnoise_f=.false.
      rlxortho_f=2
      siltol_f=1e-5

!-----------------------------------------------------------------------
! Lanczos parameters
!-----------------------------------------------------------------------      
      lmain=0
      ncycles=0
      lancguess=1
      lancname='SCRATCH/lancstates'      
      ldynblock=.false.
      tdtol=0.0005d0
      orthotype=0

!-----------------------------------------------------------------------
! I/O channels
!-----------------------------------------------------------------------
      iin=1
      ilog=2

!-----------------------------------------------------------------------
! SCF parameters
!-----------------------------------------------------------------------
      scfiter=10

!-----------------------------------------------------------------------
! GAMESS parameters
!-----------------------------------------------------------------------
      lrungamess=.false.
      basname=''
      natm=0
      difftype=0
      ndiff=0
      pntgroup=''

!-----------------------------------------------------------------------
! Dyson orbital calculation parameters
!-----------------------------------------------------------------------
      ! Main Dyson orbital calculation parameters
      ldyson=.false.
      dysirrep=0
      dyslim=9999d0
      dysdiag=0
      dysout=0

      ! ezdyson input parameters
      lmax=4
      zcore=1.0d0
      nelen=10
      eleni=0.1d0
      elenf=10.0d0
      ngrdpnts=201
      grdi=-10.0d0
      grdf=10.0d0

!-----------------------------------------------------------------------
! Target state matching
!-----------------------------------------------------------------------
      ltarg=.false.
      detfile=''
      mofile=''
      detthrsh=-1.0d0
      ovrthrsh=-1.0d0

      return

    end subroutine set_defaults

!#######################################################################

  end module defaults
