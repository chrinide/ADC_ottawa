!######################################################################
! chebyspec: routines for the calculation of the Chebyshev order-domain
!            autocorrelation function
!######################################################################

module chebyspec

  use constants
  use parameters
  use iomod
  use channels
  
  implicit none

  integer                :: matdim,n1h1p
  integer*8              :: noffdiag
  real(dp), dimension(2) :: bounds
  real(dp), allocatable  :: auto(:)
  real(dp), allocatable  :: q1h1p(:,:)
  
contains

!######################################################################

  subroutine chebyshev_auto_order_domain(q0,ndimf,noffdf,ndimsf,kpqf)

    use tdsemod
    use specbounds
    use timingmod
    
    implicit none

    ! TEMPORARY
    integer, dimension(7,0:nBas**2*4*nOcc**2) :: kpqf
    ! TEMPORARY
    
    integer, intent(in)        :: ndimf,ndimsf
    integer*8, intent(in)      :: noffdf
    integer                    :: k
    real(dp), dimension(ndimf) :: q0
    real(dp)                   :: tw1,tw2,tc1,tc2

!----------------------------------------------------------------------
! Start timing
!----------------------------------------------------------------------
    call times(tw1,tc1)
    
!----------------------------------------------------------------------
! Output what we are doing
!----------------------------------------------------------------------
    write(ilog,'(/,70a)') ('-',k=1,70)
    write(ilog,'(2x,a)') 'Calculation of the order-domain &
         Chebyshev autocorrelation function'
    write(ilog,'(70a,/)') ('-',k=1,70)
    
!----------------------------------------------------------------------
! Initialisation
!----------------------------------------------------------------------
    call chebyshev_initialise(ndimf,noffdf,ndimsf)

!----------------------------------------------------------------------
! Determine what can be held in memory
!----------------------------------------------------------------------
    call memory_managment

!----------------------------------------------------------------------
! Loading of the non-zero elements of the Hamiltonian matrix into
! memory
!----------------------------------------------------------------------
    if (hincore) call load_hamiltonian('SCRATCH/hmlt.diac',&
         'SCRATCH/hmlt.offc',matdim,noffdf)
    
!----------------------------------------------------------------------
! Estimation of the spectral bounds
!----------------------------------------------------------------------
    ! Estimation of the spectral bounds using a combination of
    ! block Davidson and block Lanczos
    call spectral_bounds(bounds,'c','davlanc',ndimf,noffdf)

    ! Adjust the estimated bounds to ensure that all eigenvalues are
    ! definitely in the interval [Ea,Eb]
    bounds(1)=0.9d0*bounds(1)
    bounds(2)=1.1d0*bounds(2)

!----------------------------------------------------------------------
! Projection of the initial state onto an energy subspace
!----------------------------------------------------------------------
    if (lprojpsi0) call project_psi0(q0,kpqf)
    
!----------------------------------------------------------------------
! Calculate the order-domain autocorrelation function
!----------------------------------------------------------------------
   call chebyshev_auto(q0)

!----------------------------------------------------------------------
! Write the order-domain autocorrelation function to file
!----------------------------------------------------------------------
   call write_chebyshev_auto

!----------------------------------------------------------------------
! Write the 1h1p parts of the Chebyshev order-domain vectors to file
!----------------------------------------------------------------------
   if (save1h1p) call write_1h1p
   
!----------------------------------------------------------------------
! Finalisation
!----------------------------------------------------------------------
   call chebyshev_finalise

!----------------------------------------------------------------------
! Output timings
!----------------------------------------------------------------------
   call times(tw2,tc2)
   write(ilog,'(/,a,1x,F9.2,1x,a)') 'Time taken:',tw2-tw1," s"
   
   return
    
 end subroutine chebyshev_auto_order_domain

!######################################################################

 subroutine chebyshev_initialise(ndimf,noffdf,ndimsf)

   implicit none

   integer, intent(in)   :: ndimf,ndimsf
   integer*8, intent(in) :: noffdf
    
!----------------------------------------------------------------------
! Dimensions
!----------------------------------------------------------------------
   matdim=ndimf
   noffdiag=noffdf
   n1h1p=ndimsf
   
!----------------------------------------------------------------------
! Make sure that the order of the Chebyshev expansion of Delta(E-H)
! is even
!----------------------------------------------------------------------
   if (mod(chebyord,2).ne.0) chebyord=chebyord-1
    
!----------------------------------------------------------------------
! Allocate and initialise arrays
!----------------------------------------------------------------------
   ! Chebyshev order-domain autocorrelation function
   allocate(auto(0:2*chebyord))
   auto=0.0d0

   ! 1h1p parts of the Chebyshev order-domain vectors
   if (save1h1p) then
      allocate(q1h1p(n1h1p,0:chebyord))
      q1h1p=0.0d0
   endif
      
   return
    
 end subroutine chebyshev_initialise
    
!######################################################################

  subroutine chebyshev_finalise
    
    use tdsemod
    
    implicit none

!----------------------------------------------------------------------
! Deallocate arrays
!----------------------------------------------------------------------
    deallocate(auto)
    if (hincore) call deallocate_hamiltonian
    if (save1h1p) deallocate(q1h1p)
    
   return
    
  end subroutine chebyshev_finalise

!######################################################################

  subroutine memory_managment

    use tdsemod
    use omp_lib
    
    implicit none

    integer*8  :: maxrecl,reqmem
    integer    :: nthreads
    real(dp)   :: memavail

!----------------------------------------------------------------------
! Available memory
!----------------------------------------------------------------------
    ! Maximum memory requested to be used by the user
    memavail=maxmem

    ! Two-electron integrals held in-core
    memavail=memavail-8.0d0*(nbas**4)/1024.0d0**2

    ! kpq
    memavail=memavail-8.0d0*7.0d0*(1+nbas**2*4*nocc**2)/1024.0d0**2

    ! Chebyshev polynomial-vector products
    memavail=memavail-8.0d0*4*matdim/1024.0d0**2

    ! 1h1p parts of the Chebyshev vectors
    if (save1h1p) &
         memavail=memavail-8.0d0*n1h1p*(chebyord+1)/1024.0d0**2
    
    ! Be cautious and only use say 90% of the available memory
    memavail=memavail*0.9d0

!----------------------------------------------------------------------
! Determine whether or not we can hold the non-zero Hamiltonian
! matrix elements in-core
!----------------------------------------------------------------------
    !$omp parallel
    nthreads=omp_get_num_threads()
    !$omp end parallel

    reqmem=0.0d0
    
    ! Parallelised matrix-vector multiplication
    reqmem=reqmem+8.0d0*nthreads*matdim/1024.0d0**2

    ! Non-zero off-diagonal Hamiltonian matrix elements and their
    ! indices
    reqmem=reqmem+8.0d0*2.0d0*noffdiag/1024.0d0**2

    ! On-diagonal Hamiltonian matrix elements
    reqmem=reqmem+8.0d0*matdim/1024.0d0**2

    ! Set the hincore flag controling whether the matrix-vector
    ! multiplication proceeds in-core
    if (reqmem.lt.memavail) then
       hincore=.true.
    else
       hincore=.false.
    endif

    return
    
  end subroutine memory_managment
    
!######################################################################

  subroutine chebyshev_auto(q0)

    use tdsemod
    
    implicit none

    integer                     :: k,i
    real(dp), dimension(matdim) :: q0
    real(dp), allocatable       :: qk(:),qkm1(:),qkm2(:)
    
!----------------------------------------------------------------------
! Allocate arrays
!----------------------------------------------------------------------
    allocate(qk(matdim))
    qk=0.0d0

    allocate(qkm1(matdim))
    qkm1=0.0d0

    allocate(qkm2(matdim))
    qkm2=0.0d0

!----------------------------------------------------------------------
! C_0
!----------------------------------------------------------------------
    auto(0)=dot_product(q0,q0)

!----------------------------------------------------------------------
! Save the 1h1p of the 0th-order Chebyshev vector
!----------------------------------------------------------------------
    if (save1h1p) q1h1p(:,0)=q0(1:n1h1p)
    
!----------------------------------------------------------------------
! Calculate the Chebyshev order-domain autocorrelation function
!----------------------------------------------------------------------
    ! Initialisation
    qkm1=q0
    
    ! Loop over Chebyshev polynomials of order k >= 1
    do k=1,chebyord

       ! Output our progress
       if (mod(k,10).eq.0) then
          write(ilog,'(70a)') ('+',i=1,70)
          write(ilog,'(a,x,i6)') 'Order:',k
       endif
       
       ! Calculate the kth Chebyhev polynomial-vector product
       call chebyshev_recursion(k,matdim,noffdiag,bounds,qk,qkm1,qkm2)

       ! Calculate C_k
       auto(k)=dot_product(q0,qk)

       ! Calculate C_2k and C_2k-1
       if (k.gt.chebyord/2) then
          auto(2*k)=2.0d0*dot_product(qk,qk)-auto(0)
          auto(2*k-1)=2.0d0*dot_product(qkm1,qk)-auto(1)
       endif

       ! Save the 1h1p of the kth Chebyshev vector
       if (save1h1p) q1h1p(:,k)=qk(1:n1h1p)
       
       ! Update qkm1 and qkm2
       qkm2=qkm1       
       qkm1=qk
       qk=0.0d0
       
    enddo
    write(ilog,'(70a)') ('+',i=1,70)

!----------------------------------------------------------------------
! Deallocate arrays
!----------------------------------------------------------------------
    deallocate(qk)
    deallocate(qkm1)
    deallocate(qkm2)
    
    return
    
  end subroutine chebyshev_auto

!######################################################################

  subroutine write_chebyshev_auto
    
    implicit none

    integer :: unit,k
    
!----------------------------------------------------------------------
! Open the output file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file='chebyauto',form='formatted',status='unknown')

!----------------------------------------------------------------------
! Write the file header
!----------------------------------------------------------------------
    write(unit,'(a,2(2x,E21.14),/)') '#    Spectral bounds:',&
         bounds(1),bounds(2)
    write(unit,'(a)')   '#    Order [k]    C_k'
    
!----------------------------------------------------------------------
! Write the order-domain autocorrelation function to file
!----------------------------------------------------------------------
    do k=0,chebyord*2
       write(unit,'(i6,11x,E21.14)') k,auto(k)
    enddo
    
!----------------------------------------------------------------------
! Close the output file
!----------------------------------------------------------------------
    close(unit)
    
    return
    
  end subroutine write_chebyshev_auto

!######################################################################

  subroutine write_1h1p

    use iomod
    
    implicit none

    integer :: unit,k

!----------------------------------------------------------------------
! Open the output file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit=unit,file='cheby1h1p',status='unknown',&
         access='sequential',form='unformatted')
    
!----------------------------------------------------------------------
! Write the 1h1p parts of the Chebyshev order-domain vectors to file
!----------------------------------------------------------------------
    do k=0,chebyord
       write(unit) q1h1p(:,k)
    enddo
       
!----------------------------------------------------------------------
! Close the output file
!----------------------------------------------------------------------
    close(unit)
    
    return
    
  end subroutine write_1h1p

!######################################################################

  subroutine project_psi0(q0,kpqf)

    use tdsemod
    use misc
    
    implicit none

    ! TEMPORARY
    integer, dimension(7,0:nBas**2*4*nOcc**2) :: kpqf
    ! TEMPORARY
    
    integer                     :: k
    real(dp), dimension(matdim) :: q0
    real(dp), allocatable       :: qk(:),qkm1(:),qkm2(:),pq0(:)
    real(dp), allocatable       :: gk(:),fk(:)
    real(dp)                    :: escale,alpha,cosa,sina

    integer, allocatable :: indx(:)
    integer              :: ilbl,kpqdim2
    character(len=2)     :: spincase

!----------------------------------------------------------------------
! Allocate arrays
!----------------------------------------------------------------------
    allocate(qk(matdim))
    qk=0.0d0

    allocate(qkm1(matdim))
    qkm1=0.0d0

    allocate(qkm2(matdim))
    qkm2=0.0d0

    allocate(pq0(matdim))
    pq0=0.0d0
    
    allocate(gk(0:chebyord))
    gk=0.0d0
    
    allocate(fk(0:chebyord))
    fk=0.0d0
    
!----------------------------------------------------------------------
! Scale the projection energy
!----------------------------------------------------------------------
    escale=projen-(0.5d0*(bounds(2)-bounds(1))+bounds(1))
    escale=escale/(bounds(2)-bounds(1))
    escale=2.0d0*escale

!----------------------------------------------------------------------
! Calculate the attenuation coefficients, g_k
!----------------------------------------------------------------------
  alpha=pi/dble(chebyord+2)
  cosa=cos(alpha)
  sina=sin(alpha)
  
  do k=0,chebyord
     gk(k)=(1.0d0-dble(k)/(dble(chebyord+2)))*sina*cos(k*alpha) &
          + (1.0d0/dble(chebyord+2))*cosa*sin(k*alpha)
  enddo
  gk(:)=gk(:)/sina

!----------------------------------------------------------------------
! Calculate the expansion coefficients, f_k
!----------------------------------------------------------------------
    fk(0)=1.0d0-acos(escale)/pi

    do k=1,chebyord
       fk(k)=-2.0d0*sin(k*acos(escale))/(k*pi)
    enddo

!----------------------------------------------------------------------
! Project the initial state onto the energy subspace of interest
!----------------------------------------------------------------------
    ! Initialisation
    pq0=fk(0)*gk(0)*q0
    qkm1=q0
    
    ! Jackson-Chebyshev expansion
    do k=1,chebyord

       ! Calculate the kth Chebyhev polynomial-vector product
       call chebyshev_recursion(k,matdim,noffdiag,bounds,qk,qkm1,qkm2)

       ! Contribution the the projected state
       pq0=pq0+fk(k)*gk(k)*qk

       ! Update qkm1 and qkm2
       qkm2=qkm1       
       qkm1=qk
       qk=0.0d0

    enddo

    q0=pq0

!----------------------------------------------------------------------
! Test: analyse the dominant configurations contributuing to the
! projected initial state
!----------------------------------------------------------------------
    allocate(indx(matdim))
    indx=0
    
    pq0=abs(q0/sqrt(dot_product(q0,q0)))
    
    call dsortindxa1("D",matdim,pq0,indx(:))

    kpqdim2=1+nBas**2*4*nOcc**2
    
    do k=1,50
       ilbl=indx(k)
       if (kpqf(4,ilbl).eq.-1) then
          ! Single excitations
          write(ilog,'(3x,i2,4x,a2,1x,i2,9x,F8.5)') &
               kpqf(3,ilbl),'->',kpqf(5,ilbl),pq0(ilbl)
       else
          ! Double excitations
          if (kpqf(3,ilbl).ne.kpqf(4,ilbl).and.kpqf(5,ilbl).ne.kpqf(6,ilbl)) then
             ! a|=b, i|=j
             spincase=getspincase(ilbl,kpqf,kpqdim2)
             write(ilog,'(3x,2(i2,1x),a2,2(1x,i2),2x,a2,2x,F8.5)') &
                  kpqf(3,ilbl),kpqf(4,ilbl),'->',kpqf(5,ilbl),&
                  kpqf(6,ilbl),spincase,pq0(ilbl)
          else
             ! a=b,  i=j
             ! a|=b, i=j
             ! a=b,  i=|j
             write(ilog,'(3x,2(i2,1x),a2,2(1x,i2),6x,F8.5)') &
                  kpqf(3,ilbl),kpqf(4,ilbl),'->',kpqf(5,ilbl),&
                  kpqf(6,ilbl),pq0(ilbl)
          endif
       endif
    enddo
    
    deallocate(indx)

!----------------------------------------------------------------------
! Deallocate arrays
!----------------------------------------------------------------------
    deallocate(qk)
    deallocate(qkm1)
    deallocate(qkm2)
    deallocate(pq0)
    deallocate(gk)
    deallocate(fk)
    
    return
    
  end subroutine project_psi0
    
!######################################################################
    
end module chebyspec
