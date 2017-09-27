!######################################################################
! capmod: gateway for calling the routines that calculate the single-
!         particle basis representation of the CAP operator.
!######################################################################

module capmod

  implicit none  
  
  save
  
  ! Annoyingly, the gamess_internal module contains a variable
  ! named 'd', so we will use 'dp' here instead
  integer, parameter     :: dp=selected_real_kind(8)

contains
  
!######################################################################

  subroutine cap_mobas(gam,cap_mo)

    use channels
    use iomod
    use parameters
    use timingmod
    use monomial_analytic
    use import_gamess
    
    implicit none

    integer                               :: k
    real(dp)                              :: tw1,tw2,tc1,tc2
    real(dp), dimension(:,:), allocatable :: cap_mo
    type(gam_structure)                   :: gam
    
!----------------------------------------------------------------------
! Ouput what we are doing
!----------------------------------------------------------------------
    write(ilog,'(/,72a)') ('-',k=1,72)
    write(ilog,'(2x,a)') 'Calculating the MO representation of the &
         CAP operator'
    write(ilog,'(72a,/)') ('-',k=1,72)

!----------------------------------------------------------------------
! Start timing
!----------------------------------------------------------------------
    call times(tw1,tc1)

!----------------------------------------------------------------------
! Allocate arrays
!----------------------------------------------------------------------
    allocate(cap_mo(nbas,nbas))
    cap_mo=0.0d0
    
!----------------------------------------------------------------------
! Calculate the AO representation of the CAP operator
!----------------------------------------------------------------------
    if (icap.eq.1) then
       ! Monomial CAP, analytic evaluation of the CAP matrix elements
       call monomial_ana(gam,cap_mo)
    else
       ! Numerical evaluation of the CAP matrix elements
       call numerical_cap(gam,cap_mo)
    endif

!----------------------------------------------------------------------
! Output timings
!----------------------------------------------------------------------
    call times(tw2,tc2)
    write(ilog,'(/,2x,a,1x,F9.2,1x,a)') 'Time taken:',tw2-tw1," s"

    return
    
  end subroutine cap_mobas

!######################################################################

  subroutine numerical_cap(gam,cap_mo)

    use channels
    use constants
    use parameters
    use basis_cap
    use misc, only: get_vdwr
    use import_gamess
    
    implicit none

    integer                                  :: nao,i,j,n,natom
    real(dp), dimension(nbas,nbas)           :: cap_mo
    real(dp), dimension(:,:), allocatable    :: cap_ao,smat,lmat
    real(dp), parameter                      :: ang2bohr=1.889725989d0
    real(dp), dimension(:), allocatable      :: vdwr
    real(dp), parameter                      :: dscale=3.5
    real(dp)                                 :: x,r
    complex(dp), dimension(:,:), allocatable :: cap_ao_cmplx
    type(gam_structure)                      :: gam
    
!----------------------------------------------------------------------
! Allocate arrays
!----------------------------------------------------------------------
    nao=gam%nbasis

    natom=gam%natoms
    allocate(vdwr(natom))
    vdwr=0.0d0
    
    allocate(cap_ao(nao,nao))
    cap_ao=0.0d0

    allocate(cap_ao_cmplx(nao,nao))
    cap_ao_cmplx=czero

    allocate(smat(nao,nao))
    smat=0.0d0

    allocate(lmat(nao,nao))
    lmat=0.0d0
    
!----------------------------------------------------------------------
! Set the CAP type string used by the basis_cap module
!----------------------------------------------------------------------
    if (icap.eq.2) then
       ! Monomial CAP
       cap_type='monomial'
    else if (icap.eq.3) then
       ! Atom-centred monomial CAP
       cap_type='atom monomial'
    else if (icap.eq.4) then
       ! Moiseyev's non-local perfect CAP, single sphere
       cap_type='moiseyev'
    else if (icap.eq.5) then
       ! Moiseyev's non-local perfect CAP, atom-centered spheres
       cap_type='atom moiseyev'
    endif

!----------------------------------------------------------------------
! CAP centre: for now we will take this as the geometric centre of
! the molecule
!----------------------------------------------------------------------
    cap_centre=0.0d0
    do n=1,natom
       do i=1,3
          cap_centre(i)=cap_centre(i) &
               +gam%atoms(n)%xyz(i)*ang2bohr/natom
       enddo
    enddo

!----------------------------------------------------------------------
! CAP starting radius: we take the start of the CAP to correspond to
! the greatest distance in any direction to the furthest most atom
! plus its van der Waals radius multiplied by dscale
!----------------------------------------------------------------------
    call get_vdwr(gam,vdwr,natom)

    cap_r0=-1.0d0
    do n=1,natom
       do i=1,3
          x=gam%atoms(n)%xyz(i)*ang2bohr
          r=abs(x-cap_centre(i))+dscale*vdwr(n)
          if (r.gt.cap_r0) cap_r0=r
       enddo
    enddo
    
!----------------------------------------------------------------------
! Calculate the AO representation of the CAP.
!
! Note that cap_evaluate calculates the AO representation of -iW, but
! we require the AO representation of W, hence the conversion after
! this subroutine is called.
!----------------------------------------------------------------------
     call cap_evaluate(gam,120,770,1200,770,cap_ao_cmplx,smat,lmat)

     do i=1,nao
        do j=1,nao
           cap_ao(i,j)=-aimag(cap_ao_cmplx(i,j))
        enddo
     enddo

!----------------------------------------------------------------------
! Transform the AO representation of the CAP to the MO representation
!----------------------------------------------------------------------
     cap_mo=matmul(transpose(ao2mo),matmul(cap_ao,ao2mo))
     
!----------------------------------------------------------------------
! Deallocate arrays
!----------------------------------------------------------------------
    deallocate(cap_ao)
    deallocate(cap_ao_cmplx)
    deallocate(smat)
    deallocate(lmat)
    
    return
    
  end subroutine numerical_cap

!######################################################################  
  
end module capmod