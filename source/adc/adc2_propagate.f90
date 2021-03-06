!#######################################################################
! TD-ADC(2) wavepacket propagation including the interaction with an
! applied laser pulse
!#######################################################################

module adc2propmod

  use channels

contains

!#######################################################################

  subroutine adc2_propagate(gam)

    use constants
    use parameters
    use adc_common
    use fspace
    use misc
    use guessvecs
    use mp2
    use targetmatching
    use capmod
    use thetamod
    use propagate_adc2
    
    implicit none

    integer, dimension(:,:), allocatable  :: kpq,kpqd,kpqf
    integer                               :: i,ndim,ndims,ndimsf,&
                                             nout,ndimf,ndimd,noutf
    integer*8                             :: noffd,noffdf
    real(dp)                              :: e0
    real(dp), dimension(:,:), allocatable :: cap_mo,theta_mo
    type(gam_structure)                   :: gam
    
!-----------------------------------------------------------------------
! Calculate the MP2 ground state energy and D2 diagnostic
!-----------------------------------------------------------------------
    call mp2_master(e0)

!-----------------------------------------------------------------------
! Determine the 1h1p and 2h2p subspaces
!-----------------------------------------------------------------------
    call get_subspaces(kpq,kpqf,kpqd,ndim,ndimf,ndimd,nout,noutf,&
         ndims,ndimsf)

!-----------------------------------------------------------------------
! For now, we will take the initial space to be equal to the final space
!-----------------------------------------------------------------------
    kpq=kpqf
    ndim=ndimf
    nout=noutf
    ndims=ndimsf
    
!-----------------------------------------------------------------------
! Set MO representation of the dipole operator
!-----------------------------------------------------------------------
    call set_dpl

!-----------------------------------------------------------------------
! If the initial state is an excited state or if excited states are to
! be included in a projected CAP, then diagonalise the initial state
! Hamiltonian
!-----------------------------------------------------------------------
    if (statenumber.gt.0.or.iprojcap.eq.2) &
         call get_initial_state_adc2(kpq,ndim,ndims,noffd)
    
!-----------------------------------------------------------------------
! Calculate the final space Hamiltonian matrix
!-----------------------------------------------------------------------
    call calc_hamiltonian(ndimf,kpqf,noffdf)
    
!-----------------------------------------------------------------------
! Calculate the MO representation of the CAP operator
!-----------------------------------------------------------------------
    if (lcap) call cap_mobas(gam,cap_mo)

!-----------------------------------------------------------------------
! If a projected CAP is being used, determine which states are to be
! included in the projector
!-----------------------------------------------------------------------
    if (lprojcap) call get_proj_states_adc2(ndim)
    
!-----------------------------------------------------------------------
! If flux analysis is to be performed, then calculate the MO
! representation of the projector (Theta) onto the CAP region
!-----------------------------------------------------------------------
    if (lflux) call theta_mobas(gam,theta_mo)
    
!-----------------------------------------------------------------------
! Calculate the matrix elements needed to represent the CAP operator
! in the the ground state + intermediate state basis
!-----------------------------------------------------------------------
    if (lcap) call cap_isbas_adc2(cap_mo,kpqf,ndimf)

!-----------------------------------------------------------------------
! Calculate the dipole matrices
!-----------------------------------------------------------------------
    if (npulse.gt.0) call dipole_isbas_adc2(kpqf,ndimf)

!-----------------------------------------------------------------------
! If flux analysis is to be performed, then calculate the matrix
! elements needed to represent the projector onto the CAP region in
! the ground state + intermediate state basis
!-----------------------------------------------------------------------
    if (lflux) call theta_isbas_adc2(theta_mo,kpqf,ndimf)
    
!-----------------------------------------------------------------------
! Perform the wavepacket propagation
!-----------------------------------------------------------------------
    hamflag='f'
    call propagate_laser_adc2(gam,ndimf,noffdf,kpqf)
    
!-----------------------------------------------------------------------
! Deallocate arrays
!-----------------------------------------------------------------------    
    deallocate(kpq,kpqf,kpqd)
    if (allocated(cap_mo)) deallocate(cap_mo)
    if (allocated(w0j)) deallocate(w0j)
    deallocate(d0j)
    deallocate(dpl_all)
    if (allocated(theta_mo)) deallocate(theta_mo)
    if (allocated(theta0j)) deallocate(theta0j)
    if (allocated(projmask)) deallocate(projmask)
    
    return
    
  end subroutine adc2_propagate

!#######################################################################

  subroutine calc_hamiltonian(ndimf,kpqf,noffdf)

    use fspace
    
    implicit none

    integer, dimension(7,0:nBas**2*4*nOcc**2) :: kpqf
    integer                                   :: ndimf
    integer*8                                 :: noffdf
    
    write(ilog,*) 'Saving complete FINAL SPACE ADC2 matrix in file'
    
    if (method_f.eq.2) then
       ! ADC(2)-s
       if (lcvsfinal) then
          call write_fspace_adc2_1_cvs(ndimf,kpqf(:,:),noffdf,'c')
       else
          call write_fspace_adc2_1(ndimf,kpqf(:,:),noffdf,'c')
       endif
    else if (method_f.eq.3) then
       ! ADC(2)-x
       if (lcvsfinal) then
          call write_fspace_adc2e_1_cvs(ndimf,kpqf(:,:),noffdf,'c')
       else
          call write_fspace_adc2e_1(ndimf,kpqf(:,:),noffdf,'c')
       endif
    endif
    
    return
    
  end subroutine calc_hamiltonian
  
!#######################################################################

  subroutine cap_isbas_adc2(cap_mo,kpqf,ndimf)

    use constants
    use parameters
    use mp2
    use get_matrix_dipole
    use get_moment
    
    implicit none

    integer, dimension(7,0:nBas**2*4*nOcc**2) :: kpqf
    integer                                   :: ndimf
    integer                                   :: p,q,k
    integer                                   :: error
    real(dp), dimension(nbas,nbas)            :: cap_mo
    real(dp), dimension(nbas,nbas)            :: rho0
    real(dp), dimension(nbas,nbas)            :: dpl_orig
    character(len=60)                         :: filename

!----------------------------------------------------------------------
! Calculate the ground state density matrix
!----------------------------------------------------------------------
    call rho_mp2(rho0)

!----------------------------------------------------------------------
! Calculate the CAP matrix element W_00 = < Psi_0 | W | Psi_0 >
!----------------------------------------------------------------------
    w00=0.0d0
    do p=1,nbas
       do q=1,nbas
          w00=w00+rho0(p,q)*cap_mo(p,q)
       enddo
    enddo
    
!----------------------------------------------------------------------
! In the following, we calculate CAP matrix elements using the shifted
! dipole code (D-matrix and f-vector code) by simply temporarily
! copying the MO CAP matrix into the dpl array.
!----------------------------------------------------------------------
    dpl_orig(1:nbas,1:nbas)=dpl(1:nbas,1:nbas)
    dpl(1:nbas,1:nbas)=cap_mo(1:nbas,1:nbas)

!----------------------------------------------------------------------
! Calculate the vector W_0J = < Psi_0 | W | Psi_J >
!----------------------------------------------------------------------
    allocate(w0j(ndimf))
    w0j=0.0d0

    write(ilog,'(/,72a)') ('-',k=1,72)
    write(ilog,'(2x,a)') 'Calculating the vector &
         W_0J = < Psi_0 | W | Psi_J >'
    write(ilog,'(72a)') ('-',k=1,72)
    
    call get_modifiedtm_adc2(ndimf,kpqf(:,:),w0j,1)

!----------------------------------------------------------------------
! Calculate the IS representation of the shifted CAP operator W-W_00
!----------------------------------------------------------------------
    write(ilog,'(/,72a)') ('-',k=1,72)
    write(ilog,'(2x,a)') 'Calculating the IS representation of the &
         shifted CAP operator'
    write(ilog,'(72a,/)') ('-',k=1,72)
    
    filename='SCRATCH/cap'
    call get_adc2_dipole_same_space(ndimf,kpqf,nbuf_cap,nel_cap,&
         filename)
    
!----------------------------------------------------------------------
! Reset the dpl array
!----------------------------------------------------------------------
    dpl(1:nbas,1:nbas)=dpl_orig(1:nbas,1:nbas)
    
    return
    
  end subroutine cap_isbas_adc2
    
!#######################################################################

  subroutine dipole_isbas_adc2(kpqf,ndimf)

    use constants
    use parameters
    use mp2
    use get_matrix_dipole
    use get_moment
    
    implicit none

    integer, dimension(7,0:nBas**2*4*nOcc**2) :: kpqf
    integer                                   :: ndimf
    integer                                   :: p,q,k,c
    real(dp), dimension(nbas,nbas)            :: rho0
    character(len=60)                         :: filename
    character(len=1), dimension(3)            :: acomp

    acomp=(/ 'x','y','z' /)

!----------------------------------------------------------------------
! Calculate the ground state density matrix
!----------------------------------------------------------------------
    call rho_mp2(rho0)

!----------------------------------------------------------------------
! Calculate the dipole matrix elements Dc_00 = < Psi_0 | Dc | Psi_0 >
! for c=x,y,z
!----------------------------------------------------------------------
    d00=0.0d0
    do p=1,nbas
       do q=1,nbas
          d00(1:3)=d00(1:3)+rho0(p,q)*dpl_all(1:3,p,q)
       enddo
    enddo

!----------------------------------------------------------------------
! Calculate the vectors Dc_0J = < Psi_0 | D | Psi_J >, c=x,y,z
!----------------------------------------------------------------------
    allocate(d0j(3,ndimf))
    d0j=0.0d0

    ! Loop over the x, y, and z components
    do c=1,3

       ! Skip if the current component is not required
       if (sum(abs(pulse_vec(c,1:npulse))).eq.0.0d0) cycle
       
       write(ilog,'(/,72a)') ('-',k=1,72)
       write(ilog,'(2x,a)') 'Calculating the vector D'//acomp(c)//&
            '_0J = < Psi_0 | D'//acomp(c)//' | Psi_J >'
       write(ilog,'(72a)') ('-',k=1,72)

       dpl(:,:)=dpl_all(c,:,:)
       
       call get_modifiedtm_adc2(ndimf,kpqf(:,:),d0j(c,:),1)

    enddo
        
!----------------------------------------------------------------------
! Calculate the IS representations of the shifted dipole operators
! Dc - Dc_0, c=x,y,z
!----------------------------------------------------------------------
    ! Loop over the x, y, and z components
    do c=1,3

       ! Skip if the current component is not required
       if (sum(abs(pulse_vec(c,1:npulse))).eq.0.0d0) cycle
       
       write(ilog,'(/,72a)') ('-',k=1,72)
       write(ilog,'(2x,a)') 'Calculating the IS representation of &
            the shifted dipole operator D'//acomp(c)
       write(ilog,'(72a)') ('-',k=1,72)
       
       filename='SCRATCH/dipole_'//acomp(c)

       dpl(:,:)=dpl_all(c,:,:)
       
       call get_adc2_dipole_same_space(ndimf,kpqf,nbuf_dip(c),&
            nel_dip(c),filename)
       
    enddo

    return
    
  end subroutine dipole_isbas_adc2

!#######################################################################

  subroutine theta_isbas_adc2(theta_mo,kpqf,ndimf)

    use constants
    use parameters
    use mp2
    use get_matrix_dipole
    use get_moment
    
    implicit none

    integer, dimension(7,0:nBas**2*4*nOcc**2) :: kpqf
    integer                                   :: ndimf
    integer                                   :: p,q,k
    integer                                   :: error
    real(dp), dimension(nbas,nbas)            :: theta_mo
    real(dp), dimension(nbas,nbas)            :: rho0
    real(dp), dimension(nbas,nbas)            :: dpl_orig
    character(len=60)                         :: filename

!----------------------------------------------------------------------
! Calculate the ground state density matrix
!----------------------------------------------------------------------
    call rho_mp2(rho0)

!----------------------------------------------------------------------
! Calculate the projector matrix element
! Theta_00 = < Psi_0 | Theta | Psi_0 >
!----------------------------------------------------------------------
    theta00=0.0d0
    do p=1,nbas
       do q=1,nbas
          theta00=theta00+rho0(p,q)*theta_mo(p,q)
       enddo
    enddo

!----------------------------------------------------------------------
! In the following, we calculate projector matrix elements using the
! shifted dipole code (D-matrix and f-vector code) by simply
! temporarily copying the MO projector matrix into the dpl array.
!----------------------------------------------------------------------
    dpl_orig(1:nbas,1:nbas)=dpl(1:nbas,1:nbas)
    dpl(1:nbas,1:nbas)=theta_mo(1:nbas,1:nbas)

!----------------------------------------------------------------------
! Calculate the vector Theta_0J = < Psi_0 | Theta | Psi_J >
!----------------------------------------------------------------------
    allocate(theta0j(ndimf))
    theta0j=0.0d0

    write(ilog,'(/,72a)') ('-',k=1,72)
    write(ilog,'(2x,a)') 'Calculating the vector &
         Theta_0J = < Psi_0 | Theta | Psi_J >'
    write(ilog,'(72a)') ('-',k=1,72)
    
    call get_modifiedtm_adc2(ndimf,kpqf(:,:),theta0j,1)

!----------------------------------------------------------------------
! Calculate the IS representation of the shifted projector operator
! Theta-Theta_00
!----------------------------------------------------------------------
    write(ilog,'(/,72a)') ('-',k=1,72)
    write(ilog,'(2x,a)') 'Calculating the IS representation of the &
         CAP-projector (Theta)'
    write(ilog,'(72a,/)') ('-',k=1,72)
    
    filename='SCRATCH/theta'
    
    call get_adc2_dipole_same_space(ndimf,kpqf,nbuf_theta,nel_theta,&
         filename)
    
!----------------------------------------------------------------------
! Reset the dpl array
!----------------------------------------------------------------------
    dpl(1:nbas,1:nbas)=dpl_orig(1:nbas,1:nbas)

    return
    
  end subroutine theta_isbas_adc2
    
!#######################################################################

  subroutine get_initial_state_adc2(kpq,ndim,ndims,noffd)

    use constants
    use parameters
    use guessvecs
    use adc_common
    use misc
    
    implicit none

    integer, dimension(7,0:nBas**2*4*nOcc**2) :: kpq
    integer                                   :: ndim,ndims
    integer                                   :: i,itmp
    integer*8                                 :: noffd
    real(dp)                                  :: time
    real(dp), dimension(:), allocatable       :: ener
    real(dp), dimension(:), allocatable       :: mtm,tmvec,&
                                                 osc_str
    real(dp), dimension(:,:), allocatable     :: rvec
    
!-----------------------------------------------------------------
! Diagonalise the initial space Hamiltonian and calculate the
! transition dipoles with the ground state
!-----------------------------------------------------------------
    if (ladc1guess) call adc1_guessvecs
    call initial_space_diag(time,kpq,ndim,ndims,noffd)
    call initial_space_tdm(ener,rvec,ndim,mtm,tmvec,osc_str,kpq)
    
!-----------------------------------------------------------------
! Output the initial space vectors
!-----------------------------------------------------------------
    write(ilog,'(/,70a)') ('*',i=1,70)
    write(ilog,'(2x,a)') &
         'Initial space ADC(2)-s excitation energies'
    write(ilog,'(70a)') ('*',i=1,70)
    itmp=1+nBas**2*4*nOcc**2
    call table2(ndim,davstates,ener(1:davstates),&
         rvec(:,1:davstates),tmvec(1:davstates),&
         osc_str(1:davstates),kpq,itmp,'i')
    write(ilog,'(/,70a,/)') ('*',i=1,70)

    return
    
  end subroutine get_initial_state_adc2

!#######################################################################

    subroutine get_proj_states_adc2(ndim)

    use constants
    use parameters
    use iomod
    
    implicit none

    integer               :: ndim,unit,itmp,i
    real(dp), allocatable :: ener(:)
    real(dp), allocatable :: vec(:)
    
!----------------------------------------------------------------------
! Allocate arrays
!----------------------------------------------------------------------
    allocate(projmask(davstates))
    projmask=0
    
    allocate(vec(davstates))
    vec=0.0d0

    allocate(ener(davstates))
    ener=0.0d0
    
!----------------------------------------------------------------------
! Fill in the projmask array
!----------------------------------------------------------------------
    projmask=0

    if (iprojcap.eq.2) then
       call freeunit(unit)
       open(unit,file=davname,status='old',access='sequential',&
            form='unformatted')
       do i=1,davstates
          read(unit) itmp,ener(i),vec
          if (ener(i).le.projlim) then
             projmask(i)=1
          else
             exit
          endif
       enddo
       close(unit)
    else if (iprojcap.eq.1.and.statenumber.gt.0) then
       projmask(statenumber)=1
    endif

!----------------------------------------------------------------------
! Deallocate arrays
!----------------------------------------------------------------------
    deallocate(vec)
    deallocate(ener)
    
    return
    
  end subroutine get_proj_states_adc2
  
!#######################################################################
  
end module adc2propmod
