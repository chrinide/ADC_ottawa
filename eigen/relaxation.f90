!#######################################################################
! Experimental block-relaxation algorithm for the calculation of the
! N lowest eigenpairs of the Hamiltonian matrix.
!
! A collection of N trial vectors are taken as a set of initial
! time-dependent electronic wavefunctions and propagated in negative
! imaginary time using the short iterative Lanczos algorithm.
!
! It is not clear yet whether this will be more effective than the
! block Davidson method.
!
! One possibility is to run the relaxation calculation for one or two
! iterations and then use the resulting vectors as guesses for a
! block Davidson calculation.
!#######################################################################

  module relaxmod

    use iomod
    use constants
    use parameters
    use channels
    use timingmod

    save

    integer                              :: maxbl,nrec,nblock,nconv,&
                                            nstates,krydim,niter,iortho
    integer, dimension(:), allocatable   :: indxi,indxj,sildim
    real(d), dimension(:), allocatable   :: hii,hij,ener,res,currtime
    real(d), dimension(:,:), allocatable :: vec_old,vec_new,hxvec
    real(d)                              :: step,eps,toler
    character(len=36)                    :: vecfile
    logical, dimension(:), allocatable   :: lconv
    logical                              :: lincore,lrdadc1,lrandom

  contains

!#######################################################################

    subroutine relaxation(matdim,noffd)

      implicit none

      integer, intent(in)      :: matdim
      integer*8, intent(in)    :: noffd
      integer                  :: n,k,l
      real(d)                  :: tw1,tw2,tc1,tc2
      character(len=120)       :: atmp
      
!-----------------------------------------------------------------------
! Start timing
!-----------------------------------------------------------------------
      call times(tw1,tc1)

!-----------------------------------------------------------------------
! Write to the log file
!-----------------------------------------------------------------------
      atmp='Block-relaxation in the'
      if (hamflag.eq.'i') then
         atmp=trim(atmp)//' initial space'
      else if (hamflag.eq.'f') then
         atmp=trim(atmp)//' final space'
      endif
      write(ilog,'(/,70a)') ('-',k=1,70)
      write(ilog,'(2x,a)') trim(atmp)
      write(ilog,'(70a,/)') ('-',k=1,70)

!-----------------------------------------------------------------------
! Allocatation and initialisation of arrays
!-----------------------------------------------------------------------
      call initialise(matdim)      

!-----------------------------------------------------------------------
! Determine whether or not we can perform the matrix-vector
! multiplication in-core
!-----------------------------------------------------------------------
      call isincore(matdim,noffd)

!-----------------------------------------------------------------------
! Set the initial vectors
!-----------------------------------------------------------------------
      call initvec(matdim)

!-----------------------------------------------------------------------
! Read the on-diagonal elements of the Hamiltonian matrix from disk
!-----------------------------------------------------------------------
      call rdham_on(matdim)
      
!-----------------------------------------------------------------------
! If the matrix-vector multiplication is to proceed in-core, then
! read the off-diagonal Hamiltonian matrix from disk
!-----------------------------------------------------------------------
      if (lincore) call rdham_off(noffd)

!-----------------------------------------------------------------------
! Output the initial energies and convergence information
!-----------------------------------------------------------------------
      vec_new=vec_old
      call getener(matdim,noffd)
      call check_conv(matdim,noffd)
      call wrtable(0)

!-----------------------------------------------------------------------
! Perform the block-relaxation calculation
!-----------------------------------------------------------------------
      ! Loop over timesteps
      do n=1,niter

         !! Propagate the wavefunctions to the next timestep using
         !! the SIL algorithm    
         !do k=1,nblock
         !   if (lconv(k).and.iortho.eq.2) then
         !      vec_new(:,k)=vec_old(:,k)
         !   else
         !      call silstep(k,matdim,noffd,vec_old(:,k),vec_new(:,k))
         !   endif
         !enddo

         ! New: Short iterative block-Lanczos (SIBL)
         call siblstep(matdim,noffd,vec_old,vec_new)

         ! If the unmodified SIL algorithm is being used, then
         ! orthogonalise the propagated wavefunctions amongst 
         ! themselves
         if (iortho.eq.1) call orthowf(matdim)

         ! Calculate the energies
         call getener(matdim,noffd)
         
         ! Sort the wavefunctions by energy
         call sortwf(matdim)
         
         ! Check convergence
         call check_conv(matdim,noffd)

         ! Output the energies and convergence information
         call wrtable(n)
         
         ! Exit if all wavefunctions have converged
         if (nconv.ge.nstates) then
            write(ilog,'(/,2x,a,/)') 'All states have converged'
            exit
         endif
            
         ! Set the initial wavefunctions for the next step
         vec_old=vec_new
         
      enddo

!-----------------------------------------------------------------------
! Exit here if not all states have converged
!-----------------------------------------------------------------------
      if (nconv.lt.nstates) then
         errmsg='Not all wavefunctions have converged. Quitting here.'
         call error_control
      endif

!-----------------------------------------------------------------------
! Write the converged eigenpairs to disk
!-----------------------------------------------------------------------
      call wreigenpairs

!-----------------------------------------------------------------------
! Deallocate arrays
!-----------------------------------------------------------------------
      call finalise

!-----------------------------------------------------------------------    
! Output timings
!-----------------------------------------------------------------------    
      call times(tw2,tc2)
      write(ilog,'(/,a,1x,F9.2,1x,a)') 'Time taken:',tw2-tw1," s"

      return
      
    end subroutine relaxation

!#######################################################################

    subroutine initialise(matdim)

      implicit none

      integer, intent(in) :: matdim

!-----------------------------------------------------------------------
! Initialisation of parameter values
!-----------------------------------------------------------------------
      if (hamflag.eq.'i') then
         vecfile=davname
         nstates=davstates
         nblock=dmain
         krydim=kdim
         step=stepsize
         eps=davtol
         niter=maxiter
         iortho=rlxortho
         toler=siltol
      else if (hamflag.eq.'f') then
         vecfile=davname_f
         nstates=davstates_f
         nblock=dmain_f
         krydim=kdim_f
         step=stepsize_f
         eps=davtol_f
         niter=maxiter_f
         iortho=rlxortho_f
         toler=siltol_f
      endif

!-----------------------------------------------------------------------
! Allocation of arays
!-----------------------------------------------------------------------
      ! On-diagonal elements of the Hamiltonian matrix
      allocate(hii(matdim))
      hii=0.0d0

      ! |Psi_n(t)>
      allocate(vec_old(matdim,nblock))
      vec_old=0.0d0

      ! |Psi_n(t+dt)>
      allocate(vec_new(matdim,nblock))
      vec_new=0.0d0

      ! H |Psi_n>
      allocate(hxvec(matdim,nblock))
      hxvec=0.0d0

      ! Energies
      allocate(ener(nblock))
      ener=0.0d0

      ! Residuals
      allocate(res(nblock))
      res=0.0d0

      ! Convergence flags
      allocate(lconv(nblock))
      lconv=.false.
      
      ! Current times
      allocate(currtime(nblock))
      currtime=0.0d0

      ! SIL Krylov subspace dimensions
      allocate(sildim(nblock))
      sildim=0.0d0
      
      return
      
    end subroutine initialise
      
!#######################################################################

    subroutine isincore(matdim,noffd)

      use constants
      use parameters, only: maxmem

      implicit none

      integer, intent(in)   :: matdim
      integer*8, intent(in) :: noffd
      real(d)               :: mem

      mem=0.0d0

      ! On-diagonal Hamiltonian matrix elements
      mem=mem+8.0d0*matdim/1024.0d0**2

      ! Non-zero off-diagonal Hamiltonian matrix element values
      mem=mem+8.0d0*noffd/1024.0d0**2

      ! Indices of the non-zero off-diagonal Hamiltonian matrix elements
      mem=mem+8.0d0*noffd/1024.0d0**2

      ! |Psi_n(t)> and |Psi_n(t+dt)>, n=1,nblock
      mem=mem+8.0d0*nblock*matdim/1024.0d0**2
      
      ! H |Psi>
      mem=mem+8.0d0*nblock*matdim/1024.0d0**2

      ! SIL: Lanczos vectors
      mem=mem+8.0d0*krydim*matdim/1024.0d0**2

      ! SIL: work arrays
      mem=mem+8.0d0*3*matdim/1024.0d0**2
      
      ! Determine whether we can hold the Hamiltonian matrix in-core
      if (mem.lt.maxmem) then
         lincore=.true.
         write(ilog,'(2x,a,/)') 'Matrix-vector multiplication will &
              proceed in-core'
      else
         lincore=.false.
         write(ilog,'(2x,a,/)') 'Matrix-vector multiplication will &
              proceed out-of-core'
      endif

      return

    end subroutine isincore

!#######################################################################

    subroutine initvec(matdim)

      implicit none

      integer, intent(in) :: matdim

      ! Determine whether the initial vectors are to be constructed from
      ! the ADC(1) eigenvectors, random noise or as single ISs
      lrdadc1=.false.
      lrandom=.false.      
      if (hamflag.eq.'i'.and.ladc1guess) then
         lrdadc1=.true.
      else if (hamflag.eq.'f'.and.ladc1guess_f) then
         lrdadc1=.true.
      endif
      if (hamflag.eq.'i'.and.lnoise) then
         lrandom=.true.
      else if (hamflag.eq.'f'.and.lnoise_f) then
         lrandom=.true.
      endif
      
      if (lrdadc1) then
         ! Construct the initial vectors from the ADC(1) eigenvectors
         call initvec_adc1
      else if (lrandom) then
         ! Construct the initial vectors as random orthonormal unit
         ! vectors
         call initvec_random(matdim)
      else
         ! Use a single IS for each initial vector
         call initvec_ondiag(matdim)
      endif
      
      return
      
    end subroutine initvec
      
!#######################################################################

    subroutine initvec_adc1

      use iomod, only: freeunit
      use constants
      use parameters

      implicit none

      integer                              :: iadc1,dim1,i
      integer, dimension(:), allocatable   :: indx1
      real(d), dimension(:,:), allocatable :: vec1

!-----------------------------------------------------------------------
! Open the ADC(1) eigenvector file
!-----------------------------------------------------------------------
      call freeunit(iadc1)
      open(iadc1,file='SCRATCH/adc1_vecs',form='unformatted',status='old')

!-----------------------------------------------------------------------
! Read the ADC(1) the eigenvectors
!-----------------------------------------------------------------------
      read(iadc1) dim1
      allocate(vec1(dim1,dim1))
      allocate(indx1(dim1))

      rewind(iadc1)

      read(iadc1) dim1,vec1

!-----------------------------------------------------------------------
! Set the initial Davidson vectors
!-----------------------------------------------------------------------
      vec_old=0.0d0
      do i=1,nblock
         vec_old(1:dim1,i)=vec1(:,i)
      enddo

!-----------------------------------------------------------------------
! Close the ADC(1) eigenvector file
!-----------------------------------------------------------------------
      close(iadc1)

      return

    end subroutine initvec_adc1

!#######################################################################

    subroutine initvec_ondiag(matdim)

      use iomod, only: freeunit
      use constants
      use parameters
      use misc, only: dsortindxa1

      implicit none

      integer, intent(in)                :: matdim
      integer                            :: iham,i,k
      integer, dimension(:), allocatable :: indx_hii
      real(d), dimension(:), allocatable :: hii
      character(len=70)                  :: filename

!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
      allocate(hii(matdim))
      allocate(indx_hii(matdim))

!-----------------------------------------------------------------------
! Open file
!-----------------------------------------------------------------------
      call freeunit(iham)
      
      if (hamflag.eq.'i') then
         filename='SCRATCH/hmlt.diai'
      else if (hamflag.eq.'f') then
         filename='SCRATCH/hmlt.diac'
      endif

      open(iham,file=filename,status='old',access='sequential',&
        form='unformatted') 

!-----------------------------------------------------------------------
! Read the on-diagonal Hamiltonian matrix elements
!-----------------------------------------------------------------------
      read(iham) maxbl,nrec
      read(iham) hii

!-----------------------------------------------------------------------
! Determine the indices of the on-diagonal elements with the smallest
! absolute values
!-----------------------------------------------------------------------
      hii=abs(hii)   
      call dsortindxa1('A',matdim,hii,indx_hii)

!-----------------------------------------------------------------------
! Set the initial vectors
!-----------------------------------------------------------------------
      vec_old=0.0d0
      do i=1,nblock
         k=indx_hii(i)
         vec_old(k,i)=1.0d0
      enddo

!-----------------------------------------------------------------------
! Deallocate arrays
!-----------------------------------------------------------------------
      deallocate(hii)
      deallocate(indx_hii)

!-----------------------------------------------------------------------
! Close file
!-----------------------------------------------------------------------
      close(iham)

      return

    end subroutine initvec_ondiag

!#######################################################################

    subroutine initvec_random(matdim)

      implicit none

      integer, intent(in) :: matdim      
      integer             :: n,k
      real(d)             :: ftmp
      
      do n=1,nblock
         do k=1,matdim
            call random_number(ftmp)
            vec_old(k,n)=ftmp
         enddo
         ftmp=dot_product(vec_old(:,n),vec_old(:,n))
         vec_old(:,n)=vec_old(:,n)/sqrt(ftmp)
      enddo
         
      return
      
    end subroutine initvec_random
      
!#######################################################################
    
    subroutine rdham_on(matdim)

      use iomod, only: freeunit
      use constants
      use parameters

      implicit none

      integer, intent(in) :: matdim
      integer             :: iham
      character(len=70)   :: filename

!-----------------------------------------------------------------------
! On-diagonal elements
!-----------------------------------------------------------------------
      call freeunit(iham)

      if (hamflag.eq.'i') then
         filename='SCRATCH/hmlt.diai'
      else if (hamflag.eq.'f') then
         filename='SCRATCH/hmlt.diac'
      endif

      open(iham,file=filename,status='old',access='sequential',&
           form='unformatted')

      read(iham) maxbl,nrec
      read(iham) hii

      close(iham)

      return

    end subroutine rdham_on

!#######################################################################
    
    subroutine rdham_off(noffd)

      use iomod, only: freeunit
      use constants
      use parameters
      
      implicit none
      
      integer*8, intent(in)              :: noffd
      integer                            :: iham,count,k,nlim
      integer, dimension(:), allocatable :: itmp1,itmp2
      real(d), dimension(:), allocatable :: ftmp
      character(len=70)                  :: filename

!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
      allocate(hij(noffd))
      allocate(indxi(noffd))
      allocate(indxj(noffd))

!-----------------------------------------------------------------------
! Off-diagonal elements
!-----------------------------------------------------------------------
      allocate(ftmp(maxbl))
      allocate(itmp1(maxbl))
      allocate(itmp2(maxbl))

      if (hamflag.eq.'i') then
         filename='SCRATCH/hmlt.offi'
      else if (hamflag.eq.'f') then
         filename='SCRATCH/hmlt.offc'
      endif

      open(iham,file=filename,status='old',access='sequential',&
           form='unformatted')

      count=0
      do k=1,nrec
         read(iham) ftmp(:),itmp1(:),itmp2(:),nlim
         hij(count+1:count+nlim)=ftmp(1:nlim)
         indxi(count+1:count+nlim)=itmp1(1:nlim)
         indxj(count+1:count+nlim)=itmp2(1:nlim)
         count=count+nlim
      enddo

      deallocate(ftmp,itmp1,itmp2)

      close(iham)

      return

    end subroutine rdham_off

!#######################################################################

    subroutine orthowf(matdim)

      implicit none
      
      integer, intent(in) :: matdim
      integer             :: i,j
      real(d)             :: dp

      ! Double modified Gram-Schmidt orthogonalisation
      do i=1,nblock
         do j=1,i-1
            dp=dot_product(vec_new(:,i),vec_new(:,j))
            vec_new(:,i)=vec_new(:,i)-dp*vec_new(:,j)
         enddo
      enddo
      do i=1,nblock
         do j=1,i-1
            dp=dot_product(vec_new(:,i),vec_new(:,j))
            vec_new(:,i)=vec_new(:,i)-dp*vec_new(:,j)
         enddo
      enddo

      ! Normalisation
      do i=1,nblock
         dp=dot_product(vec_new(:,i),vec_new(:,i))
         vec_new(:,i)=vec_new(:,i)/sqrt(dp)
      enddo

      return

    end subroutine orthowf

!#######################################################################

    subroutine getener(matdim,noffd)

      implicit none

      integer, intent(in)   :: matdim
      integer*8, intent(in) :: noffd
      integer               :: k

      call hxpsi_all(matdim,noffd,vec_new,hxvec)

      do k=1,nblock
         ener(k)=dot_product(vec_new(:,k),hxvec(:,k))
      enddo

      return
      
    end subroutine getener
      
!#######################################################################

    subroutine hxpsi_all(matdim,noffd,vecin,vecout)

      use iomod, only: freeunit
      use constants
      use parameters
      
      implicit none

      integer, intent(in)               :: matdim
      integer*8, intent(in)             :: noffd
      integer                           :: iham,nlim,i,j,k,l,m,n
      real(d), dimension(matdim,nblock) :: vecin,vecout
      character(len=70)                 :: filename

!-----------------------------------------------------------------------
! Contribution from the on-diagonal elements of the Hamiltonian matrix
!-----------------------------------------------------------------------
      vecout=0.0d0
      do m=1,nblock
         do n=1,matdim
            vecout(n,m)=hii(n)*vecin(n,m)
         enddo
      enddo

!-----------------------------------------------------------------------
! Contribution from the off-diagonal elements of the Hamiltonian matrix
!-----------------------------------------------------------------------
      if (.not.lincore) then
         
         allocate(hij(maxbl),indxi(maxbl),indxj(maxbl))      
         if (hamflag.eq.'i') then
            filename='SCRATCH/hmlt.offi'
         else if (hamflag.eq.'f') then
            filename='SCRATCH/hmlt.offc'
         endif

         open(iham,file=filename,status='old',access='sequential',&
              form='unformatted')
         
         do k=1,nrec
            read(iham) hij(:),indxi(:),indxj(:),nlim
            do l=1,nlim
               do m=1,nblock
                  vecout(indxi(l),m)=vecout(indxi(l),m)+hij(l)*vecin(indxj(l),m)
                  vecout(indxj(l),m)=vecout(indxj(l),m)+hij(l)*vecin(indxi(l),m)
               enddo
            enddo
         enddo
         
         close(iham)

         deallocate(hij,indxi,indxj)
      
      else        

         do m=1,nblock
            do l=1,noffd
               vecout(indxi(l),m)=vecout(indxi(l),m)+hij(l)*vecin(indxj(l),m)
               vecout(indxj(l),m)=vecout(indxj(l),m)+hij(l)*vecin(indxi(l),m)
            enddo
         enddo

      endif

      return
      
    end subroutine hxpsi_all

!#######################################################################
! silstep: propagates the wavefunction vector vec0 forward by a
!          single timestep using a modified short iterative Lanczos 
!          algorithm to yield the wavefunction vector vecprop
!#######################################################################

    subroutine silstep(ista,matdim,noffd,vec0,vecprop)

      use iomod

      implicit none

      integer, intent(in)                  :: matdim
      integer*8, intent(in)                :: noffd
      integer                              :: ista,i,j,n,info,truedim
      real(d), dimension(matdim)           :: vec0,vecprop
      real(d), dimension(:,:), allocatable :: qmat,eigvec
      real(d), dimension(:), allocatable   :: r,q,v,alpha,beta,&
                                              eigval,work,a,tmparr
      real(d)                              :: dp,norm,err,dtau

!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
      allocate(qmat(matdim,krydim))
      allocate(r(matdim))
      allocate(q(matdim))
      allocate(v(matdim))
      allocate(alpha(krydim))
      allocate(beta(krydim))
      allocate(eigvec(krydim,krydim))
      allocate(eigval(krydim))
      allocate(tmparr(krydim))
      allocate(a(krydim))
      
!-----------------------------------------------------------------------
! Generate the Lanczos vectors
!-----------------------------------------------------------------------
      qmat=0.0d0

      ! The first vector is either |Psi_n(t)> (unmodified algorithm) 
      ! or |Psi_n(t)> orthogonalised against the already propagated 
      ! wavefunctions and then renormalised (modified algorithm)
      if (iortho.eq.2) then
         do i=1,ista-1
            dp=dot_product(vec_new(:,i),vec0)
            vec0=vec0-dp*vec_new(:,i)
         enddo
         dp=dot_product(vec0,vec0)
         vec0=vec0/sqrt(dp)
      endif

      q=vec0
      qmat(:,1)=q

      ! alpha_1
      call hxkryvec(ista,1,matdim,noffd,q,r)
      alpha(1)=dot_product(q,r)

      ! beta_1
      r=r-alpha(1)*q
      beta(1)=sqrt(dot_product(r,r))

      truedim=1
      
      ! Remaining vectors
      do j=2,krydim
                 
         truedim=truedim+1

         ! Compute the next vector and pair of matrix elements
         v=q
         q=r/beta(j-1)
         qmat(:,j)=q
         call hxkryvec(ista,j,matdim,noffd,q,r)
         r=r-beta(j-1)*v
         alpha(j)=dot_product(q,r)
         r=r-alpha(j)*q
         beta(j)=sqrt(dot_product(r,r))

         ! Calculate the expansion of the propagated wavefunction in the
         ! current Lanczos state basis.
         ! If the error is below threshold, then exit here.
         ! Else, carry on and compute the next Lanczos vector.
         if (j.gt.2) then

            ! Diagonalise the Lanczos state representation of the
            ! Hamiltonian
            allocate(work((2*(truedim)-2)))
            eigval=alpha
            tmparr=beta
            call dstev('V',truedim,eigval(1:truedim),tmparr(1:truedim-1),&
                 eigvec(1:truedim,1:truedim),truedim,work,info)

            ! Calculate the epansion coefficients for |Psi(t0_dt)> in
            ! the Lanczos state basis
            a=0.0d0
            dtau=step
            do i=1,truedim
               do n=1,truedim
                  a(i)=a(i)+eigvec(i,n)*exp(-eigval(n)*dtau)*eigvec(1,n)
               enddo
            enddo            
            norm=sqrt(dot_product(a,a))
            a=a/norm

            ! Calcuate the error and exit if we are below
            ! threshold
            err=abs(a(truedim))
            deallocate(work)
            if (err.lt.toler) exit

         endif
         
      enddo

!-----------------------------------------------------------------------
! Calculate the wavefunction at time t0+dt, with dt being determined
! adaptively s.t. the estimated error in |Psi(t0+dt)> is below
! threshold.
!-----------------------------------------------------------------------
      dtau=step

10    continue
      a=0.0d0
      do j=1,truedim
         do n=1,truedim
            a(j)=a(j)+eigvec(j,n)*exp(-eigval(n)*dtau)*eigvec(1,n)
         enddo
      enddo
      
      ! OLD
!      vecprop=0.0d0
!      do j=1,truedim
!         vecprop=vecprop+a(j)*qmat(:,j)
!      enddo
!      norm=sqrt(dot_product(vecprop,vecprop))      
!      err=abs(a(truedim)/norm)
!      if (err.gt.toler) then
!         dtau=dtau/2.0d0
!         goto 10
!      endif
!      vecprop=vecprop/norm
      
      ! NEW
      ! For orthonormal Lanczos vectors, this holds true:
      norm=sqrt(dot_product(a,a))
      a=a/norm
      err=abs(a(truedim))
      if (err.gt.toler) then
         dtau=dtau/2.0d0
         goto 10
      endif
      vecprop=0.0d0
      do j=1,truedim
         vecprop=vecprop+a(j)*qmat(:,j)
      enddo
      
!-----------------------------------------------------------------------
! Update the propagation time for the current state
!-----------------------------------------------------------------------
      currtime(ista)=currtime(ista)+dtau

!-----------------------------------------------------------------------
! Save the Krylov subspace dimension that was used for the current
! state in this iteration
!-----------------------------------------------------------------------
      sildim(ista)=truedim
      
!-----------------------------------------------------------------------
! Deallocate arrays
!-----------------------------------------------------------------------
      deallocate(qmat)
      deallocate(r)
      deallocate(q)
      deallocate(v)
      deallocate(alpha)
      deallocate(beta)
      deallocate(eigvec)
      deallocate(eigval)
      deallocate(tmparr)
      deallocate(a)
      
      return
      
    end subroutine silstep

!#######################################################################
    
    subroutine hxkryvec(ista,krynum,matdim,noffd,vecin,vecout)

      use iomod, only: freeunit
      use constants
      use parameters
      
      implicit none

      integer, intent(in)        :: ista,matdim
      integer*8, intent(in)      :: noffd
      integer                    :: krynum,iham,nlim,i,j,k,l,m,n
      real(d), dimension(matdim) :: vecin,vecout
      real(d)                    :: dp
      character(len=70)          :: filename

      vecout=0.0d0

!-----------------------------------------------------------------------
! Q |Psi>
!-----------------------------------------------------------------------
      if (iortho.eq.2) then
         if (krynum.eq.2) then
            do i=1,ista-1
               dp=dot_product(vec_new(:,i),vecin)
               vecin=vecin-dp*vec_new(:,i)               
               dp=dot_product(vecin,vecin)
               vecin=vecin/sqrt(dp)
            enddo
         endif
      endif

!-----------------------------------------------------------------------
! H Q |Psi>
!
! Contribution from the on-diagonal elements of the Hamiltonian matrix
!-----------------------------------------------------------------------
      do n=1,matdim
         vecout(n)=hii(n)*vecin(n)
      enddo

!-----------------------------------------------------------------------
! H Q |Psi>
!
! Contribution from the off-diagonal elements of the Hamiltonian matrix
!-----------------------------------------------------------------------

      if (.not.lincore) then

         allocate(hij(maxbl),indxi(maxbl),indxj(maxbl))
      
         if (hamflag.eq.'i') then
            filename='SCRATCH/hmlt.offi'
         else if (hamflag.eq.'f') then
            filename='SCRATCH/hmlt.offc'
         endif
         
         open(iham,file=filename,status='old',access='sequential',&
              form='unformatted')
         
         do k=1,nrec
            read(iham) hij(:),indxi(:),indxj(:),nlim
            do l=1,nlim
               vecout(indxi(l))=vecout(indxi(l))+hij(l)*vecin(indxj(l))
               vecout(indxj(l))=vecout(indxj(l))+hij(l)*vecin(indxi(l))
            enddo
         enddo

         close(iham)
         
         deallocate(hij,indxi,indxj)

      else

         do l=1,noffd
            vecout(indxi(l))=vecout(indxi(l))+hij(l)*vecin(indxj(l))
            vecout(indxj(l))=vecout(indxj(l))+hij(l)*vecin(indxi(l))
         enddo

      endif

!-----------------------------------------------------------------------
! Q H Q |Psi>
!-----------------------------------------------------------------------
      if (iortho.eq.2) then
         do i=1,ista-1
            dp=dot_product(vec_new(:,i),vecout)
            vecout=vecout-dp*vec_new(:,i)
         enddo
      endif

      return
      
    end subroutine hxkryvec
      
!#######################################################################

    subroutine check_conv(matdim,noffd)

      implicit none

      integer, intent(in)                  :: matdim
      integer*8, intent(in)                :: noffd
      integer                              :: k
      real(d), dimension(:,:), allocatable :: hpsi
      real(d), dimension(:), allocatable   :: resvec
      real(d), dimension(nblock)           :: hpsi2,h2psi
      
!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
      allocate(hpsi(matdim,nblock))
      allocate(resvec(matdim))

!-----------------------------------------------------------------------
! Residuals r_k=|| H |psi_k> - E_k |psi_k> ||
!-----------------------------------------------------------------------      
      call hxpsi_all(matdim,noffd,vec_new,hpsi)
      
      do k=1,nblock
         resvec=hpsi(:,k)-ener(k)*vec_new(:,k)
         res(k)=dot_product(resvec,resvec)
         res(k)=sqrt(res(k))
         if (res(k).lt.eps) lconv(k)=.true.
      enddo

      ! No. converged states (N.B. this runs over nstates rather than
      ! nblock as higher-lying states may converge before the lowest
      ! nstates states of interest)
      nconv=0
      do k=1,nstates
         if (res(k).lt.eps) nconv=nconv+1
      enddo

!-----------------------------------------------------------------------
! Deallocate arrays
!-----------------------------------------------------------------------
      deallocate(hpsi)
      deallocate(resvec)

      return
      
    end subroutine check_conv

!#######################################################################

    subroutine sortwf(matdim)

      use misc, only: dsortindxa1
      
      implicit none

      integer, intent(in)                  :: matdim
      integer                              :: i
      integer, dimension(nblock)           :: indx,itmp
      real(d), dimension(nblock)           :: tmpval
      real(d), dimension(:,:), allocatable :: tmpvec

      allocate(tmpvec(matdim,nblock))

      call dsortindxa1('A',nblock,ener,indx)

      ! Wavefunctions
      do i=1,nblock
         tmpvec(:,i)=vec_new(:,indx(i))
      enddo
      vec_new=tmpvec
      
      ! Energies
      do i=1,nblock
         tmpval(i)=ener(indx(i))
      enddo
      ener=tmpval

      ! Residuals
      do i=1,nblock
         tmpval(i)=res(indx(i))
      enddo
      res=tmpval

      ! Current times
      do i=1,nblock
         tmpval(i)=currtime(indx(i))
      enddo
      currtime=tmpval

      ! Krylov subspace dimensions
      do i=1,nblock
         itmp(i)=sildim(indx(i))
      enddo
      sildim=itmp
      
      deallocate(tmpvec)
      
      return
      
    end subroutine sortwf
      
!#######################################################################

    subroutine wrtable(k)
      
      use constants
      use channels
      use parameters

      implicit none

      integer          :: k,i,j
      character(len=1) :: aconv

!-----------------------------------------------------------------------
! Table header
!-----------------------------------------------------------------------
      if (k.eq.0) then
         write(ilog,'(64a)') ('*',j=1,64)
         write(ilog,'(a)') 'Iteration   Time   Kdim    Energies    &
              Residuals       Converged'         
         write(ilog,'(64a)') ('*',j=1,64)
      endif

!-----------------------------------------------------------------------
! Information from the current iteration
!-----------------------------------------------------------------------
      write(ilog,*)
      do i=1,nstates
         if (lconv(i)) then
            aconv='y'
         else
            aconv='n'
         endif         
         if (i.eq.1) then
            write(ilog,'(i4,3x,F10.3,2x,i3,3x,F12.7,3x,E13.7,3x,a1)') &
                 k,currtime(i),sildim(i),ener(i)*eh2ev,res(i),aconv
         else
            write(ilog,'(7x,F10.3,2x,i3,3x,F12.7,3x,E13.7,3x,a1)') &
                 currtime(i),sildim(i),ener(i)*eh2ev,res(i),aconv
         endif
      enddo

      return

    end subroutine wrtable

!#######################################################################

    subroutine wreigenpairs

      implicit none

      integer :: idav,i
      
!-----------------------------------------------------------------------
! Open the Davidson vector file
!-----------------------------------------------------------------------
      call freeunit(idav)
      open(unit=idav,file=vecfile,status='unknown',&
           access='sequential',form='unformatted')

!-----------------------------------------------------------------------
! Write the eigenpairs to file
!-----------------------------------------------------------------------
      do i=1,nstates
         write(idav) i,ener(i),vec_new(:,i)
      enddo

!-----------------------------------------------------------------------
! Close the Davidson vector file
!-----------------------------------------------------------------------
      close(idav)

      return
      
    end subroutine wreigenpairs

!#######################################################################

    subroutine finalise

      implicit none

      deallocate(hii)
      deallocate(vec_old)
      deallocate(vec_new)
      deallocate(hxvec)
      deallocate(ener)
      deallocate(lconv)
      deallocate(sildim)
      if (allocated(hij)) deallocate(hij)
      if (allocated(indxi)) deallocate(indxi)
      if (allocated(indxj)) deallocate(indxj)
      
      return
      
    end subroutine finalise
      
!#######################################################################

    subroutine siblstep(matdim,noffd,vec0,vecprop)

      use iomod

      implicit none

      integer, intent(in)                  :: matdim
      integer*8, intent(in)                :: noffd
      integer                              :: blocksize,nvec,info,&
                                              i,j,k,m,n,i1,j1,k1,k2,&
                                              upper
      real(d), dimension(matdim,nblock)    :: vec0,vecprop
      real(d), dimension(:,:), allocatable :: qmat1,qmat2,umat,rmat,&
                                              tmpmat,amat,bmat,tmat,&
                                              lancvec
      real(d), dimension(nblock)           :: tau
      real(d), dimension(nblock)           :: work
      real(d), dimension(:,:), allocatable :: eigvec
      real(d), dimension(:), allocatable   :: eigval

!-----------------------------------------------------------------------
! Allocate and initialise the block-Lanczos arrays
!-----------------------------------------------------------------------
      ! Temporary: use blocksize variable name from the block_lanczos 
      ! code
      blocksize=nblock
      
      ! Here we are taking krydim to be the maximum no. of 
      ! block-Lanczos iterations
      nvec=blocksize*krydim

      allocate(qmat1(matdim,blocksize))
      allocate(qmat2(matdim,blocksize))
      allocate(umat(matdim,blocksize))
      allocate(rmat(matdim,blocksize))
      allocate(tmpmat(matdim,blocksize))
      allocate(amat(blocksize,blocksize))
      allocate(bmat(blocksize,blocksize))
      allocate(tmat(nvec,nvec))
      allocate(lancvec(matdim,nvec))
      allocate(eigval(nvec))
      allocate(eigvec(nvec,nvec))
      qmat1=0.0d0
      qmat2=0.0d0
      umat=0.0d0
      rmat=0.0d0
      amat=0.0d0
      bmat=0.0d0
      tmat=0.0d0
      lancvec=0.0d0

!-----------------------------------------------------------------------
! Set the initial Lanczos vectors
!-----------------------------------------------------------------------
      qmat2=vec0

!-----------------------------------------------------------------------
! Perform the block-Lanczos iterations
!-----------------------------------------------------------------------
      do j=1,krydim

         !--------------------------------------------------------------
         ! (1) Save the Lanczos vectors from the last iteration
         !--------------------------------------------------------------
         k1=(j-1)*blocksize+1
         k2=j*blocksize
         lancvec(:,k1:k2)=qmat2(:,:)

         !--------------------------------------------------------------
         ! (2) Calculate the current block of on-diagonal elements of
         !     the T-matrix
         !--------------------------------------------------------------
         call hxpsi_all(matdim,noffd,qmat2,umat)

         call dgemm('N','T',matdim,blocksize,blocksize,1.0d0,qmat1,matdim,bmat,&
              blocksize,0.0d0,tmpmat,matdim)
         
         umat=umat-tmpmat
         
         call dgemm('T','N',blocksize,blocksize,matdim,1.0d0,qmat2,matdim,umat,&
              matdim,0.0d0,amat,blocksize)

         !--------------------------------------------------------------
         ! (3) Calculate the next block of Krylov vectors
         !--------------------------------------------------------------
         call dgemm('N','N',matdim,blocksize,blocksize,1.0d0,qmat2,matdim,amat,&
              blocksize,0.0d0,tmpmat,matdim)

         rmat=umat-tmpmat

         !--------------------------------------------------------------
         ! (4) Compute the QR factorization of the matrix of Krylov 
         !     vectors
         !--------------------------------------------------------------
         ! dgeqrf will overwrite rmat, so instead use a copy of this
         ! matrix
         tmpmat=rmat

         ! Compute the current block of off-diagonal elements of
         ! the T-matrix
         call dgeqrf(matdim,blocksize,tmpmat,matdim,tau,work,blocksize,info)
         if (info.ne.0) then
            write(ilog,'(/,2x,a,/)') 'dqerf failed in siblstep'
            STOP
         endif

         ! Note that the B-matrix is upper-triangular
         bmat=0.0d0
         do k=1,blocksize
            do i=1,k
               bmat(i,k)=tmpmat(i,k)
            enddo
         enddo

         ! Extract the next block of Lanczos vectors
         call dorgqr(matdim,blocksize,blocksize,tmpmat,matdim,tau,work,&
              blocksize,info)
         if (info.ne.0) then
            write(ilog,'(/,2x,a,/)') 'dorgqr failed in siblstep'
            STOP
         endif

         ! Update the matrices of Lanczos vectors
         qmat1=qmat2
         qmat2=tmpmat

         !--------------------------------------------------------------
         ! (5) Fill in the next block of the T-matrix array
         !--------------------------------------------------------------
         i1=0                               ! Initialise the column counter
         do m=(j-1)*blocksize+1,j*blocksize ! Loop over columns of T_j
            i1=i1+1                         ! Increment the column counter
            if (j.lt.ncycles) then
               upper=(j+1)*blocksize
            else
               upper=j*blocksize
            endif
            j1=0                            ! Initialise the row counters
            k1=0
            k2=0
            do n=(j-1)*blocksize+1,upper    ! Loop over rows of T_j
               j1=j1+1                      ! Increment the main row counter
               if (j1.le.blocksize) then    ! Contribution from A_j
                  k1=k1+1
                  tmat(n,m)=amat(k1,i1)
               else                         ! Contribution from B_j
                  k2=k2+1
                  tmat(n,m)=bmat(k2,i1)
               endif
               tmat(m,n)=tmat(n,m)
            enddo
         enddo

      enddo

!-----------------------------------------------------------------------
! Deallocate the block-Lanczos arrays now that they are not needed
!-----------------------------------------------------------------------
      deallocate(qmat1)
      deallocate(qmat2)
      deallocate(rmat)
      deallocate(amat)
      deallocate(bmat)
      deallocate(tmpmat)
      deallocate(umat)

!-----------------------------------------------------------------------
! Diagonalise the block-Lanczos state representation of the Hamiltonian
!-----------------------------------------------------------------------
      call diagmat_banded(tmat,eigvec,eigval,nvec,blocksize)

!-----------------------------------------------------------------------
! Propagate each wavefunction forwards in time to t0+dt
!-----------------------------------------------------------------------
      ! (1) Construct the block-Lanczos state representation of the
      !     negative imaginary time-evolution operator U(dt)=exp(-Hdt)
      allocate(umat(nvec,nvec))
      umat=0.0d0

      do i=1,nvec
         do j=1,nvec
            do k=1,nvec
               umat(i,j)=umat(i,j)+&
                    eigvec(i,k)*exp(-eigval(k)*step)*eigvec(j,k)
            enddo
         enddo
      enddo

      ! (2) Calculate the propagated wavefunctions
      vecprop=0.0d0
      do n=1,blocksize

         ! Normalise the expansion coefficients for the
         ! current wavefunction
         umat(:,n)=umat(:,n)/sqrt(dot_product(umat(:,n),umat(:,n)))

         ! Expansion of Psi(t0+dt) in the Lanczos state basis
         do j=1,nvec
            vecprop(:,n)=vecprop(:,n)+umat(j,n)*lancvec(:,j)
         enddo

      enddo

      deallocate(umat)

!-----------------------------------------------------------------------
! Orthonormalisation of the propagated wavefunctions via the QR 
! factorisation of the matrix of these wavefunctions.
!-----------------------------------------------------------------------
      call dgeqrf(matdim,blocksize,vecprop,matdim,tau,work,blocksize,info)

      call dorgqr(matdim,blocksize,blocksize,vecprop,matdim,tau,work,&
           blocksize,info)

!-----------------------------------------------------------------------
! Deallocate any remaining allocated arrays
!-----------------------------------------------------------------------
      deallocate(tmat)
      deallocate(lancvec)
      deallocate(eigval)
      deallocate(eigvec)

      currtime(:)=currtime(:)+step
      sildim(:)=krydim

      return

    end subroutine siblstep

!#######################################################################

    subroutine diagmat_banded(matrix,eigvec,eigval,nvec,blocksize)

      implicit none
      
      integer                              :: nvec,blocksize
      integer                              :: i,j,iupper
      real(d), dimension(nvec,nvec)        :: matrix

      integer                              :: kd,ldab,error
      real(d), dimension(blocksize+1,nvec) :: ab
      real(d), dimension(nvec)             :: eigval
      real(d), dimension(nvec,nvec)        :: eigvec
      real(d), dimension(3*nvec-2)         :: work

!-----------------------------------------------------------------------
! Set dimensions required to be passed to dsbev
!-----------------------------------------------------------------------
      kd=blocksize
      ldab=blocksize+1

!-----------------------------------------------------------------------
! Fill in the array ab holding the upper triangle of the projection of
! the Hamiltonian onto the space spanned by the Lanczos vectors
!-----------------------------------------------------------------------
      ab=0.0d0
      do j=1,nvec
         iupper=min(nvec,j+kd)
         do i=j,iupper
            ab(1+i-j,j)=matrix(i,j)
         enddo
      enddo

!-----------------------------------------------------------------------
! Diagonalise the projection of the Hamiltonian onto the space spanned
! by the Lanczos vectors
!-----------------------------------------------------------------------
      call dsbev('V','L',nvec,kd,ab,ldab,eigval,eigvec,nvec,work,error)

      if (error.ne.0) then
         write(ilog,'(/,2x,3a,/)') 'Diagonalisation of the Lanczos ',&
              'representation of the Hamiltonian failed in ',&
              'subroutine diagmat_banded (called from siblstep).'
         STOP
      endif

      return

    end subroutine diagmat_banded

!#######################################################################
    
  end module relaxmod