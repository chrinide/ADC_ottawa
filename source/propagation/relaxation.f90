!#######################################################################
! Routines for the calcuation of eigenstates of the ADC(2) Hamiltonian
! via imaginary time wavepacket propagations using the XSIL
! algorithm.
!#######################################################################

  module relaxmod

    use iomod
    use constants
    use parameters
    use channels
    use timingmod

    save

    integer                              :: maxbl,nrec,nblock,nconv,&
                                            nstates,krydim,niter,&
                                            subdim,nmult
    integer, dimension(:), allocatable   :: indxi,indxj,sildim
    real(d), dimension(:), allocatable   :: hii,hij,ener,res,currtime
    real(d), dimension(:,:), allocatable :: vec_old,vec_new,hxvec
    real(d)                              :: step,eps,toler
    character(len=36)                    :: vecfile 
    character(len=60)                    :: fileon,fileoff
    logical, dimension(:), allocatable   :: lconv
    logical                              :: lrdadc1,lrandom,lsub

    ! XSIL arrays
    integer                              :: maxvec,maxdim,nlin
    real(d), dimension(:,:), allocatable :: subhmat,subsmat,lancvec,&
                                            vec_conv,alphamat,betamat
    
  contains

!#######################################################################

    subroutine relaxation(matdim,noffd)

      use tdsemod
      
      implicit none

      integer, intent(in)      :: matdim
      integer*8, intent(in)    :: noffd
      integer                  :: k
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
! If the matrix-vector multiplication is to proceed in-core, then
! load the non-zero elements of the Hamiltonian matrix into memory
!-----------------------------------------------------------------------
      if (hincore) call load_hamiltonian(fileon,fileoff,matdim,noffd)

!-----------------------------------------------------------------------
! Set the initial vectors
!-----------------------------------------------------------------------
      call initvec(matdim,noffd)

!-----------------------------------------------------------------------
! Perform the relaxation calculation using the XSIL algorithm
!-----------------------------------------------------------------------
      call xsil_rlx(matdim,noffd)
      
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
! Output timings and the no. matrix-vector multiplications
!-----------------------------------------------------------------------    
      write(ilog,'(/,a,1x,i4)') 'No. matrix-vector multiplications:',&
           nmult

      call times(tw2,tc2)
      write(ilog,'(/,a,1x,F9.2,1x,a)') 'Time taken:',tw2-tw1," s"

      return
      
    end subroutine relaxation

!#######################################################################

    subroutine xsil_rlx(matdim,noffd)

      implicit none

      integer, intent(in)                :: matdim
      integer*8, intent(in)              :: noffd
      integer                            :: s,n,i,ncurr
      real(d), dimension(:), allocatable :: vec0,vecprop
      real(d)                            :: energy,residual

!-----------------------------------------------------------------------
! Initialisation
!-----------------------------------------------------------------------
      ! Maximum no. of vectors that will be generated per state.
      ! Note that this is set to the maximum subspace dimension plus
      ! maxdim/krydim as one extra Lanczos vector is required to be
      ! calculated and stored each timestep in order to calculate the
      ! matrix elements with the vectors of the previous timesteps
      if (maxdim.lt.0) maxdim=2*krydim
      if (mod(maxdim,krydim).ne.0) then
         errmsg='maxvec must be an integer multiple of krydim...'
         call error_control
      endif
      maxvec=maxdim+maxdim/krydim

      ! Representation of the Hamiltonian in the variational subspace
      allocate(subhmat(maxvec,maxvec))
      subhmat=0.0d0

      ! Overlaps of the variational subspace vectors
      allocate(subsmat(maxvec,maxvec))
      subsmat=0.0d0

      ! Vectors spanning the variational subspace
      allocate(lancvec(matdim,maxvec))
      lancvec=0.0d0

      ! |Psi(0)>
      allocate(vec0(matdim))
      vec0=0.0d0

      ! |Psi(dt)>
      allocate(vecprop(matdim))
      vecprop=0.0d0

      ! Converged states
      allocate(vec_conv(matdim,nblock))
      vec_conv=0.0d0
      
      ! Intra-timestep Lanczos state Hamiltonian matrix elements
      allocate(alphamat(krydim,niter))
      alphamat=0.0d0
      allocate(betamat(krydim,niter))
      betamat=0.0d0
      
      ! No. converged states
      nconv=0

!-----------------------------------------------------------------------
! Output some information about the relaxation calculation
!-----------------------------------------------------------------------
      write(ilog,'(2x,a,/)') 'Algorithm: Lanczos-Liu'
      write(ilog,'(2x,a,F12.7,/)') 'Timestep:',step
      write(ilog,'(2x,a,i3,/)') 'Max. Krylov subspace dimension:',&
           krydim

!-----------------------------------------------------------------------
! Perform the relaxation calculations using the SIL-Liu algorithm
!-----------------------------------------------------------------------
      ! Loop over states
      do s=1,nstates

         ! Initialisation
         subhmat=0.0d0
         subsmat=0.0d0
         lancvec=0.0d0
         alphamat=0.0d0
         betamat=0.0d0
         ncurr=0
         nlin=0
         vec0=vec_old(:,s)

         ! Write the table header for the current state
         call wrheader_1vec(s)

         ! Output the initial energy and residual
         call residual_1vec(vec0,matdim,noffd,energy,residual)
         call wrtable_1vec(0,energy,residual)

         ! Loop over timesteps
         do n=1,niter

            ! Subspace collapse
            if (ncurr*(krydim+1).eq.maxvec) then
               call collapse_subspace(matdim)
               ncurr=ncurr-1
            endif

            ! Current no. steps used in the subspace basis
            ! generation (N.B., after the first subspace
            ! collapse, this stays constant due to the
            ! subsequent collapsing of the subspace on every
            ! iteration)
            ncurr=ncurr+1

            ! Generation of the Lanczos vectors for the current
            ! timestep
            call get_lancvecs_current(s,ncurr,matdim,noffd,vec0)
            
            ! Calculation of the subspace Hamiltonian and overlap
            ! matrix elements
            call subspace_matrices(ncurr)

            ! Calculate |Psi(t+dt)>
            call solve_subspace_tdse(ncurr,vecprop,matdim)

            ! Orthogonalise |Psi(t+dt)> against the previously
            ! converged states
            do i=1,s-1
               vecprop=vecprop&
                    -dot_product(vecprop,vec_conv(:,s))*vec_conv(:,s)
            enddo
            vecprop=vecprop/sqrt(dot_product(vecprop,vecprop))

            ! Calculate the residual
            call residual_1vec(vecprop,matdim,noffd,energy,residual)

            ! Reset vec0
            vec0=vecprop

            ! Output the residual and energy for the current iteration
            call wrtable_1vec(n,energy,residual)

            ! Exit if convergence has been reached
            if (residual.le.eps) then
               ! Update the number of converged states
               nconv=nconv+1
               ! Save the converged state and energy
               vec_new(:,s)=vecprop
               vec_conv(:,s)=vecprop
               ener(s)=energy
               ! Output some things
               write(ilog,'(/,2x,a,/)') 'Converged'
               ! Terminate the relaxation for the current state
               exit
            endif

         enddo

         ! Quit here if convergence was not reached for the
         ! current state
         if (residual.gt.eps) then
            write(errmsg,'(a,x,i2)')&
                 'Convergence not reached for state:',s
            call error_control
         endif

      enddo

!-----------------------------------------------------------------------
! Finalisation
!-----------------------------------------------------------------------
      deallocate(subhmat)
      deallocate(subsmat)
      deallocate(lancvec)
      deallocate(vecprop)
      deallocate(vec_conv)
      
      return
      
    end subroutine xsil_rlx

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
         toler=siltol
         maxdim=maxsubdim
         subdim=guessdim
      else if (hamflag.eq.'f') then
         vecfile=davname_f
         nstates=davstates_f
         nblock=dmain_f
         krydim=kdim_f
         step=stepsize_f
         eps=davtol_f
         niter=maxiter_f
         toler=siltol_f
         maxdim=maxsubdim
         subdim=guessdim_f
      endif

!-----------------------------------------------------------------------
! Files holding the non-zero elements of the Hamiltonian matrix
!-----------------------------------------------------------------------
      if (hamflag.eq.'i') then
         fileon='SCRATCH/hmlt.diai'
         fileoff='SCRATCH/hmlt.offi'
      else if (hamflag.eq.'f') then
         fileon='SCRATCH/hmlt.diac'
         fileoff='SCRATCH/hmlt.offc'
      endif
      
!-----------------------------------------------------------------------
! Allocation of arays
!-----------------------------------------------------------------------
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
      use parameters
      use tdsemod
      
      implicit none

      integer, intent(in)   :: matdim
      integer*8, intent(in) :: noffd
      real(d)               :: mem

      mem=0.0d0

      ! Two-electron integrals held in-core
      mem=mem+8.0d0*(nbas**4)/1024.0d0**2

      ! kpq
      mem=mem+8.0d0*7.0d0*(1+nbas**2*4*nocc**2)/1024.0d0**2
      
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
         hincore=.true.
         write(ilog,'(2x,a,/)') 'Matrix-vector multiplication will &
              proceed in-core'
      else
         hincore=.false.
         write(ilog,'(2x,a,/)') 'Matrix-vector multiplication will &
              proceed out-of-core'
      endif

      return

    end subroutine isincore

!#######################################################################

    subroutine initvec(matdim,noffd)

      implicit none

      integer, intent(in)   :: matdim
      integer*8, intent(in) :: noffd

      ! Determine whether the initial vectors are to be constructed from
      ! the ADC(1) eigenvectors, random noise, the eigenvectors of the
      ! Hamiltonian represented in a subspace of ISs, or as single ISs
      lrdadc1=.false.
      lrandom=.false.
      lsub=.false.
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
      if (hamflag.eq.'i'.and.lsubdiag) then
         lsub=.true.
      else if (hamflag.eq.'f'.and.lsubdiag_f) then
         lsub=.true.
      endif
      
      if (lrdadc1) then
         ! Construct the initial vectors from the ADC(1) eigenvectors
         call initvec_adc1
      else if (lrandom) then
         ! Construct the initial vectors as random orthonormal unit
         ! vectors
         call initvec_random(matdim)
      else if (lsub) then
         ! Construct the initial vectors from the eigenvectors of the
         ! Hamiltonian represented in a subspace of ISs
         call initvec_subdiag(matdim,noffd)
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
! Set the initial vectors
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
      integer             :: n,k,i,j
      real(d)             :: ftmp,dp

      ! Generate a set of random vectors
      do n=1,nblock
         do k=1,matdim
            call random_number(ftmp)
            vec_old(k,n)=ftmp
         enddo
         ftmp=dot_product(vec_old(:,n),vec_old(:,n))
         vec_old(:,n)=vec_old(:,n)/sqrt(ftmp)
      enddo

      ! Orthogonalisation
      do i=1,nblock
         do j=1,i-1
            dp=dot_product(vec_old(:,i),vec_old(:,j))
            vec_old(:,i)=vec_old(:,i)-dp*vec_old(:,j)
         enddo
      enddo
      do i=1,nblock
         do j=1,i-1
            dp=dot_product(vec_old(:,i),vec_old(:,j))
            vec_old(:,i)=vec_old(:,i)-dp*vec_old(:,j)
         enddo
      enddo

      ! Normalisation
      do i=1,nblock
         dp=dot_product(vec_old(:,i),vec_old(:,i))
         vec_old(:,i)=vec_old(:,i)/sqrt(dp)
      enddo
      
      return
      
    end subroutine initvec_random

!#######################################################################

    subroutine initvec_subdiag(matdim,noffd)

      use misc, only: dsortindxa1
      use tdsemod
      
      implicit none

      integer, intent(in)                  :: matdim
      integer*8, intent(in)                :: noffd
      integer, dimension(:), allocatable   :: full2sub,sub2full,&
                                              indxhii
      integer                              :: i,j,k,i1,j1,e2,error,&
                                              iham,nlim,l
      real(d), dimension(:,:), allocatable :: hsub
      real(d), dimension(:), allocatable   :: subeig,work
      character(len=70)                    :: filename

!-----------------------------------------------------------------------
! Output where we are at
!-----------------------------------------------------------------------
      write(ilog,'(2x,a,/)') 'Generating guess vectors by &
           diagonalising a subspace Hamiltonian...'

!-----------------------------------------------------------------------
! Read the on-diagonal elements from file
!-----------------------------------------------------------------------
      allocate(hii(matdim))

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
      
!-----------------------------------------------------------------------
! Sort the on-diagonal Hamiltonian matrix elements in order of
! ascending value
!-----------------------------------------------------------------------
      allocate(indxhii(matdim))
      call dsortindxa1('A',matdim,hii,indxhii)

!-----------------------------------------------------------------------
! Ensure that the subdim'th IS is not degenerate with subdim+1'th IS,
! and if it is, increase subdim accordingly
!-----------------------------------------------------------------------
5     continue
      if (abs(hii(indxhii(subdim))-hii(indxhii(subdim+1))).lt.1e-6_d) then
         subdim=subdim+1
         goto 5
      endif

!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
      allocate(full2sub(matdim))
      allocate(sub2full(subdim))
      allocate(hsub(subdim,subdim))
      allocate(subeig(subdim))
      allocate(work(3*subdim))

!-----------------------------------------------------------------------
! Set the full space-to-subsace mappings
!-----------------------------------------------------------------------
      full2sub=0
      do i=1,subdim
         k=indxhii(i)
         sub2full(i)=k
         full2sub(k)=i
      enddo
      
!-----------------------------------------------------------------------
! Construct the Hamiltonian matrix in the subspace
!-----------------------------------------------------------------------
      hsub=0.0d0

      ! (i) On-diagonal elements
      do i=1,subdim
         k=sub2full(i)
         hsub(i,i)=hii(k)
      enddo

      ! (ii) Off-diagonal elements
      !
      ! Open the off-diagonal element file
      call freeunit(iham)


      if (hamflag.eq.'i') then
         filename='SCRATCH/hmlt.offi'
      else if (hamflag.eq.'f') then
         filename='SCRATCH/hmlt.offc'
      endif
      open(iham,file=filename,status='old',access='sequential',&
           form='unformatted')



      ! Allocate arrays
      allocate(hij(maxbl),indxi(maxbl),indxj(maxbl))
      ! Loop over records
      do k=1,nrec
         read(iham) hij(:),indxi(:),indxj(:),nlim
         ! Loop over the non-zero elements of the full space
         ! Hamiltonian in the current record
         do l=1,nlim
            ! Indices of the current off-diagonal element of the
            ! full space Hamiltonian
            i=indxi(l)
            j=indxj(l)
            ! If both indices correspond to subspace ISs, then
            ! add the element to subspace Hamiltonian
            if (full2sub(i).ne.0.and.full2sub(j).ne.0) then
               i1=full2sub(i)
               j1=full2sub(j)
               hsub(i1,j1)=hij(l)
               hsub(j1,i1)=hsub(i1,j1)
            endif
         enddo
      enddo
      ! Close the off-diagonal element file
      close(iham)
      ! Deallocate arrays
      deallocate(hij,indxi,indxj)

!-----------------------------------------------------------------------
! Diagonalise the subspace Hamiltonian
!-----------------------------------------------------------------------
      e2=3*subdim
      call dsyev('V','U',subdim,hsub,subdim,subeig,work,e2,error)

      if (error.ne.0) then
         errmsg='The diagonalisation of the subspace Hamiltonian failed.'
         call error_control
      endif

!-----------------------------------------------------------------------
! Construct the initial vectors from the subspace vectors.
! Note that after calling dsyev, hsub now holds the eigenvectors of
! the subspace Hamiltonian.
!-----------------------------------------------------------------------
      vec_old=0.0d0
      do i=1,nblock
         do j=1,subdim
            k=sub2full(j)
            vec_old(k,i)=hsub(j,i)            
         enddo
      enddo
      
!-----------------------------------------------------------------------
! Deallocate arrays
!-----------------------------------------------------------------------
      deallocate(hii)
      deallocate(indxhii)
      deallocate(full2sub)
      deallocate(sub2full)
      deallocate(hsub)
      deallocate(subeig)
      deallocate(work)

      return
      
    end subroutine initvec_subdiag
      
!#######################################################################
    
    subroutine collapse_subspace(matdim)

      implicit none

      integer, intent(in)                  :: matdim
      integer                              :: n
      real(d), dimension(:,:), allocatable :: tmp

!-----------------------------------------------------------------------
! Reorder the lancvec, subhmat, subsmat, alphamat and betamat arrays
! s.t. the elements corresponding to the last iteration are removed
!-----------------------------------------------------------------------
      ! lancvec: removal of elements corresponding to krydim+1
      ! vectors
      allocate(tmp(matdim,maxvec-(krydim+1)))
      tmp=lancvec(:,krydim+2:maxvec)
      lancvec(:,1:maxvec-(krydim+1))=tmp
      deallocate(tmp)

      ! subsmat and subhmat: removal of elements corresponding
      ! to krydim vectors
      allocate(tmp(maxvec-krydim,maxvec-krydim))
      tmp=subsmat(krydim+1:maxvec,krydim+1:maxvec)
      subsmat(1:maxvec-krydim,1:maxvec-krydim)=tmp
      tmp=subhmat(krydim+1:maxvec,krydim+1:maxvec)
      subhmat(1:maxvec-krydim,1:maxvec-krydim)=tmp
      deallocate(tmp)

      ! alphamat and betamat: removal of elements corresponding
      ! to krydim vectors
      n=maxvec/(krydim+1)
      allocate(tmp(krydim,n-1))
      tmp=alphamat(:,2:n)
      alphamat(:,1:n-1)=tmp
      tmp=betamat(:,2:n)
      betamat(:,1:n-1)=tmp
      deallocate(tmp)

      return

    end subroutine collapse_subspace

!#######################################################################

    subroutine get_lancvecs_current(ista,istep,matdim,noffd,vec0)

      use tdsemod
      
      implicit none

      integer, intent(in)                  :: matdim
      integer*8, intent(in)                :: noffd
      integer                              :: ista,istep,i,j,i1,j1,k1
      real(d)                              :: dp,norm
      real(d), dimension(matdim)           :: vec0
      real(d), dimension(:), allocatable   :: r,q,v,alpha,beta

!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
      allocate(r(matdim))
      allocate(q(matdim))
      allocate(v(matdim))
      allocate(alpha(krydim))
      allocate(beta(krydim))
      
!-----------------------------------------------------------------------
! Index of the first Lanczos vector
!-----------------------------------------------------------------------
      k1=(istep-1)*(krydim+1)+1

!-----------------------------------------------------------------------
! The first vector is |Psi_n(t)> orthogonalised against the previously
! converged states and then renormalised
!----------------------------------------------------------------------- 
      lancvec(:,k1)=vec0(:)

      do i=1,ista-1
         dp=dot_product(vec_conv(:,i),lancvec(:,k1))
         lancvec(:,k1)=lancvec(:,k1)-dp*vec_conv(:,i)
      enddo
      dp=dot_product(lancvec(:,k1),lancvec(:,k1))
      lancvec(:,k1)=lancvec(:,k1)/sqrt(dp)

      q=lancvec(:,k1)

      ! alpha_1
      call matxvec(matdim,noffd,q,r)
      r=-r
      nmult=nmult+1
      
      alpha(1)=dot_product(q,r)
      
      ! beta_1
      r=r-alpha(1)*q
      beta(1)=sqrt(dot_product(r,r))

!-----------------------------------------------------------------------      
! Remaining vectors
!-----------------------------------------------------------------------
      j1=1
      do j=k1+1,istep*(krydim+1)-1
         j1=j1+1

         ! Compute the next vector and pair of matrix elements
         v=q
         q=r/beta(j1-1)

         lancvec(:,j)=q

         call matxvec(matdim,noffd,q,r)
         r=-r
         nmult=nmult+1

         r=r-beta(j1-1)*v
         alpha(j1)=dot_product(q,r)
         r=r-alpha(j1)*q
         beta(j1)=sqrt(dot_product(r,r))
         
      enddo

      ! Calculate the last Lanczos state vector, which is required
      ! for the calculation of the inter-timestep Hamiltonian
      ! matrix elements
      q=r/beta(krydim)
      lancvec(:,istep*(krydim+1))=q

!-----------------------------------------------------------------------
! Fill in the current intra-timestep block of the subspace Hamiltonian
! and overlap matrices, noting that the Lanczos vectors are orthonormal
!-----------------------------------------------------------------------
      ! On-diagonal terms
      do i=1,krydim
         i1=(istep-1)*krydim+i
         subhmat(i1,i1)=alpha(i)
         subsmat(i1,i1)=1.0d0
      enddo

      ! Off-diagonal terms
      do i=1,krydim-1
         i1=(istep-1)*krydim+i
         subhmat(i1,i1+1)=beta(i)
         subhmat(i1+1,i1)=subhmat(i1,i1+1)
      enddo

      ! alpha and beta arrays: it is useful to save these for use in 
      ! the calculation of inter-timestep Hamiltonian matrix elements
      do i=1,krydim
         alphamat(i,istep)=alpha(i)
         betamat(i,istep)=beta(i)
      enddo

!-----------------------------------------------------------------------
! Deallocate arrays
!-----------------------------------------------------------------------
      deallocate(r)
      deallocate(q)
      deallocate(v)
      deallocate(alpha)
      deallocate(beta)

      return
      
    end subroutine get_lancvecs_current

!#######################################################################

    subroutine subspace_matrices(istep)

      implicit none

      integer :: istep,n,i,j,i1,j1,k

!----------------------------------------------------------------------
! Off-diagonal elements between the Lanczos vectors of the current
! and previous timesteps
!----------------------------------------------------------------------
      ! Loop over previous timesteps
      do n=1,istep-1

         ! Loop over the Lanczos vectors of the nth timestep
         i1=(n-1)*krydim
         do i=(n-1)*(krydim+1)+1,n*(krydim+1)-1

            i1=i1+1
            
            ! Loop over the Lanczos vectors of the current timestep
            k=0
            j1=(istep-1)*krydim
            do j=(istep-1)*(krydim+1)+1,istep*(krydim+1)-1
               k=k+1
               j1=j1+1

               ! H_ij
               if (k.eq.1) then
                  subhmat(i1,j1)=&
                       alphamat(k,istep)*dot_product(lancvec(:,i),lancvec(:,j)) &
                       +betamat(k,istep)*dot_product(lancvec(:,i),lancvec(:,j+1))
               else
                  subhmat(i1,j1)=&
                       +betamat(k-1,istep)*dot_product(lancvec(:,i),lancvec(:,j-1))&
                       +alphamat(k,istep)*dot_product(lancvec(:,i),lancvec(:,j)) &
                       +betamat(k,istep)*dot_product(lancvec(:,i),lancvec(:,j+1))
               endif
               subhmat(j1,i1)=subhmat(i1,j1)

               ! S_ij
               subsmat(i1,j1)=dot_product(lancvec(:,i),lancvec(:,j))
               subsmat(j1,i1)=subsmat(i1,j1)
               
            enddo
            
         enddo
         
      enddo

      return
      
    end subroutine subspace_matrices

!#######################################################################

    subroutine solve_subspace_tdse(istep,vecprop,matdim)

      implicit none

      integer, intent(in)                  :: matdim
      integer                              :: istep,nvec,nnull,&
                                              error,i,j,k,m,i1,j1
      real(d), dimension(matdim)           :: vecprop
      real(d), dimension(:,:), allocatable :: transmat,hmat1,eigvec,&
                                              umat,funcmat
      real(d), dimension(:), allocatable   :: eigval,work,coeff0,coeff,&
                                              coeff1
      real(d)                              :: dtau,norm

!----------------------------------------------------------------------
! Perform Lowdin's canonical orthogonalisation of the subspace basis
! vectors to generate a linearly independent basis
!----------------------------------------------------------------------
      call canonical_ortho(nvec,nnull,istep,hmat1,coeff0,&
           transmat)

!----------------------------------------------------------------------
! Allocate arrays
!----------------------------------------------------------------------
      allocate(eigval(nlin))
      allocate(work(3*nlin))
      allocate(coeff(nvec))
      allocate(coeff1(nlin))
      allocate(eigvec(nlin,nlin))
      allocate(umat(nlin,nlin))
      allocate(funcmat(nlin,nlin))

!----------------------------------------------------------------------
! Diagonalise the transformed subspace Hamiltonian matrix, hmat1
!----------------------------------------------------------------------
      eigvec=hmat1

      call dsyev('V','U',nlin,eigvec,nlin,eigval,work,3*nlin,error)

      if (error.ne.0) then
         errmsg='Diagonalisation of the transformed subspace &
              Hamiltonian failed in solve_subspace_tdse'
         call error_control
      endif

!----------------------------------------------------------------------
! Propagate the wavefunction
!----------------------------------------------------------------------
      dtau=step

      ! F(Et)
      funcmat=0.0d0
      do k=1,nlin
         ! exp(-Ht)
         funcmat(k,k)=exp(-eigval(k)*dtau)
         
         ! 1-tanh(Ht)
         !funcmat(k,k)=1.0d0-tanh(eigval(k)*dtau)
      
         ! 1-erf(Ht)
         !funcmat(k,k)=1.0d0-erf(eigval(k)*dtau)
      enddo
      
      ! Representation of the propagator in the transformed
      ! subspace basis
      umat=matmul(eigvec,matmul(funcmat,transpose(eigvec)))
      
      ! Expansion coefficients for |Psi(dt)> in the basis of the
      ! transformed subspace states
      coeff1=matmul(umat,coeff0)
      norm=sqrt(dot_product(coeff1,coeff1))
      coeff1=coeff1/norm

      ! Transformation to the original, untransformed subspace basis
      coeff=matmul(transmat,coeff1)

      ! Construction of |Psi(dt)>
      !
      ! Note that the lancvec array also contains the "(N+1)th" vectors
      ! that are only used in the construction of the subspace
      ! Hamiltonian but are not used in the expansion of |Psi(dt)>
      vecprop=0.0d0
      i=0
      i1=0
10    continue
      i1=i1+1
      if (mod(i1,krydim+1).ne.0) then
         i=i+1
         vecprop=vecprop+coeff(i)*lancvec(:,i1)
      endif
      if (i1.lt.istep*(krydim+1)) goto 10

!----------------------------------------------------------------------
! Deallocate arrays
!----------------------------------------------------------------------
      deallocate(transmat)
      deallocate(hmat1)
      deallocate(eigval)
      deallocate(coeff0)
      deallocate(work)
      deallocate(eigvec)
      deallocate(coeff)
      deallocate(umat)
      deallocate(funcmat)

      return

    end subroutine solve_subspace_tdse

!#######################################################################

    subroutine canonical_ortho(nvec,nnull,istep,hmat1,coeff0,&
         transmat)

      implicit none

      integer                              :: nvec,nnull,istep,&
                                              error,i,j,k,l,lwork
      real(d), dimension(:,:), allocatable :: smat,hmat,eigvec,&
                                              smat1,hmat1,transmat,&
                                              invtransmat
      real(d), dimension(:), allocatable   :: eigval,work,coeff0
      real(d), parameter                   :: eps=1e-6_d

!----------------------------------------------------------------------
! Allocate arrays
!----------------------------------------------------------------------
      ! Number of subspace vectors
      nvec=istep*krydim

      allocate(smat(nvec,nvec))
      smat=0.0d0
      allocate(hmat(nvec,nvec))
      hmat=0.0d0
      allocate(eigvec(nvec,nvec))
      eigvec=0.0d0
      allocate(eigval(nvec))
      eigval=0.0d0
      allocate(work(3*nvec))
      work=0.0d0

!----------------------------------------------------------------------
! Diagonalise the subspace overlap matrix
!----------------------------------------------------------------------
      smat(1:nvec,1:nvec)=subsmat(1:nvec,1:nvec)
      hmat(1:nvec,1:nvec)=subhmat(1:nvec,1:nvec)

      eigvec=smat
      lwork=3*nvec
      call dsyev('V','U',nvec,eigvec,nvec,eigval,work,lwork,error)

      if (error.ne.0) then
         errmsg='Diagonalisation of the subspace overlap matrix &
              failed in canonical_ortho'
         call error_control
      endif

!----------------------------------------------------------------------
! Transform the subspace Hamiltonian to the space spanned by the
! linearly indpendent vectors
!
! Note that the eigenvectors of the subspace overlap matrix are
! arranged in order of increasing eigenvalues and that this matrix
! is positive semidefinite, i.e., the null space vectors will appear
! first
!----------------------------------------------------------------------
      ! Number of linearly independent vectors
      nlin=0
      do i=1,nvec
         if (abs(eigval(i)).gt.eps) nlin=nlin+1
      enddo

      ! Number of null space vectors
      nnull=nvec-nlin

      ! Allocate arrays
      allocate(smat1(nlin,nlin))
      allocate(hmat1(nlin,nlin))
      allocate(coeff0(nlin))
      allocate(transmat(nvec,nlin))
      allocate(invtransmat(nlin,nvec))

      ! Set up the transformation matrices, taking into account
      ! the normalisation factors
      transmat=eigvec(1:nvec,nnull+1:nvec)
      invtransmat=transpose(transmat)
      do i=1,nlin
         transmat(:,i)=transmat(:,i)/sqrt(eigval(nnull+i))
         invtransmat(i,:)=invtransmat(i,:)*sqrt(eigval(nnull+i))
      enddo

      ! Transformed subspace overlap and Hamiltonian matrices
      ! N.B., we only calculate the transformed overlap matrix
      ! for checking purposes (if this isn't the unit matrix,
      ! then things have gone terribly wrong).
      smat1=matmul(transpose(transmat),matmul(smat,transmat))
      hmat1=matmul(transpose(transmat),matmul(hmat,transmat))

!----------------------------------------------------------------------
! Initial wavefunction in the basis of the transformed subspace vectors
!
! Note that in the basis of the original, untransformed subspace 
! vectors, |Psi(0)> = (0,...,0,1,0,...,0)^T, hence the coefficient
! vector in the transformed subspace basis is simply given by the
! corresponding column of the inverse transformation matrix
!----------------------------------------------------------------------
      k=(istep-1)*krydim+1
      coeff0(:)=invtransmat(:,k)

!----------------------------------------------------------------------
! Deallocate arrays
!----------------------------------------------------------------------
      deallocate(smat)
      deallocate(hmat)
      deallocate(eigval)
      deallocate(eigvec)
      deallocate(work)
      deallocate(smat1)
      deallocate(invtransmat)

      return

    end subroutine canonical_ortho

!#######################################################################

    subroutine residual_1vec(vecprop,matdim,noffd,energy,residual)

      use tdsemod
      
      implicit none

      integer, intent(in)                :: matdim
      integer*8, intent(in)              :: noffd
      real(d), dimension(matdim)         :: vecprop
      real(d), dimension(:), allocatable :: hpsi,resvec
      real(d)                            :: energy,residual

!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
      allocate(hpsi(matdim))
      allocate(resvec(matdim))

!-----------------------------------------------------------------------
! Calculate the residual r = || H |Psi> - E |Psi> ||
!-----------------------------------------------------------------------
      ! H |Psi>
      call matxvec(matdim,noffd,vecprop,hpsi)
      hpsi=-hpsi
      
      ! Energy, <Psi| H |Psi>
      energy=dot_product(vecprop,hpsi)

      ! Residual
      resvec=hpsi-energy*vecprop
      residual=dot_product(resvec,resvec)
      residual=sqrt(residual)

!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
      deallocate(hpsi)
      deallocate(resvec)

      return

    end subroutine residual_1vec

!#######################################################################

    subroutine wrheader_1vec(s)

      implicit none

      integer :: s,i

      write(ilog,'(64a)') ('=',i=1,64)
      write(ilog,'(a,i3)') 'State',s
      write(ilog,'(64a)') ('=',i=1,64)
      write(ilog,'(2(a,8x),a,10x,a)') 'Iteration','Energy',&
           'Residual','Subdim'
      write(ilog,'(64a)') ('=',i=1,64)
      
      return
      
    end subroutine wrheader_1vec
      
!#######################################################################

    subroutine wrtable_1vec(n,energy,residual)

      implicit none

      integer :: n
      real(d) :: energy,residual

      write(ilog,'(i3,11x,F12.7,5x,E13.7,5x,i3)') n,energy*eh2ev,&
           residual,nlin
      
      return

    end subroutine wrtable_1vec
      
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

      use tdsemod
      
      implicit none

      deallocate(vec_old)
      deallocate(vec_new)
      deallocate(hxvec)
      deallocate(ener)
      deallocate(lconv)
      deallocate(sildim)
      if (allocated(hij)) deallocate(hij)
      if (allocated(indxi)) deallocate(indxi)
      if (allocated(indxj)) deallocate(indxj)
      if (hincore) call deallocate_hamiltonian
      
      return
      
    end subroutine finalise
      
!#######################################################################
    
  end module relaxmod