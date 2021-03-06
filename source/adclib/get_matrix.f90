module get_matrix

  use constants
  use parameters
  use adc_ph
  use misc
  use filetools
  use channels
  use timingmod
  
  implicit none

contains

!######################################################################
   
  subroutine get_diag_tda_direct(ndim,kpq,ar_diag)
    
    integer, intent(in) :: ndim 
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    real(dp), dimension(ndim), intent(out) :: ar_diag
    
    integer :: i
    integer :: inda,indb,indj,indk,spin

!!$ Preparing the diagonal part for the full diagonalisation   
    
    do i= 1,ndim
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ar_diag(i)=K_ph_ph(e(inda),e(indj))
       ar_diag(i)=ar_diag(i)+C1_ph_ph(inda,indj,inda,indj)
    end do

  end subroutine get_diag_tda_direct

!######################################################################

  subroutine get_diag_tda_direct_cvs(ndim,kpq,ar_diag)
    
    integer, intent(in) :: ndim 
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    real(dp), dimension(ndim), intent(out) :: ar_diag
    
    integer :: i
    integer :: inda,indb,indj,indk,spin

!!$ Preparing the diagonal part for the full diagonalisation   
    
    do i= 1,ndim
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ar_diag(i)=K_ph_ph(e(inda),e(indj))
       ar_diag(i)=ar_diag(i)+C1_ph_ph(inda,indj,inda,indj)
    end do

  end subroutine get_diag_tda_direct_cvs

!######################################################################

  subroutine get_offdiag_tda_direct(ndim,kpq,ar_offdiag)

    implicit none
    
    integer, intent(in) :: ndim
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    real(dp), dimension(ndim,ndim), intent(out) :: ar_offdiag 
    
    integer :: i,j
    integer :: inda,indb,indj,indk,spin
    integer :: indapr,indbpr,indjpr,indkpr,spinpr
 
    do i=1,ndim
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=i+1,ndim
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          ar_offdiag(i,j)=C1_ph_ph(inda,indj,indapr,indjpr)
          ar_offdiag(j,i)=C1_ph_ph(indapr,indjpr,inda,indj)
       end do
    end do

    return

  end subroutine get_offdiag_tda_direct

!######################################################################

  subroutine get_offdiag_tda_direct_cvs(ndim,kpq,ar_offdiag)
    
    integer, intent(in) :: ndim
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    real(dp), dimension(ndim,ndim), intent(out) :: ar_offdiag 
    
    integer :: i,j
    integer :: inda,indb,indj,indk,spin
    integer :: indapr,indbpr,indjpr,indkpr,spinpr

    do i=1,ndim
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=i+1,ndim
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          ar_offdiag(i,j)=C1_ph_ph(inda,indj,indapr,indjpr)
          ar_offdiag(j,i)=C1_ph_ph(indapr,indjpr,inda,indj)
       enddo
    enddo
    
  end subroutine get_offdiag_tda_direct_cvs

!######################################################################

  subroutine get_diag_tda_save(ndim,kpq,nbuf,chr)
    
    integer, intent(in) :: ndim,nbuf 
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    character(1), intent(in) :: chr
    
    character(30) :: name
    integer :: i,ktype,unt
    integer :: inda,indb,indj,indk,spin
    real(dp), dimension(ndim) :: ar_diag
    
    ktype=1
    name="SCRATCH/hmlt.dia"//chr
    unt=11
    
    do i=1, ndim
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ar_diag(i)=K_ph_ph(e(inda),e(indj))
       ar_diag(i)=ar_diag(i)+C1_ph_ph(inda,indj,inda,indj)
    end do

       !Saving in file
       write(ilog,*) "Writing the diagonal part in file ", name
       OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
            FORM='UNFORMATTED')
       call wrtdg(unt,ndim,buf_size,nbuf,ktype,ar_diag(:))
       CLOSE(unt)
       
  end subroutine get_diag_tda_save

 !######################################################################

  subroutine get_offdiag_tda_save(ndim,kpq,nbuf,noffd,chr)
    
    integer, intent(in) :: ndim
    integer, intent(out) :: nbuf 
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    integer*8 :: noffd
    character(1), intent(in) :: chr
    
    character(30) :: name
    integer  :: i,j,nlim,rec_count,count,unt
    integer  :: inda,indb,indj,indk,spin
    integer  :: indapr,indbpr,indjpr,indkpr,spinpr
    real(dp) :: ar_offdiag_ij, ar_offdiag_ji

    integer, dimension(:), allocatable  :: oi,oj
    real(dp), dimension(:), allocatable :: file_offdiag
    
    allocate(oi(buf_size))
    allocate(oj(buf_size))
    allocate(file_offdiag(buf_size))

    name="SCRATCH/hmlt.off"//chr
    unt=12

    count=0
    rec_count=0

       write(ilog,*) "Writing the off-diagonal part of TDA matrix in file ", name
       OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
            FORM='UNFORMATTED')
    
    do i=1,ndim
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=i+1,ndim
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          ar_offdiag_ij=C1_ph_ph(inda,indj,indapr,indjpr)
          ar_offdiag_ji=C1_ph_ph(indapr,indjpr,inda,indj)
!          if(abs(ar_offdiag_ij-ar_offdiag_ji) .ge. 1.e-15_d) then
!             write(ilog,*) "TDA matrix is not symmetric. Stopping now."
!             stop
!          end if

!!$ Saving into vector for the following Lanzcos/Davidson routine 
            

          !Culling  small matrix elements
          if (abs(ar_offdiag_ij) .gt. minc) then
             call register1()
          end if

       end do
    end do
!!$

       call register2()
       CLOSE(unt)
       
       deallocate(oi)
       deallocate(oj)
       deallocate(file_offdiag)

       noffd=count
       
  contains
       
    subroutine register1()
      
      count=count+1
      file_offdiag(count-buf_size*rec_count)=ar_offdiag_ij
      oi(count-buf_size*rec_count)=i
      oj(count-buf_size*rec_count)=j
      !Checking if the buffer is full 
      if(mod(count,buf_size) .eq. 0) then
         rec_count=rec_count+1
         nlim=buf_size
         !Saving off-diag part in file
         call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim) 
      end if

    end subroutine register1
       
    subroutine register2()
         
      !Saving the rest of matrix in file
      nlim=count-buf_size*rec_count
      call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
      rec_count=rec_count+1
      nbuf=rec_count
      
    end subroutine register2
    
  end subroutine get_offdiag_tda_save

!######################################################################

  subroutine get_diag_adc2_direct(ndim1,ndim2,kpq,ar_diag)
  
    integer, intent(in) :: ndim1,ndim2
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    real(dp), dimension(ndim1+ndim2), intent(out) :: ar_diag
    
    integer :: inda,indb,indj,indk,spin
    integer :: i
    
!!$ Filling the ph-ph block

    do i=1, ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ar_diag(i)=K_ph_ph(e(inda),e(indj))
       ar_diag(i)=ar_diag(i)+C1_ph_ph(inda,indj,inda,indj)
       ar_diag(i)=ar_diag(i)+CA_ph_ph(inda,inda)
       ar_diag(i)=ar_diag(i)+CB_ph_ph(indj,indj)
       ar_diag(i)=ar_diag(i)+CC_ph_ph(inda,indj,inda,indj)
    end do
    
!!$ Filling the 2p2h-2p2h block
    
    do i=ndim1+1, ndim1+ndim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ar_diag(i)=K_2p2h_2p2h(e(inda),e(indb),e(indj),e(indk))
    end do
    
  end subroutine get_diag_adc2_direct

!######################################################################

  subroutine get_diag_adc2_save(ndim1,ndim2,kpq,nbuf,chr)
  
    integer, intent(in) :: ndim1,ndim2,nbuf
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    character(1), intent(in) :: chr

    integer :: inda,indb,indj,indk,spin
    
    character(30) :: name
    integer :: i,ktype,unt 
    real(dp), dimension(:), allocatable :: ar_diag

    allocate(ar_diag(ndim1+ndim2))

    ktype=1
    name="SCRATCH/hmlt.dia"//chr 
    unt=11

!!$ Filling the ph-ph block

    do i=1, ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ar_diag(i)=K_ph_ph(e(inda),e(indj))
       ar_diag(i)=ar_diag(i)+C1_ph_ph(inda,indj,inda,indj)
       ar_diag(i)=ar_diag(i)+CA_ph_ph(inda,inda)
       ar_diag(i)=ar_diag(i)+CB_ph_ph(indj,indj)
       ar_diag(i)=ar_diag(i)+CC_ph_ph(inda,indj,inda,indj)
    end do

!!$ Filling the 2p2h-2p2h block
    
    do i=ndim1+1, ndim1+ndim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ar_diag(i)=K_2p2h_2p2h(e(inda),e(indb),e(indj),e(indk))
    end do
    
    !Saving the diagonal part in file
    write(ilog,*) "Writing the diagonal part of ADC matrix in file ", name
    OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
         FORM='UNFORMATTED')
    call wrtdg(unt,ndim1+ndim2,buf_size,nbuf,ktype,ar_diag(:))
    CLOSE(unt)

    deallocate(ar_diag)
  end subroutine get_diag_adc2_save

!######################################################################
  
  subroutine get_offdiag_adc2_direct(ndim,kpq,ar_offdiag)
    
    integer, intent(in) :: ndim
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    real(dp), dimension(ndim,ndim), intent(out) :: ar_offdiag
    
    integer :: inda,indb,indj,indk,spin
    integer :: indapr,indbpr,indjpr,indkpr,spinpr 
    
    integer :: i,j,dim_count,ndim1
    
    
    integer, dimension(buf_size)  :: oi,oj
    real(dp), dimension(buf_size) :: file_offdiag
    
    ar_offdiag(:,:)=0._dp
    
!!$ Full diagonalization. 

!!$ Filling the off-diagonal part of the ph-ph block

    ndim1=kpq(1,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=i+1,ndim1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)             
          ar_offdiag(i,j)=C1_ph_ph(inda,indj,indapr,indjpr)
          if(indj .eq. indjpr)&
                  ar_offdiag(i,j)=ar_offdiag(i,j)+CA_ph_ph(inda,indapr)
          if(inda .eq. indapr)&
               ar_offdiag(i,j)=ar_offdiag(i,j)+CB_ph_ph(indj,indjpr)
          ar_offdiag(i,j)=ar_offdiag(i,j)+CC_ph_ph(inda,indj,indapr,indjpr)
          ar_offdiag(j,i)=ar_offdiag(i,j)
       end do
    end do
       
!!$ Filling the off-diagonal part of the ph-2p2h block 
!!$ Coupling to the i=j,a=b configs
    
    dim_count=kpq(1,0)

    if (.not.lcvsfinal) then
    
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(2,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    
             ar_offdiag(i,j)=C5_ph_2p2h(inda,indj,indapr,indjpr)
             ar_offdiag(j,i)=ar_offdiag(i,j)
          end do
       end do
    
!!$ Coupling to the i=j,a|=b configs   
    
    dim_count=dim_count+kpq(2,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(3,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag(i,j)=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)
          ar_offdiag(j,i)=ar_offdiag(i,j)
       end do
    end do
    
 endif

!!$ Coupling to the i|=j,a=b configs
    
    dim_count=dim_count+kpq(3,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(4,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag(i,j)=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)
          ar_offdiag(j,i)=ar_offdiag(i,j)
       end do
    end do
       
!!$ Coupling to the i|=j,a|=b I configs
       
    dim_count=dim_count+kpq(4,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag(i,j)=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
          ar_offdiag(j,i)=ar_offdiag(i,j)
       end do
    end do

!!$ Coupling to the i|=j,a|=b II configs
       
    dim_count=dim_count+kpq(5,0)

    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag(i,j)=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
          ar_offdiag(j,i)=ar_offdiag(i,j)
       end do
    end do
  
  end subroutine get_offdiag_adc2_direct

!######################################################################

  subroutine get_offdiag_adc2_save(ndim,kpq,nbuf,count,chr)

!!$The difference from the earlier routine is that this routine returns the total number of saved els to a caller. 
    
    integer, intent(in)                                 :: ndim
    integer, intent(out)                                :: nbuf
    integer*8, intent(out)                              :: count
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    character(1), intent(in)                            :: chr
    
    integer                      :: inda,indb,indj,indk,spin
    integer                      :: indapr,indbpr,indjpr,indkpr,spinpr 
    
    character(30)                :: name
    integer                      :: i,j,nlim,rec_count,dim_count,ndim1,unt
    real(dp)                     :: ar_offdiag_ij

    integer, dimension(:), allocatable  :: oi,oj
    real(dp), dimension(:), allocatable :: file_offdiag
   
    integer                               :: a,b,nzero
    real(dp), dimension(:,:), allocatable :: ca,cb
    real(dp)                              :: tw1,tw2,tc1,tc2

    allocate(oi(buf_size))
    allocate(oj(buf_size))
    allocate(file_offdiag(buf_size))

!-----------------------------------------------------------------------
! Precompute the results of calls to CA_ph_ph and CB_ph_ph
!-----------------------------------------------------------------------
    call times(tw1,tc1)

    allocate(ca(nvirt,nvirt),cb(nocc,nocc))

    ! CA_ph_ph
    do i=1,nvirt
       do j=i,nvirt
          ca(i,j)=CA_ph_ph(nocc+i,nocc+j)
          ca(j,i)=ca(i,j)
       enddo
    enddo

    ! CB_ph_ph
    do i=1,nocc
       do j=i,nocc
          cb(i,j)=CB_ph_ph(i,j)
          cb(j,i)=cb(i,j)
       enddo
    enddo

!-----------------------------------------------------------------------
! Calculate the off-diagonal Hamiltonian matrix elements
!-----------------------------------------------------------------------
    name="SCRATCH/hmlt.off"//chr
    unt=12

    count=0
    rec_count=0
    
    write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", name
    OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
         FORM='UNFORMATTED')

!!$ Filling the off-diagonal part of the ph-ph block

    ndim1=kpq(1,0)
    
    do i=1,ndim1       
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=i+1,ndim1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)

          ar_offdiag_ij=C1_ph_ph(inda,indj,indapr,indjpr)

          if(indj .eq. indjpr)&
               ar_offdiag_ij= ar_offdiag_ij+ca(inda-nocc,indapr-nocc)

          if(inda .eq. indapr)&
               ar_offdiag_ij= ar_offdiag_ij+cb(indj,indjpr)

          ar_offdiag_ij= ar_offdiag_ij+CC_ph_ph(inda,indj,indapr,indjpr)

          call register1()
       end do
    end do

    deallocate(ca,cb)
       
!!$ Filling the off-diagonal part of the ph-2p2h block 
!!$ Coupling to the i=j,a=b configs

    dim_count=kpq(1,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(2,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    
          ar_offdiag_ij=C5_ph_2p2h(inda,indj,indapr,indjpr)
          call register1()
       end do
    end do
    
!!$ Coupling to the i=j,a|=b configs   
    
    dim_count=dim_count+kpq(2,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(3,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag_ij=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)
          call register1()
       end do
    end do
    
!!$ Coupling to the i|=j,a=b configs
    
    dim_count=dim_count+kpq(3,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(4,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)
          call register1()
       end do
    end do
       
!!$ Coupling to the i|=j,a|=b I configs
       
    dim_count=dim_count+kpq(4,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
          call register1()
       end do
    end do

!!$ Coupling to the i|=j,a|=b II configs
       
    dim_count=dim_count+kpq(5,0)

    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
          call register1()
       end do
    end do

    call register2()
    CLOSE(unt)
    write(ilog,*) count,' off-diagonal elements saved'

    call times(tw2,tc2)
    write(ilog,'(/,2x,a,F8.2,1x,a1)') &
         'Time taken to save off-diagonal elements:',tw2-tw1,'s'

    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)

  contains
    
    subroutine register1()
      if (abs(ar_offdiag_ij) .gt. minc) then
         count=count+1
         file_offdiag(count-buf_size*int(rec_count,8))= ar_offdiag_ij
         oi(count-buf_size*int(rec_count,8))=i
         oj(count-buf_size*int(rec_count,8))=j
         !Checking if the buffer is full 
         if(mod(count,buf_size) .eq. 0) then
            rec_count=rec_count+1
            nlim=buf_size
            !Saving off-diag part in file
            call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim) 
         end if
      end if
    end subroutine register1
    
    subroutine register2()
      
      !Saving the rest in file
      nlim=count-buf_size*int(rec_count,8)
      call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
      rec_count=rec_count+1
      nbuf=rec_count
      
    end subroutine register2
    
  end subroutine get_offdiag_adc2_save

!#######################################################################

  subroutine get_interm_adc2_save(ndim,kpq,chr)

    
    integer, intent(in)                                 :: ndim
!    integer, intent(out)                                :: nbuf
    integer*8                                           :: count
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    character(1), intent(in)                            :: chr
    
    
    character(30)                :: name,file
    integer                      :: i,j,nlim,rec_count,dim_count,ndim1,unt
    real(dp)                     :: ar_offdiag_ij

    integer                               :: a,b,nzero
    real(dp), dimension(:,:), allocatable :: ca,cb
    real(dp)                              :: tw1,tw2,tc1,tc2


!-----------------------------------------------------------------------
! Precompute the results of calls to Ca1_ph_ph and Cb1_ph_ph
!-----------------------------------------------------------------------
    call times(tw1,tc1)

    name="SCRATCH/hmlt.intermCa"//chr
    file="SCRATCH/hmlt.intermCb"//chr
    unt=12

    write(ilog,*) "Writing intermediate terms of ADC matrix in file ", name
    OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
         FORM='UNFORMATTED')

    rec_count=nvirt*nvirt
    dim_count=nocc*nocc

    allocate(ca(nvirt,nvirt),cb(nocc,nocc))

    ! CA_ph_ph
    do i=1,nvirt
       do j=i,nvirt
          ca(i,j)=Ca1_ph_ph(nocc+i,nocc+j)
          ca(j,i)=ca(i,j)
       enddo
    enddo

    call wrtinterm(unt,nvirt,rec_count,ca)

    close(unt)

    write(ilog,*) "Writing intermediate terms of ADC matrix in file ", file
    OPEN(UNIT=unt,FILE=file,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
         FORM='UNFORMATTED')

    ! CB_ph_ph
    do i=1,nocc
       do j=i,nocc
          cb(i,j)=Cb1_ph_ph(i,j)
          cb(j,i)=cb(i,j)
       enddo
    enddo

    call wrtinterm(unt,nocc,dim_count,cb)

    close(unt)

    count=rec_count+dim_count

    deallocate(ca,cb)
       

    write(ilog,*) count,' intermediate terms saved'

    call times(tw2,tc2)
    write(ilog,'(/,2x,a,F8.2,1x,a1)') &
         'Time taken to save intermediate vectors:',tw2-tw1,'s'

  end subroutine get_interm_adc2_save

!#######################################################################
  
  subroutine get_offdiag_adc2_save_omp(ndim,kpq,nbuf,count,chr)

    use omp_lib
    use iomod

    implicit none
    
    integer, intent(in)                                 :: ndim
    integer, intent(out)                                :: nbuf
    integer*8, intent(out)                              :: count
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    character(1), intent(in)                            :: chr
    
    integer                      :: inda,indb,indj,indk,spin
    integer                      :: indapr,indbpr,indjpr,indkpr,spinpr
    
    character(30)                :: name
    integer                      :: i,j,k,nlim,rec_count,dim_count,ndim1,unt
    real(dp)                     :: arr_offdiag_ij

    integer, dimension(:), allocatable  :: oi,oj
    real(dp), dimension(:), allocatable :: file_offdiag
   
    integer                               :: a,b,nzero
    real(dp), dimension(:,:), allocatable :: ca,cb
    real(dp)                              :: tw1,tw2,tc1,tc2

    integer                                       :: nthreads,tid
    integer, dimension(:), allocatable            :: hamunit    
    integer, dimension(:,:), allocatable          :: oi_omp,oj_omp
    integer*8, dimension(:), allocatable          :: count_omp
    integer, dimension(:), allocatable            :: rec_count_omp
    integer, dimension(:), allocatable            :: nlim_omp
    integer*8                                     :: nonzero
    integer                                       :: n,nprev,itmp
    real(dp), dimension(:,:), allocatable         :: file_offdiag_omp
    character(len=120), dimension(:), allocatable :: hamfile

    integer  :: buf_size2
    real(dp) :: minc2

    integer, dimension(:), allocatable :: nsaved

    integer :: c,cr,cm

    buf_size2=buf_size
    minc2=minc

    call times(tw1,tc1)
    
!-----------------------------------------------------------------------
! Determine the no. threads
!-----------------------------------------------------------------------
    !$omp parallel
    nthreads=omp_get_num_threads()
    !$omp end parallel
    
    write(ilog,*) "nthreads:",nthreads

!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
    allocate(oi(buf_size))
    allocate(oj(buf_size))
    allocate(file_offdiag(buf_size))

    allocate(hamunit(nthreads))
    allocate(hamfile(nthreads))
    allocate(oi_omp(nthreads,buf_size))
    allocate(oj_omp(nthreads,buf_size))
    allocate(file_offdiag_omp(nthreads,buf_size))
    allocate(count_omp(nthreads))
    allocate(rec_count_omp(nthreads))
    allocate(nlim_omp(nthreads))
    allocate(nsaved(nthreads))
  
!-----------------------------------------------------------------------
! Open the working Hamiltonian files
!-----------------------------------------------------------------------
  do i=1,nthreads
     call freeunit(hamunit(i))
     hamfile(i)='SCRATCH/hmlt.off'//chr//'.'
     k=len_trim(hamfile(i))+1
     if (i.lt.10) then
        write(hamfile(i)(k:k),'(i1)') i
     else
        write(hamfile(i)(k:k+1),'(i2)') i
     endif
     open(unit=hamunit(i),file=hamfile(i),status='unknown',&
          access='sequential',form='unformatted')
  enddo

!-----------------------------------------------------------------------
! Precompute the results of calls to CA_ph_ph and CB_ph_ph
!-----------------------------------------------------------------------
    call times(tw1,tc1)

    allocate(ca(nvirt,nvirt),cb(nocc,nocc))

    !$omp parallel do private(i,j) shared(ca)
    ! CA_ph_ph
    do i=1,nvirt
       do j=i,nvirt
          ca(i,j)=CA_ph_ph(nocc+i,nocc+j)
          ca(j,i)=ca(i,j)
       enddo
    enddo
    !$omp end parallel do

    !$omp parallel do private(i,j) shared(cb)
    ! CB_ph_ph
    do i=1,nocc
       do j=i,nocc
          cb(i,j)=CB_ph_ph(i,j)
          cb(j,i)=cb(i,j)
       enddo
    enddo
    !$omp end parallel do

!-----------------------------------------------------------------------
! Open the Hamiltonian file
!-----------------------------------------------------------------------
  name="SCRATCH/hmlt.off"//chr
  call freeunit(unt)
 
  write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", name
  OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
       FORM='UNFORMATTED')

!-----------------------------------------------------------------------
! Initialise counters
!-----------------------------------------------------------------------
  count=0
  rec_count=0

  count_omp=0
  rec_count_omp=0

!-----------------------------------------------------------------------
! ph-ph block
!-----------------------------------------------------------------------
    ndim1=kpq(1,0)
    
    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=i+1,ndim1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)

          arr_offdiag_ij=C1_ph_ph(inda,indj,indapr,indjpr)

          if(indj .eq. indjpr)&
               arr_offdiag_ij= arr_offdiag_ij+ca(inda-nocc,indapr-nocc)

          if(inda .eq. indapr)&
               arr_offdiag_ij= arr_offdiag_ij+cb(indj,indjpr)

          arr_offdiag_ij= arr_offdiag_ij+CC_ph_ph(inda,indj,indapr,indjpr)

          tid=1+omp_get_thread_num()
             
          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif
          
       end do
    end do
    !$omp end parallel do

    deallocate(ca,cb)
       
!-----------------------------------------------------------------------
! ph-2p2h block 
!-----------------------------------------------------------------------
!!$ Coupling to the i=j,a=b configs

    dim_count=kpq(1,0)

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(2,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    
          arr_offdiag_ij=C5_ph_2p2h(inda,indj,indapr,indjpr)

          tid=1+omp_get_thread_num()
          
          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif
          
       end do
    end do
    !$omp end parallel do

!!$ Coupling to the i=j,a|=b configs   
    
    dim_count=dim_count+kpq(2,0)
    
    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(3,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          arr_offdiag_ij=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)
    
          tid=1+omp_get_thread_num()
             
          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif
          
       end do
    end do
    !$omp end parallel do

!!$ Coupling to the i|=j,a=b configs
    
    dim_count=dim_count+kpq(3,0)
    
    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(4,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          arr_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif

       end do
    end do
    !$omp end parallel do

!!$ Coupling to the i|=j,a|=b I configs
       
    dim_count=dim_count+kpq(4,0)
    
    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          arr_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif

       end do
    end do
    !$omp end parallel do

!!$ Coupling to the i|=j,a|=b II configs
       
    dim_count=dim_count+kpq(5,0)

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          arr_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif
          
       end do
    end do
    !$omp end parallel do

!-----------------------------------------------------------------------
! Assemble the complete hmlt.off file
!-----------------------------------------------------------------------
    write(ilog,*) "hmlt.off assembly..."

    count=0
    do i=1,nthreads
       count=count+count_omp(i)
    enddo

    ! Complete records
    write(ilog,*) "       complete records"
    do i=1,nthreads
       rewind(hamunit(i))
       do j=1,rec_count_omp(i)
          rec_count=rec_count+1
          read(hamunit(i)) file_offdiag(:),oi(:),oj(:),nlim
          call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),&
               buf_size)
       enddo
    enddo

    ! Incomplete records
    write(ilog,*) "       incomplete records"
    do i=1,nthreads
       nsaved(i)=mod(count_omp(i),buf_size)
    enddo
    n=nsaved(1)    
    file_offdiag(1:n)=file_offdiag_omp(1,1:n)
    oi(1:n)=oi_omp(1,1:n)
    oj(1:n)=oj_omp(1,1:n)
    nprev=n
    do i=2,nthreads

       n=n+nsaved(i)
              
       if (n.gt.buf_size) then
          ! The buffer is full. Write the buffer to disk and
          ! then save the remaining elements for thread i to the
          ! buffer
          !
          ! (i) Elements for thread i that can fit into the buffer
          itmp=buf_size-nprev
          file_offdiag(nprev+1:buf_size)=file_offdiag_omp(i,1:itmp)
          oi(nprev+1:buf_size)=oi_omp(i,1:itmp)
          oj(nprev+1:buf_size)=oj_omp(i,1:itmp)
          rec_count=rec_count+1
          call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),&
               buf_size)
          !
          ! (ii) Elements for thread i that couldn't fit into the buffer
          n=nsaved(i)-itmp
          file_offdiag(1:n)=file_offdiag_omp(i,itmp+1:nsaved(i))
          oi(1:n)=oi_omp(i,itmp+1:nsaved(i))
          oj(1:n)=oj_omp(i,itmp+1:nsaved(i))
       else
          ! The buffer is not yet full. Add all elements for thread i
          ! to the buffer
          file_offdiag(nprev+1:n)=file_offdiag_omp(i,1:nsaved(i))          
          oi(nprev+1:n)=oi_omp(i,1:nsaved(i))          
          oj(nprev+1:n)=oj_omp(i,1:nsaved(i))          
       endif

       nprev=n

    enddo

    ! Last, potentially incomplete buffer
    nlim=count-buf_size*int(rec_count,8)
    call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
    rec_count=rec_count+1
    nbuf=rec_count
    
!    ! Delete the working files
!    do i=1,nthreads
!       call system('rm -rf '//trim(hamfile(i)))
!    enddo

    write(ilog,*) 'rec_counts',nbuf
    write(ilog,*) count,' off-diagonal elements saved in file ', name

!-----------------------------------------------------------------------    
! Write any incomplete records to file and save the record counts
! for each file
!-----------------------------------------------------------------------    
    ! Write the incomplete records to file
    do i=1,nthreads       
       nlim=count_omp(i)-buf_size*int(rec_count_omp(i),8)       
       if (nlim.gt.0) then
          rec_count_omp(i)=rec_count_omp(i)+1
          call wrtoffdg(hamunit(i),buf_size,&
               file_offdiag_omp(i,:),oi_omp(i,:),&
               oj_omp(i,:),nlim)
       endif
    enddo

    ! Save the record counts to the nrec_omp array for use later on
    nrec_omp=rec_count_omp

!-----------------------------------------------------------------------    
! Close files
!-----------------------------------------------------------------------    
    close(unt)
    do i=1,nthreads
       close(hamunit(i))
    enddo

!-----------------------------------------------------------------------    
! Deallocate arrays
!-----------------------------------------------------------------------
    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)

    deallocate(hamunit)
    deallocate(hamfile)
    deallocate(oi_omp)
    deallocate(oj_omp)
    deallocate(file_offdiag_omp)
    deallocate(count_omp)
    deallocate(rec_count_omp)
    deallocate(nlim_omp)
    deallocate(nsaved)

    call times(tw2,tc2)

    write(ilog,*) "Time taken:",tw2-tw1

    return
    
  end subroutine get_offdiag_adc2_save_omp

!#######################################################################

  subroutine get_offdiag_adc2_save_cvs(ndim,kpq,nbuf,count,chr)

    integer, intent(in) :: ndim
    integer, intent(out) :: nbuf
    integer*8, intent(out) :: count 
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    character(1), intent(in) :: chr
    
    integer :: inda,indb,indj,indk,spin
    integer :: indapr,indbpr,indjpr,indkpr,spinpr 
    
    character(30) :: name
    integer  :: i,j,nlim,rec_count,dim_count,ndim1,unt
    real(dp) :: ar_offdiag_ij
    
    integer, dimension(:), allocatable  :: oi,oj
    real(dp), dimension(:), allocatable :: file_offdiag

    allocate(oi(buf_size))
    allocate(oj(buf_size))
    allocate(file_offdiag(buf_size))

    name="SCRATCH/hmlt.off"//chr
    unt=12

    count=0
    rec_count=0

    write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", name
    OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
         FORM='UNFORMATTED')

!-----------------------------------------------------------------------
! Off-diagonal part of the ph-ph block: all admissible due to previous
! screening of the configurations
!-----------------------------------------------------------------------
    ndim1=kpq(1,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=i+1,ndim1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          ar_offdiag_ij=C1_ph_ph(inda,indj,indapr,indjpr)
          if(indj .eq. indjpr)&
               ar_offdiag_ij= ar_offdiag_ij+CA_ph_ph(inda,indapr)
          if(inda .eq. indapr)&
               ar_offdiag_ij= ar_offdiag_ij+CB_ph_ph(indj,indjpr)
          ar_offdiag_ij= ar_offdiag_ij+CC_ph_ph(inda,indj,indapr,indjpr)
          call register1()
       end do
    end do

!-----------------------------------------------------------------------
! 1p1h - 2h2p (i|=j,a=b) block
!-----------------------------------------------------------------------
    dim_count=kpq(1,0)    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(4,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)
          call register1()
       end do
    end do

!-----------------------------------------------------------------------
! 1p1h - 2h2p (i|=j,a|b I) block
!-----------------------------------------------------------------------
    dim_count=dim_count+kpq(4,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
          call register1()
       end do
    end do

!-----------------------------------------------------------------------
! 1p1h - 2h2p (i|=j,a|b II) block
!-----------------------------------------------------------------------
    dim_count=dim_count+kpq(5,0)

    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
          call register1()
       end do
    end do

    call register2()
    CLOSE(unt)
    write(ilog,*) count,' off-diagonal elements saved'

    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)
    
  contains

    subroutine register1()
      if (abs(ar_offdiag_ij) .gt. minc) then
         count=count+1
         file_offdiag(count-buf_size*int(rec_count,8))= ar_offdiag_ij
         oi(count-buf_size*int(rec_count,8))=i
         oj(count-buf_size*int(rec_count,8))=j
         !Checking if the buffer is full 
         if(mod(count,buf_size) .eq. 0) then
            rec_count=rec_count+1
            nlim=buf_size
            !Saving off-diag part in file
            call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim) 
         end if
      end if
    end subroutine register1
    
    subroutine register2()
      
      !Saving the rest in file
      nlim=count-buf_size*int(rec_count,8)
      call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
      rec_count=rec_count+1
      nbuf=rec_count
      
    end subroutine register2

  end subroutine get_offdiag_adc2_save_cvs

!#######################################################################

    subroutine get_offdiag_adc2_save_cvs_omp(ndim,kpq,nbuf,count,chr)
   
    use omp_lib
    use iomod
    
    implicit none

    integer, intent(in) :: ndim
    integer*8, intent(out) :: count
    integer, intent(out) :: nbuf
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    character(1), intent(in) :: chr
    
    integer :: inda,indb,indj,indk,spin
    integer :: indapr,indbpr,indjpr,indkpr,spinpr 
    
    character(30) :: name
    integer  :: rec_count
    integer  :: i,j,k,nlim,dim_count,ndim1,unt
    integer  :: lim1i, lim2i, lim1j, lim2j
    real(dp) :: arr_offdiag_ij
    
    integer, dimension(:), allocatable  :: oi,oj
    real(dp), dimension(:), allocatable :: file_offdiag
    
    integer                               :: a,b,nzero
    real(dp), dimension(:,:), allocatable :: ca,cb
    real(dp)                              :: tw1,tw2,tc1,tc2
    
    integer                                       :: nthreads,tid
    integer, dimension(:), allocatable            :: hamunit    
    integer, dimension(:,:), allocatable          :: oi_omp,oj_omp
    integer*8, dimension(:), allocatable          :: count_omp
    integer, dimension(:), allocatable            :: rec_count_omp
    integer, dimension(:), allocatable            :: nlim_omp
    integer*8                                     :: nonzero
    integer                                       :: n,nprev,itmp
    real(dp), dimension(:,:), allocatable         :: file_offdiag_omp
    character(len=120), dimension(:), allocatable :: hamfile

    integer  :: buf_size2
    real(dp) :: minc2

    integer, dimension(:), allocatable :: nsaved

    integer :: c,cr,cm

    buf_size2=buf_size
    minc2=minc

    call times(tw1,tc1)

!-----------------------------------------------------------------------
! Determine the no. threads
!-----------------------------------------------------------------------
  !$omp parallel
  nthreads=omp_get_num_threads()
  !$omp end parallel

  write(ilog,*) "nthreads:",nthreads

!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
  allocate(oi(buf_size))
  allocate(oj(buf_size))
  allocate(file_offdiag(buf_size))

  allocate(hamunit(nthreads))
  allocate(hamfile(nthreads))
  allocate(oi_omp(nthreads,buf_size))
  allocate(oj_omp(nthreads,buf_size))
  allocate(file_offdiag_omp(nthreads,buf_size))
  allocate(count_omp(nthreads))
  allocate(rec_count_omp(nthreads))
  allocate(nlim_omp(nthreads))
  allocate(nsaved(nthreads))

!-----------------------------------------------------------------------
! Open the working Hamiltonian files
!-----------------------------------------------------------------------
  do i=1,nthreads
     call freeunit(hamunit(i))
     hamfile(i)='SCRATCH/hmlt.off'//chr//'.'
     k=len_trim(hamfile(i))+1
     if (i.lt.10) then
        write(hamfile(i)(k:k),'(i1)') i
     else
        write(hamfile(i)(k:k+1),'(i2)') i
     endif
     open(unit=hamunit(i),file=hamfile(i),status='unknown',&
          access='sequential',form='unformatted')
  enddo

!-----------------------------------------------------------------------
! Precompute the results of calls to CA_ph_ph and CB_ph_ph
!-----------------------------------------------------------------------
  allocate(ca(nvirt,nvirt),cb(nocc,nocc))
  
  !$omp parallel do private(i,j) shared(ca)
  ! CA_ph_ph
  do i=1,nvirt
     do j=i,nvirt
        ca(i,j)=CA_ph_ph(nocc+i,nocc+j)
        ca(j,i)=ca(i,j)
     enddo
  enddo
  !$omp end parallel do

  !$omp parallel do private(i,j) shared(cb)
  ! CB_ph_ph
  do i=1,nocc
     do j=i,nocc
        cb(i,j)=CB_ph_ph(i,j)
        cb(j,i)=cb(i,j)
     enddo
  enddo
  !$omp end parallel do

!-----------------------------------------------------------------------
! Open the Hamiltonian file
!-----------------------------------------------------------------------
  name="SCRATCH/hmlt.off"//chr
  call freeunit(unt)
 
  write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", name
  OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
       FORM='UNFORMATTED')

!-----------------------------------------------------------------------
! Initialise counters
!-----------------------------------------------------------------------
  count=0
  rec_count=0

  count_omp=0
  rec_count_omp=0

!-----------------------------------------------------------------------
! ph-ph block
!-----------------------------------------------------------------------
     ndim1=kpq(1,0)

     !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,ndim1)
     do i=1,ndim1
        call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
        do j=1,i-1
           call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
           arr_offdiag_ij=C1_ph_ph(inda,indj,indapr,indjpr)

           if(indj .eq. indjpr)&
                arr_offdiag_ij= arr_offdiag_ij+ca(inda-nocc,indapr-nocc)

           if(inda .eq. indapr)&
                arr_offdiag_ij= arr_offdiag_ij+cb(indj,indjpr)

           arr_offdiag_ij=arr_offdiag_ij+CC_ph_ph(inda,indj,indapr,indjpr)

           tid=1+omp_get_thread_num()
             
           if (abs(arr_offdiag_ij).gt.minc2) then
              count_omp(tid)=count_omp(tid)+1
              file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
              oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
              oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
              ! Checking if the buffer is full 
              if (mod(count_omp(tid),buf_size2).eq.0) then
                 rec_count_omp(tid)=rec_count_omp(tid)+1
                 nlim_omp(tid)=buf_size2
                 ! Saving off-diag part in file
                 write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                      oj_omp(tid,:),nlim_omp(tid)
              endif
           endif
           
        end do
     end do
     !$omp end parallel do

!-----------------------------------------------------------------------
! ph-2p2h block 
!-----------------------------------------------------------------------
!!$ Coupling to the i|=j,a=b configs

       dim_count=kpq(1,0)
             
       !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(4,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)

             tid=1+omp_get_thread_num()

             if (abs(arr_offdiag_ij).gt.minc2) then
                count_omp(tid)=count_omp(tid)+1
                file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
                oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
                oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
                ! Checking if the buffer is full 
                if (mod(count_omp(tid),buf_size2).eq.0) then
                   rec_count_omp(tid)=rec_count_omp(tid)+1
                   nlim_omp(tid)=buf_size2
                   ! Saving off-diag part in file
                   write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                        oj_omp(tid,:),nlim_omp(tid)
                endif
             endif
             
          end do
       end do
       !$omp end parallel do

!!$ Coupling to the i|=j,a|=b I configs

       dim_count=dim_count+kpq(4,0)

       !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)

             tid=1+omp_get_thread_num()

             if (abs(arr_offdiag_ij).gt.minc2) then
                count_omp(tid)=count_omp(tid)+1
                file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
                oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
                oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
                ! Checking if the buffer is full 
                if (mod(count_omp(tid),buf_size2).eq.0) then
                   rec_count_omp(tid)=rec_count_omp(tid)+1
                   nlim_omp(tid)=buf_size2
                   ! Saving off-diag part in file
                   write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                        oj_omp(tid,:),nlim_omp(tid)
              endif
           endif
             
          end do
       end do
       !$omp end parallel do

!!$ Coupling to the i|=j,a|=b II configs
       
       dim_count=dim_count+kpq(5,0)

     !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
             arr_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)

             tid=1+omp_get_thread_num()

             if (abs(arr_offdiag_ij).gt.minc2) then
                count_omp(tid)=count_omp(tid)+1
                file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
                oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
                oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
                ! Checking if the buffer is full 
                if (mod(count_omp(tid),buf_size2).eq.0) then
                   rec_count_omp(tid)=rec_count_omp(tid)+1
                   nlim_omp(tid)=buf_size2
                   ! Saving off-diag part in file
                   write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                        oj_omp(tid,:),nlim_omp(tid)
                endif
             endif

          end do
       end do
       !$omp end parallel do

!-----------------------------------------------------------------------
! Assemble the complete hmlt.off file
!-----------------------------------------------------------------------
    count=0
    do i=1,nthreads
       count=count+count_omp(i)
    enddo

    ! Complete records
    do i=1,nthreads
       rewind(hamunit(i))
       do j=1,rec_count_omp(i)
          rec_count=rec_count+1
          read(hamunit(i)) file_offdiag(:),oi(:),oj(:),nlim
          call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),&
               buf_size)
       enddo
    enddo

    ! Incomplete records
    do i=1,nthreads
       nsaved(i)=mod(count_omp(i),buf_size)
    enddo
    n=nsaved(1)    
    file_offdiag(1:n)=file_offdiag_omp(1,1:n)
    oi(1:n)=oi_omp(1,1:n)
    oj(1:n)=oj_omp(1,1:n)
    nprev=n
    do i=2,nthreads

       n=n+nsaved(i)
              
       if (n.gt.buf_size) then
          ! The buffer is full. Write the buffer to disk and
          ! then save the remaining elements for thread i to the
          ! buffer
          !
          ! (i) Elements for thread i that can fit into the buffer
          itmp=buf_size-nprev
          file_offdiag(nprev+1:buf_size)=file_offdiag_omp(i,1:itmp)
          oi(nprev+1:buf_size)=oi_omp(i,1:itmp)
          oj(nprev+1:buf_size)=oj_omp(i,1:itmp)
          rec_count=rec_count+1
          call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),&
               buf_size)
          !
          ! (ii) Elements for thread i that couldn't fit into the buffer
          n=nsaved(i)-itmp
          file_offdiag(1:n)=file_offdiag_omp(i,itmp+1:nsaved(i))
          oi(1:n)=oi_omp(i,itmp+1:nsaved(i))
          oj(1:n)=oj_omp(i,itmp+1:nsaved(i))
       else
          ! The buffer is not yet full. Add all elements for thread i
          ! to the buffer
          file_offdiag(nprev+1:n)=file_offdiag_omp(i,1:nsaved(i))          
          oi(nprev+1:n)=oi_omp(i,1:nsaved(i))          
          oj(nprev+1:n)=oj_omp(i,1:nsaved(i))          
       endif

       nprev=n

    enddo

    ! Last, potentially incomplete buffer
    nlim=count-buf_size*int(rec_count,8)
    call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
    rec_count=rec_count+1
    nbuf=rec_count
    
!    ! Delete the working files
!    do i=1,nthreads
!       call system('rm -rf '//trim(hamfile(i)))
!    enddo

    write(ilog,*) 'rec_counts',nbuf
    write(ilog,*) count,' off-diagonal elements saved in file ', name

!-----------------------------------------------------------------------    
! Write any incomplete records to file and save the record counts
! for each file
!-----------------------------------------------------------------------    
    ! Write the incomplete records to file
    do i=1,nthreads       
       nlim=count_omp(i)-buf_size*int(rec_count_omp(i),8)       
       if (nlim.gt.0) then
          rec_count_omp(i)=rec_count_omp(i)+1
          call wrtoffdg(hamunit(i),buf_size,&
               file_offdiag_omp(i,:),oi_omp(i,:),&
               oj_omp(i,:),nlim)
       endif
    enddo

    ! Save the record counts to the nrec_omp array for use later on
    nrec_omp=rec_count_omp

!-----------------------------------------------------------------------    
! Close files
!-----------------------------------------------------------------------    
    close(unt)
    do i=1,nthreads
       close(hamunit(i))
    enddo

!-----------------------------------------------------------------------    
! Deallocate arrays
!-----------------------------------------------------------------------
    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)

    deallocate(hamunit)
    deallocate(hamfile)
    deallocate(oi_omp)
    deallocate(oj_omp)
    deallocate(file_offdiag_omp)
    deallocate(count_omp)
    deallocate(rec_count_omp)
    deallocate(nlim_omp)
    deallocate(nsaved)

    call times(tw2,tc2) 
    write(ilog,*) "Time taken:",tw2-tw1

    return

  end subroutine get_offdiag_adc2_save_cvs_omp

!#######################################################################

  subroutine get_phph_adc2(ndim,kpq,amatr)
    
    integer, intent(in) :: ndim
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    real(dp), dimension(ndim,ndim), intent(out) :: amatr

    integer  :: inda,indb,indj,indk,spin
    integer  :: indapr,indbpr,indjpr,indkpr,spinpr 
    integer  :: i,j
    real(dp) :: ar_diag,ar_offd

    amatr=0._dp
    
!!$ Filling the ph-ph block: diagonal part

    do i=1, ndim
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ar_diag=K_ph_ph(e(inda),e(indj))
       ar_diag=ar_diag+C1_ph_ph(inda,indj,inda,indj)
       ar_diag=ar_diag+CA_ph_ph(inda,inda)
       ar_diag=ar_diag+CB_ph_ph(indj,indj)
       ar_diag=ar_diag+CC_ph_ph(inda,indj,inda,indj)

       amatr(i,i)=ar_diag
    end do

!!$ Filling the ph-ph block : off-diagonal part

    do i=1,ndim
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=i+1,ndim
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)      
          ar_offd=C1_ph_ph(inda,indj,indapr,indjpr)
          if(indj .eq. indjpr)&
               ar_offd=ar_offd+CA_ph_ph(inda,indapr)
          if(inda .eq. indapr)&
               ar_offd=ar_offd+CB_ph_ph(indj,indjpr)
          ar_offd=ar_offd+CC_ph_ph(inda,indj,indapr,indjpr)

          amatr(i,j)=ar_offd
       end do
    end do
    
  end subroutine get_phph_adc2

!######################################################################
  
  subroutine get_ph_2p2h(ndim,i1,i2,kpq,bmx)

    integer, intent(in) :: i1,i2,ndim
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    real(dp), dimension(ndim,i2-i1+1), intent(out) :: bmx
    
    integer :: inda,indb,indj,indk,spin
    integer :: indapr,indbpr,indjpr,indkpr,spinpr 
    
    integer :: i,j,nlim1,nlim2,mains

    mains=kpq(1,0)

    write(ilog,*) mains,i1,i2
   
    do i=i1,i2

       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)

       nlim1=kpq(1,0)+1
       nlim2=kpq(1,0)+kpq(2,0)

       do j=nlim1,nlim2
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          bmx(j-mains,i)=C5_ph_2p2h(inda,indj,indapr,indjpr)
       end do
    
       nlim1=nlim2+1
       nlim2=nlim2+kpq(3,0)
       do j=nlim1,nlim2
          write(ilog,*) j-mains,'jjjjjj'
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    
          bmx(j-mains,i)=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)
       end do

       nlim1=nlim2+1
       nlim2=nlim2+kpq(4,0)
       do j=nlim1,nlim2
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          bmx(j-mains,i)=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)
       end do
       
       nlim1=nlim2+1
       nlim2=nlim2+kpq(5,0)
       do j=nlim1,nlim2
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          bmx(j-mains,i)=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
       end do
       
       nlim1=nlim2+1
       nlim2=nlim2+kpq(5,0)
       do j=nlim1,nlim2
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          bmx(j-mains,i)=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
       end do

    end do

  end subroutine get_ph_2p2h

!######################################################################
  
  subroutine get_2p2h2p2h_dg2s(ndim,kpq,ar_diag)
    
    integer, intent(in) :: ndim
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    real(dp), dimension(ndim), intent(out) :: ar_diag
    
    integer :: inda,indb,indj,indk,spin
    integer :: i,nlim
        
    nlim=kpq(1,0)

    do i=nlim+1, nlim+ndim
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ar_diag(i-nlim)=K_2p2h_2p2h(e(inda),e(indb),e(indj),e(indk))
    end do
    
  end subroutine get_2p2h2p2h_dg2s

!######################################################################

  subroutine get_diag_adc2ext_direct(ndim1,ndim2,kpq,ar_diag)
  
    integer, intent(in) :: ndim1,ndim2
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    real(dp), dimension(ndim1+ndim2), intent(out) :: ar_diag
    
    integer  :: inda,indb,indj,indk,spin
    real(dp) ::ea,eb,ej,ek,temp
    
    integer :: i,lim1,lim2
    
!!$ Filling the ph-ph block
    
    do i= 1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ea=e(inda)
       ej=e(indj)
       ar_diag(i)=K_ph_ph(ea,ej)
       ar_diag(i)=ar_diag(i)+C1_ph_ph(inda,indj,inda,indj)
       ar_diag(i)=ar_diag(i)+CA_ph_ph(inda,inda)
       ar_diag(i)=ar_diag(i)+CB_ph_ph(indj,indj)
       ar_diag(i)=ar_diag(i)+CC_ph_ph(inda,indj,inda,indj)
    end do

!!$ Filling the 2p2h-2p2h block
!!$ Filling (1,1) block
    
    lim1=ndim1+1
    lim2=ndim1+kpq(2,0)
    
    do i= lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_1_1(inda,indj,inda,indj)
    end do

!!$ Filling (2,2) block
    
    lim1=lim1+kpq(2,0)
    lim2=lim2+kpq(3,0)

    do i= lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_2_2(inda,indb,indj,inda,indb,indj)
    end do
    
!!$ Filling (3,3) block
    
    lim1=lim1+kpq(3,0)
    lim2=lim2+kpq(4,0)

    do i= lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_3_3(inda,indj,indk,inda,indj,indk)
    end do
    
!!$ Filling (4i,4i) block  
    
    lim1=lim1+kpq(4,0)
    lim2=lim2+kpq(5,0)

    do i= lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_4i_4i(inda,indb,indj,indk,inda,indb,indj,indk)
    end do
    
!!$ Filling (4ii,4ii) block  
    
    lim1=lim1+kpq(5,0)
    lim2=lim2+kpq(5,0)

    do i= lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_4ii_4ii(inda,indb,indj,indk,inda,indb,indj,indk)
    end do
    
  end subroutine get_diag_adc2ext_direct

!######################################################################

  subroutine get_diag_adc2ext_save(ndim1,ndim2,kpq,nbuf,chr)
  
    integer, intent(in) :: ndim1,ndim2,nbuf 
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    character(1), intent(in) :: chr
   
    integer  :: inda,indb,indj,indk,spin
    real(dp) ::ea,eb,ej,ek,temp
    
    character(30) :: name
    integer :: i,ktype,dim_count,lim1,lim2,unt,a,b,c,d1
    real(dp), dimension(ndim1+ndim2) :: ar_diag
     
    ktype=1
    name="SCRATCH/hmlt.dia"//chr 
    unt=11
    
!!$ Filling the ph-ph block
    
    do i=1, ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ea=e(inda)
       ej=e(indj)
       ar_diag(i)=K_ph_ph(ea,ej)
       ar_diag(i)=ar_diag(i)+C1_ph_ph(inda,indj,inda,indj)
       ar_diag(i)=ar_diag(i)+CA_ph_ph(inda,inda)
       ar_diag(i)=ar_diag(i)+CB_ph_ph(indj,indj)
       ar_diag(i)=ar_diag(i)+CC_ph_ph(inda,indj,inda,indj)
    end do

!!$ Filling the 2p2h-2p2h block
!!$ Filling (1,1) block
    
    lim1=ndim1+1
    lim2=ndim1+kpq(2,0)
    
    do i=lim1, lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_1_1(inda,indj,inda,indj)
    end do

!!$ Filling (2,2) block
    
    lim1=lim1+kpq(2,0)
    lim2=lim2+kpq(3,0)

    do i=lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_2_2(inda,indb,indj,inda,indb,indj)
    end do
    
!!$ Filling (3,3) block
    
    lim1=lim1+kpq(3,0)
    lim2=lim2+kpq(4,0)

    do i=lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_3_3(inda,indj,indk,inda,indj,indk)
    end do
     
!!$ Filling (4i,4i) block  
    
    lim1=lim1+kpq(4,0)
    lim2=lim2+kpq(5,0)

    do i=lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_4i_4i(inda,indb,indj,indk,inda,indb,indj,indk)
    end do
    
!!$ Filling (4ii,4ii) block  
    
    lim1=lim1+kpq(5,0)
    lim2=lim2+kpq(5,0)

    do i=lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_4ii_4ii(inda,indb,indj,indk,inda,indb,indj,indk)
    end do
    
    !Saving the diagonal part in file
    write(ilog,*) "Writing",ndim1+ndim2," diagonal elements of ADC-ext. matrix in file ",name
    OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
         FORM='UNFORMATTED')
    call wrtdg(unt,ndim1+ndim2,buf_size,nbuf,ktype,ar_diag(:))
!!$    call wrtdgat(unt,ndim1+ndim2,nbuf,ar_diag(:))
    CLOSE(unt)
   
    write(ilog,*) 'Writing successful at get_diag_adc2ext_save end'
  end subroutine get_diag_adc2ext_save

!######################################################################

  subroutine get_offdiag_adc2ext_direct(ndim,kpq,ar_offdiag)

  integer, intent(in) :: ndim
  integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
  real(dp), dimension(ndim,ndim), intent(out) :: ar_offdiag
  
  integer :: inda,indb,indj,indk,spin
  integer :: indapr,indbpr,indjpr,indkpr,spinpr 
  
  integer :: i,j,nlim,dim_count,ndim1
  integer :: lim1i, lim2i, lim1j, lim2j

  ar_offdiag(:,:)=0._dp 

!!$ Full diagonalization. Filling the lower half of the matrix

!!$ Filling the off-diagonal part of the ph-ph block

     ndim1=kpq(1,0)

     do i= 1,ndim1
        call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
        do j= 1,i-1
           call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)             
           ar_offdiag(i,j)=C1_ph_ph(inda,indj,indapr,indjpr)
           if(indj .eq. indjpr)&
                ar_offdiag(i,j)=ar_offdiag(i,j)+CA_ph_ph(inda,indapr)
           if(inda .eq. indapr)&
                ar_offdiag(i,j)=ar_offdiag(i,j)+CB_ph_ph(indj,indjpr)
           ar_offdiag(i,j)=ar_offdiag(i,j)+CC_ph_ph(inda,indj,indapr,indjpr)
        end do
     end do

     
!!$ Filling the off-diagonal part of the ph-2p2h block 
!!$ Coupling to the i=j,a=b configs

       dim_count=kpq(1,0)
       
       if (.not.lcvsfinal) then

          do i= 1,ndim1
             call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
             do j= dim_count+1,dim_count+kpq(2,0)
                call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    
                ar_offdiag(j,i)=C5_ph_2p2h(inda,indj,indapr,indjpr)
!!$             ar_offdiag(i,j)=ar_offdiag(j,i)
             end do
          end do
          
!!$ Coupling to the i=j,a|=b configs   
       
          dim_count=dim_count+kpq(2,0)
       
          do i= 1,ndim1
             call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
             do j= dim_count+1,dim_count+kpq(3,0)
                call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
                ar_offdiag(j,i)=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)
!!$             ar_offdiag(i,j)=ar_offdiag(j,i)
             end do
       end do
       
    endif

!!$ Coupling to the i|=j,a=b configs
       
       dim_count=dim_count+kpq(3,0)
             
       do i= 1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j= dim_count+1,dim_count+kpq(4,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             ar_offdiag(j,i)=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)
!!$             ar_offdiag(i,j)=ar_offdiag(j,i)
          end do
       end do

!!$ Coupling to the i|=j,a|=b I configs
       
       dim_count=dim_count+kpq(4,0)

       do i= 1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j= dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             ar_offdiag(j,i)=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
!!$             ar_offdiag(i,j)=ar_offdiag(j,i)
          end do
       end do

!!$ Coupling to the i|=j,a|=b II configs
       
       dim_count=dim_count+kpq(5,0)

       do i= 1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j= dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             ar_offdiag(j,i)=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
!!$             ar_offdiag(i,j)=ar_offdiag(j,i)
          end do
       end do
    
!!$ Filling the 2p2h-2p2h block
    
!!$ (1,1) block
    
    lim1i=kpq(1,0)+1
    lim2i=kpq(1,0)+kpq(2,0)
    lim1j=lim1i
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(i,j)=C_1_1(inda,indj,indapr,indjpr)
           
       end do
    end do

!!$ (2,1) block 

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(i,j)=C_2_1(inda,indb,indj,indapr,indjpr)
           
       end do
    end do

!!$ (3,1) block
     
    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(i,j)=C_3_1(inda,indj,indk,indapr,indjpr)
           
       end do
    end do          
         
!!$ (4i,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(i,j)=C_4i_1(inda,indb,indj,indk,indapr,indjpr)
           
       end do
    end do 
 
!!$ (4ii,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(i,j)=C_4ii_1(inda,indb,indj,indk,indapr,indjpr)
           
       end do
    end do 

!!$ (2,2) block

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=lim1i
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          ar_offdiag(i,j)=C_2_2(inda,indb,indj,indapr,indbpr,indjpr)
           
       end do
    end do

!!$ (3,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(i,j)=C_3_2(inda,indj,indk,indapr,indbpr,indjpr)
           
       end do
    end do
        
!!$ (4i,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(i,j)=C_4i_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
           
       end do
    end do

!!$ (4ii,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(i,j)=C_4ii_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
           
       end do
    end do

!!$ (3,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=lim1i
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(i,j)=C_3_3(inda,indj,indk,indapr,indjpr,indkpr)
           
       end do
    end do

!!$ (4i,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(i,j)=C_4i_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
            
       end do
    end do

!!$ (4ii,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(i,j)=C_4ii_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
           
       end do
    end do

!!$ (4i,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=lim1i
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(i,j)=C_4i_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
       end do
    end do

!!$ (4ii,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)

    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          ar_offdiag(i,j)=C_4ii_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
       end do
    end do
    
!!$ (4ii,4ii) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=lim1i

    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(i,j)=C_4ii_4ii(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
       end do
    end do


  end subroutine get_offdiag_adc2ext_direct

!######################################################################

subroutine get_offdiag_adc2ext_save(ndim,kpq,nbuf,count,chr)
   
  integer, intent(in) :: ndim
  integer*8, intent(out) :: count
  integer, intent(out) :: nbuf
  integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
  character(1), intent(in) :: chr
  
  integer :: inda,indb,indj,indk,spin
  integer :: indapr,indbpr,indjpr,indkpr,spinpr 
  
  character(30) :: name
  integer  :: rec_count
  integer  :: i,j,nlim,dim_count,ndim1,unt
  integer  :: lim1i, lim2i, lim1j, lim2j
  real(dp) :: arr_offdiag_ij
  
  integer, dimension(:), allocatable  :: oi,oj
  real(dp), dimension(:), allocatable :: file_offdiag

  integer                               :: a,b,nzero
  real(dp), dimension(:,:), allocatable :: ca,cb
  real(dp)                              :: tw1,tw2,tc1,tc2


  allocate(oi(buf_size))
  allocate(oj(buf_size))
  allocate(file_offdiag(buf_size))

!-----------------------------------------------------------------------
! Precompute the results of calls to CA_ph_ph and CB_ph_ph
!-----------------------------------------------------------------------
  call times(tw1,tc1)
  
  allocate(ca(nvirt,nvirt),cb(nocc,nocc))
  
  ! CA_ph_ph
  do i=1,nvirt
     do j=i,nvirt
        ca(i,j)=CA_ph_ph(nocc+i,nocc+j)
        ca(j,i)=ca(i,j)
     enddo
  enddo
  
  ! CB_ph_ph
  do i=1,nocc
     do j=i,nocc
        cb(i,j)=CB_ph_ph(i,j)
        cb(j,i)=cb(i,j)
     enddo
  enddo

!-----------------------------------------------------------------------
! Open the Hamiltonian file
!-----------------------------------------------------------------------
  name="SCRATCH/hmlt.off"//chr
  unt=12
  
  write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", name
  OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
       FORM='UNFORMATTED')

!-----------------------------------------------------------------------
! Initialise counters
!-----------------------------------------------------------------------
  count=0
  rec_count=0

!-----------------------------------------------------------------------
! ph-ph block
!-----------------------------------------------------------------------
     ndim1=kpq(1,0)
       
     do i=1,ndim1
        call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
        do j=1,i-1
           call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)             
           arr_offdiag_ij=C1_ph_ph(inda,indj,indapr,indjpr)

           if(indj .eq. indjpr)&
                arr_offdiag_ij= arr_offdiag_ij+ca(inda-nocc,indapr-nocc)

           if(inda .eq. indapr)&
                arr_offdiag_ij= arr_offdiag_ij+cb(indj,indjpr)

           arr_offdiag_ij=arr_offdiag_ij+CC_ph_ph(inda,indj,indapr,indjpr)
           call register1()
        end do
     end do

!-----------------------------------------------------------------------
! ph-2p2h block 
!-----------------------------------------------------------------------
!!$ Coupling to the i=j,a=b configs

       dim_count=kpq(1,0)
       
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(2,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    
             arr_offdiag_ij=C5_ph_2p2h(inda,indj,indapr,indjpr)
             call register1()
          end do
       end do
          
!!$ Coupling to the i=j,a|=b configs   
       
       dim_count=dim_count+kpq(2,0)
       
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(3,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)
             !Culling  small matrix elements
             if (abs(arr_offdiag_ij) .gt. minc) then
                call register1()
             end if
          end do
       end do

!!$ Coupling to the i|=j,a=b configs
       
       dim_count=dim_count+kpq(3,0)
             
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(4,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)
             call register1()
          end do
       end do

!!$ Coupling to the i|=j,a|=b I configs
       
       dim_count=dim_count+kpq(4,0)

       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
             !Culling  small matrix elements
             if (abs(arr_offdiag_ij) .gt. minc) then
                call register1()
             end if
          end do
       end do

!!$ Coupling to the i|=j,a|=b II configs
       
       dim_count=dim_count+kpq(5,0)

       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
             arr_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
             !Culling  small matrix elements
             call register1()
          end do
       end do

!-----------------------------------------------------------------------
! 2p2h-2p2h block
!-----------------------------------------------------------------------
!!$ (1,1) block
    
    lim1i=kpq(1,0)+1
    lim2i=kpq(1,0)+kpq(2,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_1_1(inda,indj,indapr,indjpr)
           
          call register1()
       end do
    end do

!!$ (2,1) block 

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_2_1(inda,indb,indj,indapr,indjpr)
           
          call register1()
       end do
    end do

!!$ (3,1) block
     
    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_1(inda,indj,indk,indapr,indjpr)
           
          call register1()
       end do
    end do          
         
!!$ (4i,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_1(inda,indb,indj,indk,indapr,indjpr)
           
          call register1()
       end do
    end do 
 
!!$ (4ii,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_1(inda,indb,indj,indk,indapr,indjpr)
            
          call register1()
       end do
    end do 

!!$ (2,2) block

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          arr_offdiag_ij=C_2_2(inda,indb,indj,indapr,indbpr,indjpr)
           
          call register1()
       end do
    end do

!!$ (3,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_2(inda,indj,indk,indapr,indbpr,indjpr)
            
          call register1()
       end do
    end do
        
!!$ (4i,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
           
          call register1()
       end do
    end do

!!$ (4ii,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
           
          call register1()
       end do
    end do

!!$ (3,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_3(inda,indj,indk,indapr,indjpr,indkpr)
           
          call register1()
       end do
    end do

!!$ (4i,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
           
          call register1()
       end do
    end do

!!$ (4ii,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
           
          call register1()
       end do
    end do

!!$ (4i,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
          call register1()
       end do
    end do

!!$ (4ii,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)

    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          arr_offdiag_ij=C_4ii_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
          call register1()
       end do
    end do
    
!!$ (4ii,4ii) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=lim1i

    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_4ii(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
          call register1()
       end do
    end do
    
    call register2()
    CLOSE(unt)
    write(ilog,*) 'rec_counts',nbuf
    write(ilog,*) count,' off-diagonal elements saved in file ', name

    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)

  contains
       
    subroutine register1()
      if (abs(arr_offdiag_ij) .gt. minc) then
         count=count+1
! buf_size*int(rec_count,8) can exceed the int*4 limit
         file_offdiag(count-buf_size*int(rec_count,8))=arr_offdiag_ij
         oi(count-buf_size*int(rec_count,8))=i
         oj(count-buf_size*int(rec_count,8))=j
         !Checking if the buffer is full 
         if(mod(count,buf_size) .eq. 0) then
            rec_count=rec_count+1
            nlim=buf_size
            !Saving off-diag part in file
            call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
!!$            call wrtoffat(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)  
         end if
      end if
    end subroutine register1
    
    subroutine register2()
      
      !Saving the rest in file
      nlim=count-buf_size*int(rec_count,8)
      call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
!!$      call wrtoffat(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
      rec_count=rec_count+1
      nbuf=rec_count
      
    end subroutine register2

  end subroutine get_offdiag_adc2ext_save

!#######################################################################

subroutine get_offdiag_adc2ext_save_cvs(ndim,kpq,nbuf,count,chr)
   
  integer, intent(in) :: ndim
  integer*8, intent(out) :: count
  integer, intent(out) :: nbuf
  integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
  character(1), intent(in) :: chr
  
  integer :: inda,indb,indj,indk,spin
  integer :: indapr,indbpr,indjpr,indkpr,spinpr 
  
  character(30) :: name
  integer  :: rec_count
  integer  :: i,j,nlim,dim_count,ndim1,unt
  integer  :: lim1i, lim2i, lim1j, lim2j
  real(dp) :: arr_offdiag_ij
  
  integer, dimension(:), allocatable  :: oi,oj
  real(dp), dimension(:), allocatable :: file_offdiag

  integer                               :: a,b,nzero
  real(dp), dimension(:,:), allocatable :: ca,cb
 
  allocate(oi(buf_size))
  allocate(oj(buf_size))
  allocate(file_offdiag(buf_size))

!-----------------------------------------------------------------------
! Precompute the results of calls to CA_ph_ph and CB_ph_ph
!-----------------------------------------------------------------------
  allocate(ca(nvirt,nvirt),cb(nocc,nocc))
  
  ! CA_ph_ph
  do i=1,nvirt
     do j=i,nvirt
        ca(i,j)=CA_ph_ph(nocc+i,nocc+j)
        ca(j,i)=ca(i,j)
     enddo
  enddo
  
  ! CB_ph_ph
  do i=1,nocc
     do j=i,nocc
        cb(i,j)=CB_ph_ph(i,j)
        cb(j,i)=cb(i,j)
     enddo
  enddo

!-----------------------------------------------------------------------
! Calculate the off-diagonal Hamiltonian matrix elements
!-----------------------------------------------------------------------
  name="SCRATCH/hmlt.off"//chr
  unt=12
  
  count=0
  rec_count=0
  
  write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", name
  OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
       FORM='UNFORMATTED')

!!$ Filling the off-diagonal part of the ph-ph block

     ndim1=kpq(1,0)
       
     do i=1,ndim1
        call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
        do j=1,i-1
           call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)             
           arr_offdiag_ij=C1_ph_ph(inda,indj,indapr,indjpr)

           if(indj .eq. indjpr)&
                arr_offdiag_ij= arr_offdiag_ij+ca(inda-nocc,indapr-nocc)

           if(inda .eq. indapr)&
                arr_offdiag_ij= arr_offdiag_ij+cb(indj,indjpr)

           arr_offdiag_ij=arr_offdiag_ij+CC_ph_ph(inda,indj,indapr,indjpr)
           call register1()
        end do
     end do
   
!!$ Coupling to the i|=j,a=b configs
       
       dim_count=kpq(1,0)
             
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(4,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)
             call register1()
          end do
       end do

!!$ Coupling to the i|=j,a|=b I configs
       
       dim_count=dim_count+kpq(4,0)

       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
             !Culling  small matrix elements
             if (abs(arr_offdiag_ij) .gt. minc) then
                call register1()
             end if
          end do
       end do

!!$ Coupling to the i|=j,a|=b II configs
       
       dim_count=dim_count+kpq(5,0)

       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
             !Culling  small matrix elements
             call register1()
          end do
       end do
    
!!$ Filling the 2p2h-2p2h block
    
!!$ (1,1) block
    
    lim1i=kpq(1,0)+1
    lim2i=kpq(1,0)+kpq(2,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_1_1(inda,indj,indapr,indjpr)
           
          call register1()
       end do
    end do

!!$ (2,1) block 

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_2_1(inda,indb,indj,indapr,indjpr)
           
          call register1()
       end do
    end do

!!$ (3,1) block
     
    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_1(inda,indj,indk,indapr,indjpr)
           
          call register1()
       end do
    end do          
         
!!$ (4i,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_1(inda,indb,indj,indk,indapr,indjpr)
           
          call register1()
       end do
    end do 
 
!!$ (4ii,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_1(inda,indb,indj,indk,indapr,indjpr)
            
          call register1()
       end do
    end do 

!!$ (2,2) block

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          arr_offdiag_ij=C_2_2(inda,indb,indj,indapr,indbpr,indjpr)
           
          call register1()
       end do
    end do

!!$ (3,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_2(inda,indj,indk,indapr,indbpr,indjpr)
            
          call register1()
       end do
    end do
        
!!$ (4i,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
           
          call register1()
       end do
    end do

!!$ (4ii,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
           
          call register1()
       end do
    end do

!!$ (3,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_3(inda,indj,indk,indapr,indjpr,indkpr)
           
          call register1()
       end do
    end do

!!$ (4i,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
           
          call register1()
       end do
    end do

!!$ (4ii,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
           
          call register1()
       end do
    end do

!!$ (4i,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
          call register1()
       end do
    end do

!!$ (4ii,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)

    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          arr_offdiag_ij=C_4ii_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
          call register1()
       end do
    end do
    
!!$ (4ii,4ii) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=lim1i

    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_4ii(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
          call register1()
       end do
    end do
    
    call register2()
    CLOSE(unt)
    write(ilog,*) 'rec_counts',nbuf
    write(ilog,*) count,' off-diagonal elements saved in file ', name

    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)

  contains
       
    subroutine register1()
      if (abs(arr_offdiag_ij) .gt. minc) then
         count=count+1
! buf_size*int(rec_count,8) can exceed the int*4 limit
         file_offdiag(count-buf_size*int(rec_count,8))=arr_offdiag_ij
         oi(count-buf_size*int(rec_count,8))=i
         oj(count-buf_size*int(rec_count,8))=j
         !Checking if the buffer is full 
         if(mod(count,buf_size) .eq. 0) then
            rec_count=rec_count+1
            nlim=buf_size
            !Saving off-diag part in file
            call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
!!$            call wrtoffat(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)  
         end if
      end if
    end subroutine register1
    
    subroutine register2()
      
      !Saving the rest in file
      nlim=count-buf_size*int(rec_count,8)
      call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
!!$      call wrtoffat(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
      rec_count=rec_count+1
      nbuf=rec_count
      
    end subroutine register2

end subroutine get_offdiag_adc2ext_save_cvs

!#######################################################################

!---------------------------------------------------------------------------------
!---------------------------------------------------------------------------------
!-------------------FANO SUBROUTINES----------------------------------------------
!---------------------------------------------------------------------------------
!---------------------------------------------------------------------------------

!!$variable meth stands for method calling the subroutine: 1-tda,2-adc2,21-adc2e

  subroutine adc2ext_0_0(meth,a,j,a1,j1,matel)
        
    integer, intent(in)   :: meth,a,j,a1,j1
    real(dp), intent(out) :: matel

    real(dp) :: ea,ej

    matel=0._dp

    if((a .eq. a1) .and. (j .eq. j1)) then
       ea=e(a)
       ej=e(j)
       matel=K_ph_ph(ea,ej)
    end if
    
    matel=matel+C1_ph_ph(a,j,a1,j1)


    if((meth .eq. 2) .or. (meth .eq. 21)) then
       if(j .eq. j1)&
            matel=matel+CA_ph_ph(a,a1)
       if(a .eq. a1)&
            matel=matel+CB_ph_ph(j,j1)
       matel=matel+CC_ph_ph(a,j,a1,j1)
    end if
     
  end subroutine adc2ext_0_0

!######################################################################
  
  subroutine adc2ext_1_1(meth,a,j,a1,j1,ea,ej,matel)
    
    integer, intent(in):: meth,a,j,a1,j1
    real(dp), intent(in):: ea,ej
    real(dp), intent(out) :: matel
    
    logical :: diag
    
    matel=0._dp
    diag=(a .eq. a1) .and. (j .eq. j1)
    
    if(diag) then
       matel=K_2p2h_2p2h(ea,ea,ej,ej)
    end if
    if(meth .eq. 21)&
         matel=matel+C_1_1(a,j,a1,j1)
    
  end subroutine adc2ext_1_1

!######################################################################
  
  subroutine adc2ext_2_2(meth,a,b,j,a1,b1,j1,ea,eb,ej,matel)
    
    integer, intent(in):: meth,a,b,j,a1,b1,j1
    real(dp), intent(in):: ea,eb,ej
    real(dp), intent(out) :: matel
    
    logical :: diag
    
    matel=0._dp
    diag=(a .eq. a1) .and. (b .eq. b1) .and. (j .eq. j1)
    
    if(diag) then
       matel=K_2p2h_2p2h(ea,eb,ej,ej)
    end if
    
    if(meth .eq. 21)&
         matel=matel+C_2_2(a,b,j,a1,b1,j1)
    
  end subroutine adc2ext_2_2

!######################################################################
  
  subroutine adc2ext_3_3(meth,a,j,k,a1,j1,k1,ea,ej,ek,matel)
    
    integer, intent(in):: meth,a,j,k,a1,j1,k1
    real(dp), intent(in):: ea,ej,ek
    real(dp), intent(out) :: matel
    
    logical :: diag
    
    matel=0._dp
    diag=(a .eq. a1) .and. (j .eq. j1) .and. (k .eq. k1)
    
    if(diag) then
       matel=K_2p2h_2p2h(ea,ea,ej,ek)
    end if
    
    if(meth .eq. 21)&
         matel=matel+C_3_3(a,j,k,a1,j1,k1)
    
  end subroutine adc2ext_3_3

!######################################################################

  subroutine adc2ext_4i_4i(meth,a,b,j,k,a1,b1,j1,k1,ea,eb,ej,ek,matel)
    
    integer, intent(in):: meth,a,b,j,k,a1,b1,j1,k1
    real(dp), intent(in):: ea,eb,ej,ek
    real(dp), intent(out) :: matel
    
    logical :: diag
    
    matel=0._dp
    diag=(a .eq. a1) .and. (b .eq. b1) .and. (j .eq. j1) .and. (k .eq. k1)
    
    if(diag) then
       matel=K_2p2h_2p2h(ea,eb,ej,ek)
    end if
    
    if(meth .eq. 21)&
         matel=matel+C_4i_4i(a,b,j,k,a1,b1,j1,k1)
    
  end subroutine adc2ext_4i_4i

!######################################################################
  
  subroutine adc2ext_4ii_4ii(meth,a,b,j,k,a1,b1,j1,k1,ea,eb,ej,ek,matel)
    
    integer, intent(in):: meth,a,b,j,k,a1,b1,j1,k1
    real(dp), intent(in):: ea,eb,ej,ek
    real(dp), intent(out) :: matel
    
    logical :: diag
    
    matel=0._dp
    diag=(a .eq. a1) .and. (b .eq. b1) .and. (j .eq. j1) .and. (k .eq. k1)
    
    if(diag) then
       matel=K_2p2h_2p2h(ea,eb,ej,ek)
    end if
    
    if(meth .eq. 21)&
         matel=matel+C_4ii_4ii(a,b,j,k,a1,b1,j1,k1)
    
  end subroutine adc2ext_4ii_4ii
   
!######################################################################

  subroutine get_offdiag_adc2_save_MIO(ndim,kpq,nbuf,count,indx,chr)

!!$The difference from the earlier routine is that this routine returns the total number of saved els to a caller. 
    
    integer, intent(in) :: ndim
    integer, intent(out) :: nbuf
    integer*8, intent(out) :: count 
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    character(1), intent(in) :: chr
    INTEGER, DIMENSION(ndim), intent(in) :: indx  
    
    integer :: inda,indb,indj,indk,spin
    integer :: indapr,indbpr,indjpr,indkpr,spinpr 
    
    character(30) :: name
    integer  :: i,j,nlim,rec_count,dim_count,ndim1,unt
    real(dp) :: ar_offdiag_ij
    
    integer, dimension(:), allocatable  :: oi,oj
    real(dp), dimension(:), allocatable :: file_offdiag
    
    allocate(oi(buf_size))
    allocate(oj(buf_size))
    allocate(file_offdiag(buf_size))

    name="SCRATCH/hmlt.off"//chr
    unt=12

    count=0
    rec_count=0
    
    
    write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", name
    OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
         FORM='UNFORMATTED')

!!$ Full diagonalization.  

!!$ Filling the off-diagonal part of the ph-ph block

    ndim1=kpq(1,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=i+1,ndim1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)             
          ar_offdiag_ij=C1_ph_ph(inda,indj,indapr,indjpr)
          if(indj .eq. indjpr)&
               ar_offdiag_ij= ar_offdiag_ij+CA_ph_ph(inda,indapr)
          if(inda .eq. indapr)&
               ar_offdiag_ij= ar_offdiag_ij+CB_ph_ph(indj,indjpr)
          ar_offdiag_ij= ar_offdiag_ij+CC_ph_ph(inda,indj,indapr,indjpr)
          call register1()
       end do
    end do
    
       
!!$ Filling the off-diagonal part of the ph-2p2h block 
!!$ Coupling to the i=j,a=b configs

    dim_count=kpq(1,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(2,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    
          ar_offdiag_ij=C5_ph_2p2h(inda,indj,indapr,indjpr)
          call register1()
       end do
    end do
    
!!$ Coupling to the i=j,a|=b configs   
    
    dim_count=dim_count+kpq(2,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(3,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag_ij=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)
          call register1()
       end do
    end do
    
!!$ Coupling to the i|=j,a=b configs
    
    dim_count=dim_count+kpq(3,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(4,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)
          call register1()
       end do
    end do
       
!!$ Coupling to the i|=j,a|=b I configs
       
    dim_count=dim_count+kpq(4,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
          call register1()
       end do
    end do

!!$ Coupling to the i|=j,a|=b II configs
       
    dim_count=dim_count+kpq(5,0)

    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
          call register1()
       end do
    end do

    call register2()
    CLOSE(unt)
    write(ilog,*) count,' off-diagonal elements saved'

    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)
    
  contains
    
    subroutine register1()
      if (abs(ar_offdiag_ij) .gt. minc) then
         count=count+1
         file_offdiag(count-buf_size*int(rec_count,8))= ar_offdiag_ij
         if ( indx(i) .ge. indx(j) ) then 
         oi(count-buf_size*int(rec_count,8))=indx(i)
         oj(count-buf_size*int(rec_count,8))=indx(j)
         else
         oi(count-buf_size*int(rec_count,8))=indx(j)
         oj(count-buf_size*int(rec_count,8))=indx(i)
         end if
         !Checking if the buffer is full 
         if(mod(count,buf_size) .eq. 0) then
            rec_count=rec_count+1
            nlim=buf_size
            !Saving off-diag part in file
            call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim) 
         end if
      end if
    end subroutine register1
    
    subroutine register2()
      
      !Saving the rest in file
      nlim=count-buf_size*int(rec_count,8)
      call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
      rec_count=rec_count+1
      nbuf=rec_count
      
    end subroutine register2
    
  end subroutine get_offdiag_adc2_save_MIO

!######################################################################

  subroutine get_diag_adc2_save_MIO(ndim1,ndim2,kpq,nbuf,indx,chr)
  
    integer, intent(in) :: ndim1,ndim2,nbuf
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    character(1), intent(in) :: chr
    INTEGER, DIMENSION(ndim1+ndim2), intent(in) :: indx  
 
    integer :: inda,indb,indj,indk,spin
    
    character(30) :: name
    integer :: i,ktype,unt 
    real(dp), dimension(:), allocatable:: ar_diag

    allocate(ar_diag(ndim1+ndim2))


    ktype=1
    name="SCRATCH/hmlt.dia"//chr 
    unt=11

!!$ Filling the ph-ph block

    do i=1, ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ar_diag(indx(i))=K_ph_ph(e(inda),e(indj))
       ar_diag(indx(i))=ar_diag(indx(i))+C1_ph_ph(inda,indj,inda,indj)
       ar_diag(indx(i))=ar_diag(indx(i))+CA_ph_ph(inda,inda)
       ar_diag(indx(i))=ar_diag(indx(i))+CB_ph_ph(indj,indj)
       ar_diag(indx(i))=ar_diag(indx(i))+CC_ph_ph(inda,indj,inda,indj)
    end do
    
!!$ Filling the 2p2h-2p2h block
    
    do i=ndim1+1, ndim1+ndim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ar_diag(indx(i))=K_2p2h_2p2h(e(inda),e(indb),e(indj),e(indk))
    end do
    
    !Saving the diagonal part in file
    write(ilog,*) "Writing the diagonal part of ADC matrix in file ", name
    OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
         FORM='UNFORMATTED')
    call wrtdg(unt,ndim1+ndim2,buf_size,nbuf,ktype,ar_diag(:))
    CLOSE(unt)

    deallocate(ar_diag)
  end subroutine get_diag_adc2_save_MIO

!######################################################################

  subroutine get_diag_adc2_direct_MIO(ndim1,ndim2,kpq,ar_diag,indx)
  
    integer, intent(in) :: ndim1,ndim2
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    real(dp), dimension(ndim1+ndim2), intent(out) :: ar_diag
    INTEGER, dimension(ndim1+ndim2), intent(in) :: indx
    

    integer :: inda,indb,indj,indk,spin
    integer :: i
    
!!$ Filling the ph-ph block

    do i=1, ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ar_diag(indx(i))=K_ph_ph(e(inda),e(indj))
       ar_diag(indx(i))=ar_diag(indx(i))+C1_ph_ph(inda,indj,inda,indj)
       ar_diag(indx(i))=ar_diag(indx(i))+CA_ph_ph(inda,inda)
       ar_diag(indx(i))=ar_diag(indx(i))+CB_ph_ph(indj,indj)
       ar_diag(indx(i))=ar_diag(indx(i))+CC_ph_ph(inda,indj,inda,indj)
    end do
    
!!$ Filling the 2p2h-2p2h block
    
    do i=ndim1+1, ndim1+ndim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ar_diag(indx(i))=K_2p2h_2p2h(e(inda),e(indb),e(indj),e(indk))
    end do
    
  end subroutine get_diag_adc2_direct_MIO

!######################################################################

  subroutine get_offdiag_adc2_direct_MIO(ndim,kpq,ar_offdiag,indx)
    
    integer, intent(in) :: ndim
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    real(dp), dimension(ndim,ndim), intent(out) :: ar_offdiag
    INTEGER, dimension(ndim), intent(in) :: indx
    
    integer :: inda,indb,indj,indk,spin
    integer :: indapr,indbpr,indjpr,indkpr,spinpr 
    
    integer :: i,j,dim_count,ndim1
    
    integer, dimension(:), allocatable  :: oi,oj
    real(dp), dimension(:), allocatable :: file_offdiag

    allocate(oi(buf_size))
    allocate(oj(buf_size))
    allocate(file_offdiag(buf_size))

    ar_offdiag(:,:)=0._dp
    
!!$ Full diagonalization. 

!!$ Filling the off-diagonal part of the ph-ph block

    ndim1=kpq(1,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=i+1,ndim1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)             
          ar_offdiag(indx(i),indx(j))=C1_ph_ph(inda,indj,indapr,indjpr)
          if(indj .eq. indjpr)&
                  ar_offdiag(indx(i),indx(j))=ar_offdiag(indx(i),indx(j))+CA_ph_ph(inda,indapr)
          if(inda .eq. indapr)&
               ar_offdiag(indx(i),indx(j))=ar_offdiag(indx(i),indx(j))+CB_ph_ph(indj,indjpr)
          ar_offdiag(indx(i),indx(j))=ar_offdiag(indx(i),indx(j))+CC_ph_ph(inda,indj,indapr,indjpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
       end do
    end do

       
!!$ Filling the off-diagonal part of the ph-2p2h block 
!!$ Coupling to the i=j,a=b configs

    dim_count=kpq(1,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(2,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    
          ar_offdiag(indx(i),indx(j))=C5_ph_2p2h(inda,indj,indapr,indjpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
       end do
    end do
    
!!$ Coupling to the i=j,a|=b configs   
    
    dim_count=dim_count+kpq(2,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(3,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag(indx(i),indx(j))=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
       end do
    end do
    
!!$ Coupling to the i|=j,a=b configs
    
    dim_count=dim_count+kpq(3,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(4,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag(indx(i),indx(j))=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
       end do
    end do
       
!!$ Coupling to the i|=j,a|=b I configs
       
    dim_count=dim_count+kpq(4,0)
    
    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag(indx(i),indx(j))=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
       end do
    end do

!!$ Coupling to the i|=j,a|=b II configs
       
    dim_count=dim_count+kpq(5,0)

    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=dim_count+1,dim_count+kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
          ar_offdiag(indx(i),indx(j))=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
       end do
    end do

    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)
  
  end subroutine get_offdiag_adc2_direct_MIO

!######################################################################

  subroutine get_offdiag_adc2ext_direct_MIO(ndim,kpq,ar_offdiag,indx)

  integer, intent(in) :: ndim
  integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
  real(dp), dimension(ndim,ndim), intent(out) :: ar_offdiag
  INTEGER, DIMENSION(ndim), INTENT(IN) :: indx  
  
  integer :: inda,indb,indj,indk,spin
  integer :: indapr,indbpr,indjpr,indkpr,spinpr 
  
  integer :: i,j,nlim,dim_count,ndim1
  integer :: lim1i, lim2i, lim1j, lim2j

  ar_offdiag(:,:)=0._dp 

!!$ Full diagonalization. Filling the lower half of the matrix

!!$ Filling the off-diagonal part of the ph-ph block

     ndim1=kpq(1,0)
       
     do i= 1,ndim1
        call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
        do j= 1,ndim1
           call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)             
           ar_offdiag(indx(i),indx(j))=C1_ph_ph(inda,indj,indapr,indjpr)
           if(indj .eq. indjpr)&
                ar_offdiag(indx(i),indx(j))=ar_offdiag(indx(i),indx(j))+CA_ph_ph(inda,indapr)
           if(inda .eq. indapr)&
                ar_offdiag(indx(i),indx(j))=ar_offdiag(indx(i),indx(j))+CB_ph_ph(indj,indjpr)
           ar_offdiag(indx(i),indx(j))=ar_offdiag(indx(i),indx(j))+CC_ph_ph(inda,indj,indapr,indjpr)
        end do
     end do

     
!!$ Filling the off-diagonal part of the ph-2p2h block 
!!$ Coupling to the i=j,a=b configs

       dim_count=kpq(1,0)
       
       do i= 1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j= dim_count+1,dim_count+kpq(2,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    
             ar_offdiag(indx(j),indx(i))=C5_ph_2p2h(inda,indj,indapr,indjpr)
             ar_offdiag(indx(i),indx(j))=ar_offdiag(indx(j),indx(i))
          end do
       end do
          
!!$ Coupling to the i=j,a|=b configs   
       
       dim_count=dim_count+kpq(2,0)
       
       do i= 1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j= dim_count+1,dim_count+kpq(3,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             ar_offdiag(indx(j),indx(i))=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)
             ar_offdiag(indx(i),indx(j))=ar_offdiag(indx(j),indx(i))
!!$             ar_offdiag(i,j)=ar_offdiag(j,i)
          end do
       end do

!!$ Coupling to the i|=j,a=b configs
       
       dim_count=dim_count+kpq(3,0)
             
       do i= 1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j= dim_count+1,dim_count+kpq(4,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             ar_offdiag(indx(j),indx(i))=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)
             ar_offdiag(indx(i),indx(j))=ar_offdiag(indx(j),indx(i))
!!$             ar_offdiag(i,j)=ar_offdiag(j,i)
          end do
       end do

!!$ Coupling to the i|=j,a|=b I configs
       
       dim_count=dim_count+kpq(4,0)

       do i= 1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j= dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             ar_offdiag(indx(j),indx(i))=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
             ar_offdiag(indx(i),indx(j))=ar_offdiag(indx(j),indx(i))
!!$             ar_offdiag(i,j)=ar_offdiag(j,i)
          end do
       end do

!!$ Coupling to the i|=j,a|=b II configs
       
       dim_count=dim_count+kpq(5,0)

       do i= 1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j= dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             ar_offdiag(indx(j),indx(i))=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
             ar_offdiag(indx(i),indx(j))=ar_offdiag(indx(j),indx(i))
!!$             ar_offdiag(i,j)=ar_offdiag(j,i)
          end do
       end do
    
!!$ Filling the 2p2h-2p2h block
    
!!$ (1,1) block
    
    lim1i=kpq(1,0)+1
    lim2i=kpq(1,0)+kpq(2,0)
    lim1j=lim1i
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(indx(i),indx(j))=C_1_1(inda,indj,indapr,indjpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do

!!$ (2,1) block 

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(indx(i),indx(j))=C_2_1(inda,indb,indj,indapr,indjpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do

!!$ (3,1) block
     
    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(indx(i),indx(j))=C_3_1(inda,indj,indk,indapr,indjpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do          
         
!!$ (4i,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(indx(i),indx(j))=C_4i_1(inda,indb,indj,indk,indapr,indjpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do 
 
!!$ (4ii,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(indx(i),indx(j))=C_4ii_1(inda,indb,indj,indk,indapr,indjpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do 

!!$ (2,2) block

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=lim1i
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          ar_offdiag(indx(i),indx(j))=C_2_2(inda,indb,indj,indapr,indbpr,indjpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do

!!$ (3,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(indx(i),indx(j))=C_3_2(inda,indj,indk,indapr,indbpr,indjpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do
        
!!$ (4i,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(indx(i),indx(j))=C_4i_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do

!!$ (4ii,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(indx(i),indx(j))=C_4ii_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do

!!$ (3,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=lim1i
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(indx(i),indx(j))=C_3_3(inda,indj,indk,indapr,indjpr,indkpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do

!!$ (4i,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(indx(i),indx(j))=C_4i_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
            
       end do
    end do

!!$ (4ii,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(indx(i),indx(j))=C_4ii_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do

!!$ (4i,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=lim1i
    
    
    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(indx(i),indx(j))=C_4i_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do

!!$ (4ii,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)

    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          ar_offdiag(indx(i),indx(j))=C_4ii_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do
    
!!$ (4ii,4ii) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=lim1i

    do i= lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j= lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          ar_offdiag(indx(i),indx(j))=C_4ii_4ii(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
          ar_offdiag(indx(j),indx(i))=ar_offdiag(indx(i),indx(j))
           
       end do
    end do


  end subroutine get_offdiag_adc2ext_direct_MIO

!######################################################################

subroutine get_offdiag_adc2ext_save_MIO(ndim,kpq,nbuf,count,indx,chr)
   
  integer, intent(in) :: ndim
  integer*8, intent(out) :: count
  integer, intent(out) :: nbuf
  integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
  character(1), intent(in) :: chr
  INTEGER, DIMENSION(ndim), INTENT(IN) :: indx  

  integer :: inda,indb,indj,indk,spin
  integer :: indapr,indbpr,indjpr,indkpr,spinpr 
  
  character(30) :: name
  integer  :: rec_count
  integer  :: i,j,nlim,dim_count,ndim1,unt
  integer  :: lim1i, lim2i, lim1j, lim2j
  real(dp) :: arr_offdiag_ij
  
  integer, dimension(:), allocatable  :: oi,oj
  real(dp), dimension(:), allocatable :: file_offdiag

  allocate(oi(buf_size))
  allocate(oj(buf_size))
  allocate(file_offdiag(buf_size))

  name="SCRATCH/hmlt.off"//chr
  unt=12
  
  count=0
  rec_count=0
  
  write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", name
  OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
       FORM='UNFORMATTED')

!!$ Filling the off-diagonal part of the ph-ph block

     ndim1=kpq(1,0)
       
     do i=1,ndim1
        call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
        do j=1,i-1
           call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)             
           arr_offdiag_ij=C1_ph_ph(inda,indj,indapr,indjpr)
           if(indj .eq. indjpr)&
                arr_offdiag_ij=arr_offdiag_ij+CA_ph_ph(inda,indapr)
           if(inda .eq. indapr)&
                arr_offdiag_ij=arr_offdiag_ij+CB_ph_ph(indj,indjpr)
           arr_offdiag_ij=arr_offdiag_ij+CC_ph_ph(inda,indj,indapr,indjpr)
           call register1()
        end do
     end do
   
!!$ Filling the off-diagonal part of the ph-2p2h block 
!!$ Coupling to the i=j,a=b configs

       dim_count=kpq(1,0)
       
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(2,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    
             arr_offdiag_ij=C5_ph_2p2h(inda,indj,indapr,indjpr)
             call register1()
          end do
       end do
          
!!$ Coupling to the i=j,a|=b configs   
       
       dim_count=dim_count+kpq(2,0)
       
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(3,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)
             !Culling  small matrix elements
             if (abs(arr_offdiag_ij) .gt. minc) then
                call register1()
             end if
          end do
       end do

!!$ Coupling to the i|=j,a=b configs
       
       dim_count=dim_count+kpq(3,0)
             
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(4,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)
             call register1()
          end do
       end do

!!$ Coupling to the i|=j,a|=b I configs
       
       dim_count=dim_count+kpq(4,0)

       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
             !Culling  small matrix elements
             if (abs(arr_offdiag_ij) .gt. minc) then
                call register1()
             end if
          end do
       end do

!!$ Coupling to the i|=j,a|=b II configs
       
       dim_count=dim_count+kpq(5,0)

       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
             !Culling  small matrix elements
             call register1()
          end do
       end do
    
!!$ Filling the 2p2h-2p2h block
    
!!$ (1,1) block
    
    lim1i=kpq(1,0)+1
    lim2i=kpq(1,0)+kpq(2,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_1_1(inda,indj,indapr,indjpr)
           
          call register1()
       end do
    end do

!!$ (2,1) block 

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_2_1(inda,indb,indj,indapr,indjpr)
           
          call register1()
       end do
    end do

!!$ (3,1) block
     
    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_1(inda,indj,indk,indapr,indjpr)
           
          call register1()
       end do
    end do          
         
!!$ (4i,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_1(inda,indb,indj,indk,indapr,indjpr)
           
          call register1()
       end do
    end do 
 
!!$ (4ii,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_1(inda,indb,indj,indk,indapr,indjpr)
            
          call register1()
       end do
    end do 

!!$ (2,2) block

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          arr_offdiag_ij=C_2_2(inda,indb,indj,indapr,indbpr,indjpr)
           
          call register1()
       end do
    end do

!!$ (3,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_2(inda,indj,indk,indapr,indbpr,indjpr)
            
          call register1()
       end do
    end do
        
!!$ (4i,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
           
          call register1()
       end do
    end do

!!$ (4ii,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
           
          call register1()
       end do
    end do

!!$ (3,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_3(inda,indj,indk,indapr,indjpr,indkpr)
           
          call register1()
       end do
    end do

!!$ (4i,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
           
          call register1()
       end do
    end do

!!$ (4ii,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
           
          call register1()
       end do
    end do

!!$ (4i,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
          call register1()
       end do
    end do

!!$ (4ii,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)

    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          arr_offdiag_ij=C_4ii_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
          call register1()
       end do
    end do
    
!!$ (4ii,4ii) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=lim1i

    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_4ii(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
          call register1()
       end do
    end do
    
    call register2()
    CLOSE(unt)
    write(ilog,*) 'rec_counts',nbuf
    write(ilog,*) count,' off-diagonal elements saved in file ', name

    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)

  contains
       
    subroutine register1()
      if (abs(arr_offdiag_ij) .gt. minc) then
         count=count+1
! buf_size*int(rec_count,8) can exceed the int*4 limit
         file_offdiag(count-buf_size*int(rec_count,8))=arr_offdiag_ij
         if ( indx(i) .ge. indx(j) ) then 
         oi(count-buf_size*int(rec_count,8))=indx(i)
         oj(count-buf_size*int(rec_count,8))=indx(j)
         else
         oi(count-buf_size*int(rec_count,8))=indx(j)
         oj(count-buf_size*int(rec_count,8))=indx(i)
         end if

         !Checking if the buffer is full 
         if(mod(count,buf_size) .eq. 0) then
            rec_count=rec_count+1
            nlim=buf_size
            !Saving off-diag part in file
            call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
!!$            call wrtoffat(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)  
         end if
      end if
    end subroutine register1
    
    subroutine register2()
      
      !Saving the rest in file
      nlim=count-buf_size*int(rec_count,8)
      call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
!!$      call wrtoffat(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
      rec_count=rec_count+1
      nbuf=rec_count
      
    end subroutine register2

  end subroutine get_offdiag_adc2ext_save_MIO

!######################################################################

  subroutine get_diag_adc2ext_direct_MIO(ndim1,ndim2,kpq,ar_diag,indx)
  
    integer, intent(in) :: ndim1,ndim2
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    real(dp), dimension(ndim1+ndim2), intent(out) :: ar_diag
    INTEGER, DIMENSION(ndim1+ndim2), INTENT(IN) :: indx    


    integer :: inda,indb,indj,indk,spin
    real(dp) ::ea,eb,ej,ek,temp
    
    integer :: i,lim1,lim2
    
!!$ Filling the ph-ph block
    
    do i= 1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ea=e(inda)
       ej=e(indj)
       ar_diag(indx(i))=K_ph_ph(ea,ej)
       ar_diag(indx(i))=ar_diag(indx(i))+C1_ph_ph(inda,indj,inda,indj)
       ar_diag(indx(i))=ar_diag(indx(i))+CA_ph_ph(inda,inda)
       ar_diag(indx(i))=ar_diag(indx(i))+CB_ph_ph(indj,indj)
       ar_diag(indx(i))=ar_diag(indx(i))+CC_ph_ph(inda,indj,inda,indj)
    end do

!!$ Filling the 2p2h-2p2h block
!!$ Filling (1,1) block
    
    lim1=ndim1+1
    lim2=ndim1+kpq(2,0)
    
    do i= lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(indx(i))=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(indx(i))=ar_diag(indx(i))+C_1_1(inda,indj,inda,indj)
    end do

!!$ Filling (2,2) block
    
    lim1=lim1+kpq(2,0)
    lim2=lim2+kpq(3,0)

    do i= lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(indx(i))=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(indx(i))=ar_diag(indx(i))+C_2_2(inda,indb,indj,inda,indb,indj)
    end do
    
!!$ Filling (3,3) block
    
    lim1=lim1+kpq(3,0)
    lim2=lim2+kpq(4,0)

    do i= lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(indx(i))=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(indx(i))=ar_diag(indx(i))+C_3_3(inda,indj,indk,inda,indj,indk)
    end do
    
!!$ Filling (4i,4i) block  
    
    lim1=lim1+kpq(4,0)
    lim2=lim2+kpq(5,0)

    do i= lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(indx(i))=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(indx(i))=ar_diag(indx(i))+C_4i_4i(inda,indb,indj,indk,inda,indb,indj,indk)
    end do
    
!!$ Filling (4ii,4ii) block  
    
    lim1=lim1+kpq(5,0)
    lim2=lim2+kpq(5,0)

    do i= lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(indx(i))=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(indx(i))=ar_diag(indx(i))+C_4ii_4ii(inda,indb,indj,indk,inda,indb,indj,indk)
    end do
    
  end subroutine get_diag_adc2ext_direct_MIO

!######################################################################

  subroutine get_diag_adc2ext_save_MIO(ndim1,ndim2,kpq,nbuf,indx,chr)
  
    integer, intent(in) :: ndim1,ndim2,nbuf 
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    character(1), intent(in) :: chr
    INTEGER, DIMENSION(ndim1+ndim2), INTENT(IN) :: indx    
   
    integer :: inda,indb,indj,indk,spin
    real(dp) ::ea,eb,ej,ek,temp
    
    character(30) :: name
    integer :: i,ktype,dim_count,lim1,lim2,unt,a,b,c,d1
    real(dp), dimension(ndim1+ndim2) :: ar_diag
     
    ktype=1
    name="SCRATCH/hmlt.dia"//chr 
    unt=11
    
!!$ Filling the ph-ph block
    
    do i=1, ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ea=e(inda)
       ej=e(indj)
       ar_diag(indx(i))=K_ph_ph(ea,ej)
       ar_diag(indx(i))=ar_diag(indx(i))+C1_ph_ph(inda,indj,inda,indj)
       ar_diag(indx(i))=ar_diag(indx(i))+CA_ph_ph(inda,inda)
       ar_diag(indx(i))=ar_diag(indx(i))+CB_ph_ph(indj,indj)
       ar_diag(indx(i))=ar_diag(indx(i))+CC_ph_ph(inda,indj,inda,indj)
    end do

!!$ Filling the 2p2h-2p2h block
!!$ Filling (1,1) block
    
    lim1=ndim1+1
    lim2=ndim1+kpq(2,0)
    
    do i=lim1, lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(indx(i))=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(indx(i))=ar_diag(indx(i))+C_1_1(inda,indj,inda,indj)
    end do

!!$ Filling (2,2) block
    
    lim1=lim1+kpq(2,0)
    lim2=lim2+kpq(3,0)

    do i=lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(indx(i))=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(indx(i))=ar_diag(indx(i))+C_2_2(inda,indb,indj,inda,indb,indj)
    end do
    
!!$ Filling (3,3) block
    
    lim1=lim1+kpq(3,0)
    lim2=lim2+kpq(4,0)

    do i=lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(indx(i))=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(indx(i))=ar_diag(indx(i))+C_3_3(inda,indj,indk,inda,indj,indk)
    end do
     
!!$ Filling (4i,4i) block  
    
    lim1=lim1+kpq(4,0)
    lim2=lim2+kpq(5,0)

    do i=lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(indx(i))=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(indx(i))=ar_diag(indx(i))+C_4i_4i(inda,indb,indj,indk,inda,indb,indj,indk)
    end do
    
!!$ Filling (4ii,4ii) block  
    
    lim1=lim1+kpq(5,0)
    lim2=lim2+kpq(5,0)

    do i=lim1,lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(indx(i))=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(indx(i))=ar_diag(indx(i))+C_4ii_4ii(inda,indb,indj,indk,inda,indb,indj,indk)
    end do
    
    !Saving the diagonal part in file
    write(ilog,*) "Writing",ndim1+ndim2," diagonal elements of ADC-ext. matrix in file ",name
    OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
         FORM='UNFORMATTED')
    call wrtdg(unt,ndim1+ndim2,buf_size,nbuf,ktype,ar_diag(:))
!!$    call wrtdgat(unt,ndim1+ndim2,nbuf,ar_diag(:))
    CLOSE(unt)
   
    write(ilog,*) 'Writing successful at get_diag_adc2ext_save end'
  end subroutine get_diag_adc2ext_save_MIO

!######################################################################

  subroutine get_diag_tda_save_OK(ndim,kpq, UNIT_HAM )
    
    integer, intent(in) :: ndim
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    integer, intent(in) :: UNIT_HAM
    
    integer :: i,ktype
    integer :: inda,indb,indj,indk,spin
    real(dp), dimension( ndim ) :: ar_diag
    
    ar_diag(:) = 0.d0    

    do i = 1 , ndim
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ar_diag(i) = K_ph_ph(e(inda),e(indj))
       ar_diag(i) = ar_diag(i) + C1_ph_ph(inda,indj,inda,indj)
    end do

       !Saving in file

       write(ilog,*) "Writing the diagonal part in file ", UNIT_HAM

       write( UNIT_HAM ) buf_size
       write( UNIT_HAM ) ar_diag

       write(ilog,*) 'the first element diagonal saved in', UNIT_HAM,'is:', ar_diag(1)
       write(ilog,*) 'the last  element diagonal saved in', UNIT_HAM,'is:', ar_diag( ndim )
       
  end subroutine get_diag_tda_save_OK

!######################################################################

  subroutine get_offdiag_tda_save_OK(ndim,kpq,nbuf,count, UNIT_HAM )
    
    integer, intent(in) :: ndim
    integer, intent(out) :: nbuf 
    INTEGER*8, intent(out) :: count
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    integer, intent(in) :: UNIT_HAM
    
    integer :: i,j,nlim,rec_count
    integer :: inda,indb,indj,indk,spin
    integer :: indapr,indbpr,indjpr,indkpr,spinpr
    real(dp) :: ar_offdiag_ij, ar_offdiag_ji

    integer, dimension(:), allocatable :: oi,oj
    real(dp), dimension(:), allocatable :: file_offdiag

    allocate(oi(buf_size))
    allocate(oj(buf_size))
    allocate(file_offdiag(buf_size))

    count=0
    rec_count=0

       write(ilog,*) "Writing the off-diagonal part of TDA matrix in file ", UNIT_HAM
    
    do i = 1 , ndim
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = i + 1 , ndim
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          ar_offdiag_ij=C1_ph_ph(inda,indj,indapr,indjpr)
          ar_offdiag_ji=C1_ph_ph(indapr,indjpr,inda,indj)
!          if(abs(ar_offdiag_ij-ar_offdiag_ji) .ge. 1.e-15_d) then
!             write(ilog,*) "TDA matrix is not symmetric. Stopping now."
!             stop
!          end if

!!$ Saving into vector for the following Lanzcos/Davidson routine 
            

          !Culling  small matrix elements
          if (abs(ar_offdiag_ij) .gt. minc) then
             call register1()
          end if

       end do
    end do
!!$

       call register2()
       
       deallocate(oi)
       deallocate(oj)
       deallocate(file_offdiag)

  contains
       
    subroutine register1()
      
      count=count+1
         IF ( count .eq. 1 ) then
         write(ilog,*) 'the first element not-diagonal saved in', UNIT_HAM,'is the', i , j,'one:', ar_offdiag_ij
         END IF
      file_offdiag(count-buf_size*rec_count)=ar_offdiag_ij
      oi(count-buf_size*rec_count)=i
      oj(count-buf_size*rec_count)=j
      !Checking if the buffer is full 
      if(mod(count,buf_size) .eq. 0) then
         rec_count=rec_count+1
         nlim=buf_size
         !Saving off-diag part in file
         call wrtoffdg( UNIT_HAM ,buf_size,file_offdiag(:),oi(:),oj(:),nlim) 
      end if

    end subroutine register1
       
    subroutine register2()
         
      !Saving the rest of matrix in file
      nlim=count-buf_size*rec_count
      call wrtoffdg( UNIT_HAM ,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
      rec_count=rec_count+1
      nbuf=rec_count
      
    end subroutine register2
    
  end subroutine get_offdiag_tda_save_OK

!######################################################################

  subroutine get_diag_tda_save_GS( ndim , kpq , UNIT_HAM )
    
    integer, intent(in) :: ndim
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    integer, intent(in) :: UNIT_HAM
    
    integer :: i,ktype
    integer :: inda,indb,indj,indk,spin
    real(dp), dimension( ndim + 1 ) :: ar_diag
    
    ar_diag(:) = 0.d0    

    do i = 1 , ndim
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ar_diag( i + 1 ) = K_ph_ph(e(inda),e(indj))
       ar_diag( i + 1 ) = ar_diag( i + 1 ) + C1_ph_ph(inda,indj,inda,indj)
    end do

       !Saving in file

       write(ilog,*) "Writing the diagonal part in file ", UNIT_HAM

       write( UNIT_HAM ) buf_size
       write( UNIT_HAM )   ar_diag    
       write(ilog,*) 'the first element diagonal saved in', UNIT_HAM,'is:', ar_diag(1)
       write(ilog,*) 'the last  element diagonal saved in', UNIT_HAM,'is:', ar_diag( ndim + 1 )


  end subroutine get_diag_tda_save_GS

!######################################################################

  subroutine get_offdiag_tda_save_GS(ndim,kpq,nbuf,count,UNIT_HAM)
    
    integer, intent(in) :: ndim
    integer, intent(out) :: nbuf 
    integer*8, intent(out) :: count
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    integer, intent(in) :: UNIT_HAM    

    integer  :: i,j,nlim,rec_count
    integer  :: inda,indb,indj,indk,spin
    integer  :: indapr,indbpr,indjpr,indkpr,spinpr
    real(dp) :: ar_offdiag_ij, ar_offdiag_ji

    integer, dimension(:), allocatable  :: oi,oj
    real(dp), dimension(:), allocatable :: file_offdiag
    
    allocate(oi(buf_size))
    allocate(oj(buf_size))
    allocate(file_offdiag(buf_size))

    count=0
    rec_count=0

    write(ilog,*) "Writing the off-diagonal part of TDA matrix in file ", UNIT_HAM
   
   i = 0
   do j = 1 , ndim
      ar_offdiag_ij= 0.d0
          !Culling  small matrix elements
          if (abs(ar_offdiag_ij) .gt. minc) then
             call register1()
          end if
   end do


    do i = 1 , ndim
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = i + 1 , ndim
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          ar_offdiag_ij = 0.d0 
          ar_offdiag_ij = C1_ph_ph(inda,indj,indapr,indjpr)
          ar_offdiag_ji = C1_ph_ph(indapr,indjpr,inda,indj)
!          if(abs(ar_offdiag_ij-ar_offdiag_ji) .ge. 1.e-15_d) then
!             write(ilog,*) "TDA matrix is not symmetric. Stopping now."
!             stop
!          end if

!!$ Saving into vector for the following Lanzcos/Davidson routine 
            

          !Culling  small matrix elements
          if (abs(ar_offdiag_ij) .gt. minc) then
             call register1()
          end if

       end do
    end do
!!$

       call register2()

       deallocate(oi)
       deallocate(oj)
       deallocate(file_offdiag)
       
  contains
       
    subroutine register1()
      
      count=count+1
         IF ( count .eq. 1 ) then
         write(ilog,*) 'the first element not-diagonal saved in', UNIT_HAM,'is the', i+1 , j+1,'one:', ar_offdiag_ij
         END IF
      file_offdiag(count-buf_size*rec_count)=ar_offdiag_ij
      oi(count-buf_size*rec_count) = i + 1
      oj(count-buf_size*rec_count) = j + 1
      !Checking if the buffer is full 
      if(mod(count,buf_size) .eq. 0) then
         rec_count=rec_count+1
         nlim=buf_size
         !Saving off-diag part in file
         call wrtoffdg( UNIT_HAM ,buf_size,file_offdiag(:),oi(:),oj(:),nlim) 
      end if

    end subroutine register1
       
    subroutine register2()
         
      !Saving the rest of matrix in file
      nlim=count-buf_size*rec_count
      call wrtoffdg( UNIT_HAM ,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
      rec_count=rec_count+1
      nbuf=rec_count
      
    end subroutine register2
    
  end subroutine get_offdiag_tda_save_GS

!######################################################################

  subroutine get_offdiag_adc2_save_OK(ndim,kpq,nbuf,count, UNIT_HAM )

!!$The difference from the earlier routine is that this routine returns the total number of saved els to a caller. 
    
    integer, intent(in) :: ndim
    integer, intent(out) :: nbuf
    integer*8, intent(out) :: count 
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    integer, intent(in) :: UNIT_HAM
    
    integer :: inda,indb,indj,indk,spin
    integer :: indapr,indbpr,indjpr,indkpr,spinpr 
    
    integer  :: i,j,nlim,rec_count,dim_count,ndim1
    real(dp) :: ar_offdiag_ij
    
    integer, dimension(:), allocatable  :: oi,oj
    real(dp), dimension(:), allocatable :: file_offdiag

    allocate(oi(buf_size))
    allocate(oj(buf_size))
    allocate(file_offdiag(buf_size))

    count=0
    rec_count=0
    
    
    write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", UNIT_HAM

!!$ Full diagonalization.  

!!$ Filling the off-diagonal part of the ph-ph block

    ndim1=kpq(1,0)
    
    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = i + 1 , ndim1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)             

          ar_offdiag_ij = 0.d0
 
          ar_offdiag_ij = C1_ph_ph(inda,indj,indapr,indjpr)

          if(indj .eq. indjpr)&
               ar_offdiag_ij = ar_offdiag_ij + CA_ph_ph(inda,indapr)

          if(inda .eq. indapr)&
               ar_offdiag_ij = ar_offdiag_ij + CB_ph_ph(indj,indjpr)

          ar_offdiag_ij = ar_offdiag_ij + CC_ph_ph(inda,indj,indapr,indjpr)

      if (abs(ar_offdiag_ij) .gt. minc) then
          call register1()
      end if

       end do
    end do
    
       
!!$ Filling the off-diagonal part of the ph-2p2h block 
!!$ Coupling to the i=j,a=b configs

    dim_count=kpq(1,0)
    
    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = dim_count + 1 , dim_count + kpq(2,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    

          ar_offdiag_ij = 0.d0
          ar_offdiag_ij=C5_ph_2p2h(inda,indj,indapr,indjpr)

      if (abs(ar_offdiag_ij) .gt. minc) then
          call register1()
      end if

       end do
    end do
    
!!$ Coupling to the i=j,a|=b configs   
    
    dim_count=dim_count+kpq(2,0)
    
    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = dim_count + 1 , dim_count + kpq(3,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  

          ar_offdiag_ij = 0.d0
          ar_offdiag_ij=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)

      if (abs(ar_offdiag_ij) .gt. minc) then
          call register1()
      end if

       end do
    end do
    
!!$ Coupling to the i|=j,a=b configs
    
    dim_count=dim_count+kpq(3,0)
    
    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = dim_count + 1 , dim_count + kpq(4,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  

          ar_offdiag_ij = 0.d0
          ar_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)

      if (abs(ar_offdiag_ij) .gt. minc) then
          call register1()
      end if

       end do
    end do
       
!!$ Coupling to the i|=j,a|=b I configs
       
    dim_count=dim_count+kpq(4,0)
    
    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = dim_count + 1 , dim_count + kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  

          ar_offdiag_ij = 0.d0
          ar_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)

      if (abs(ar_offdiag_ij) .gt. minc) then
          call register1()
      end if

       end do
    end do

!!$ Coupling to the i|=j,a|=b II configs
       
    dim_count=dim_count+kpq(5,0)

    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = dim_count + 1 , dim_count + kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  

          ar_offdiag_ij = 0.d0
          ar_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)

      if (abs(ar_offdiag_ij) .gt. minc) then
          call register1()
      end if

       end do
    end do

    call register2()

    write(ilog,*) count,' off-diagonal elements saved in file', UNIT_HAM

    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)

  contains
    
    subroutine register1()
      if (abs(ar_offdiag_ij) .gt. minc) then
         count=count+1
         IF ( count .eq. 1 ) then
         write(ilog,*) 'the first element not-diagonal saved in', UNIT_HAM,'is the', i , j,'one:', ar_offdiag_ij
         END IF
         file_offdiag(count-buf_size*int(rec_count,8))= ar_offdiag_ij
         oi(count-buf_size*int(rec_count,8))=i
         oj(count-buf_size*int(rec_count,8))=j
         !Checking if the buffer is full 
         if(mod(count,buf_size) .eq. 0) then
            rec_count=rec_count+1
            nlim=buf_size
            !Saving off-diag part in file
            call wrtoffdg( UNIT_HAM ,buf_size,file_offdiag(:),oi(:),oj(:),nlim) 
         end if
      end if
    end subroutine register1
    
    subroutine register2()
      
      !Saving the rest in file
      nlim=count-buf_size*int(rec_count,8)
      call wrtoffdg( UNIT_HAM ,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
      rec_count=rec_count+1
      nbuf=rec_count
      
    end subroutine register2
    
  end subroutine get_offdiag_adc2_save_OK

!######################################################################
  
  subroutine get_offdiag_adc2_save_GS(ndim,kpq,nbuf,count, UNIT_HAM )

!!$The difference from the earlier routine is that this routine returns the total number of saved els to a caller. 
    
    integer, intent(in) :: ndim
    integer, intent(out) :: nbuf
    integer*8, intent(out) :: count 
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    integer, intent(in) :: UNIT_HAM
    
    integer :: inda,indb,indj,indk,spin
    integer :: indapr,indbpr,indjpr,indkpr,spinpr 
    
    integer  :: i,j,nlim,rec_count,dim_count,ndim1
    real(dp) :: ar_offdiag_ij
    
    integer, dimension(:), allocatable  :: oi,oj
    real(dp), dimension(:), allocatable :: file_offdiag
    
    allocate(oi(buf_size))
    allocate(oj(buf_size))
    allocate(file_offdiag(buf_size))

    count=0
    rec_count=0
    
    
    write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", UNIT_HAM

!!$ Full diagonalization.  

!!$ Filling the off-diagonal part of the ph-ph block


    i = 0 
    do j = 1 , ndim
          ar_offdiag_ij = 0.d0
      if (abs(ar_offdiag_ij) .gt. minc) then
          call register1()
      end if
    end do


    ndim1=kpq(1,0)
    
    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = i + 1 , ndim1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)             

          ar_offdiag_ij = 0.d0
 
          ar_offdiag_ij = C1_ph_ph(inda,indj,indapr,indjpr)

          if(indj .eq. indjpr)&
               ar_offdiag_ij = ar_offdiag_ij + CA_ph_ph(inda,indapr)

          if(inda .eq. indapr)&
               ar_offdiag_ij = ar_offdiag_ij + CB_ph_ph(indj,indjpr)

          ar_offdiag_ij = ar_offdiag_ij + CC_ph_ph(inda,indj,indapr,indjpr)

      if (abs(ar_offdiag_ij) .gt. minc) then
          call register1()
      end if

       end do
    end do
    
       
!!$ Filling the off-diagonal part of the ph-2p2h block 
!!$ Coupling to the i=j,a=b configs

    dim_count = kpq(1,0)
    
    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = dim_count + 1 , dim_count + kpq(2,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    

          ar_offdiag_ij = 0.d0
          ar_offdiag_ij=C5_ph_2p2h(inda,indj,indapr,indjpr)

      if (abs(ar_offdiag_ij) .gt. minc) then
          call register1()
      end if

       end do
    end do
    
!!$ Coupling to the i=j,a|=b configs   
    
    dim_count = dim_count + kpq(2,0)
    
    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = dim_count + 1 , dim_count + kpq(3,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  

          ar_offdiag_ij = 0.d0
          ar_offdiag_ij=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)

      if (abs(ar_offdiag_ij) .gt. minc) then
          call register1()
      end if

       end do
    end do
    
!!$ Coupling to the i|=j,a=b configs
    
    dim_count = dim_count + kpq(3,0)
    
    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = dim_count + 1 , dim_count + kpq(4,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  

          ar_offdiag_ij = 0.d0
          ar_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)

      if (abs(ar_offdiag_ij) .gt. minc) then
          call register1()
      end if

       end do
    end do
       
!!$ Coupling to the i|=j,a|=b I configs
       
    dim_count = dim_count + kpq(4,0)
    
    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = dim_count + 1 , dim_count + kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  

          ar_offdiag_ij = 0.d0
          ar_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)

      if (abs(ar_offdiag_ij) .gt. minc) then
          call register1()
      end if

       end do
    end do

!!$ Coupling to the i|=j,a|=b II configs
       
    dim_count = dim_count + kpq(5,0)

    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j = dim_count + 1 , dim_count + kpq(5,0)
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  

          ar_offdiag_ij = 0.d0
          ar_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)

      if (abs(ar_offdiag_ij) .gt. minc) then
          call register1()
      end if

       end do
    end do

    call register2()

    write(ilog,*) count,' off-diagonal elements saved in file', UNIT_HAM

    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)

  contains
    
    subroutine register1()
      if (abs(ar_offdiag_ij) .gt. minc) then
         count=count+1
         IF ( count .eq. 1 ) then
         write(ilog,*) 'the first element not-diagonal saved in', UNIT_HAM,'is the', i+1 , j+1,'one:', ar_offdiag_ij
         END IF
         file_offdiag(count-buf_size*int(rec_count,8))= ar_offdiag_ij
         oi(count-buf_size*int(rec_count,8)) = i + 1
         oj(count-buf_size*int(rec_count,8)) = j + 1
         !Checking if the buffer is full 
         if(mod(count,buf_size) .eq. 0) then
            rec_count=rec_count+1
            nlim=buf_size
            !Saving off-diag part in file
            call wrtoffdg( UNIT_HAM ,buf_size,file_offdiag(:),oi(:),oj(:),nlim) 
         end if
      end if
    end subroutine register1
    
    subroutine register2()
      
      !Saving the rest in file
      nlim=count-buf_size*int(rec_count,8)
      call wrtoffdg( UNIT_HAM ,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
      rec_count=rec_count+1
      nbuf=rec_count
      
    end subroutine register2
    
  end subroutine get_offdiag_adc2_save_GS

!######################################################################

  subroutine get_diag_adc2_save_OK(ndim1,ndim2,kpq, UNIT_HAM )
  
    integer, intent(in) :: ndim1,ndim2
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    integer, intent(in) :: UNIT_HAM

    integer :: inda,indb,indj,indk,spin
    
    integer :: i,ktype
    real(dp), dimension(:), allocatable:: ar_diag

    allocate(ar_diag( ndim1 + ndim2 ))



!!$ Filling the ph-ph block

    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ar_diag(i)=K_ph_ph(e(inda),e(indj))
       ar_diag(i)=ar_diag(i)+C1_ph_ph(inda,indj,inda,indj)
       ar_diag(i)=ar_diag(i)+CA_ph_ph(inda,inda)
       ar_diag(i)=ar_diag(i)+CB_ph_ph(indj,indj)
       ar_diag(i)=ar_diag(i)+CC_ph_ph(inda,indj,inda,indj)
    end do
    
!!$ Filling the 2p2h-2p2h block
    
    do i = ndim1 + 1 , ndim1 + ndim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ar_diag(i)=K_2p2h_2p2h(e(inda),e(indb),e(indj),e(indk))
    end do
    
    !Saving the diagonal part in file

    write(ilog,*) "Writing the diagonal part of ADC matrix in file ", UNIT_HAM

    write( UNIT_HAM ) buf_size
    write( UNIT_HAM ) ar_diag
       write(ilog,*) 'the first element diagonal saved in', UNIT_HAM,'is:', ar_diag(1)
       write(ilog,*) 'the last  element diagonal saved in', UNIT_HAM,'is:', ar_diag( ndim1 + ndim2 )



    deallocate(ar_diag)


  end subroutine get_diag_adc2_save_OK

!######################################################################

  subroutine get_diag_adc2_save_GS(ndim1,ndim2,kpq, UNIT_HAM )
  
    integer, intent(in) :: ndim1,ndim2
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    integer, intent(in) :: UNIT_HAM

    integer :: inda,indb,indj,indk,spin
    
    integer :: i,ktype
    real(dp), dimension(:), allocatable:: ar_diag

    allocate(ar_diag( ndim1 + ndim2 + 1 ))


    ar_diag(:) = 0.d0

!!$ Filling the ph-ph block

    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ar_diag( i + 1 )=K_ph_ph(e(inda),e(indj))
       ar_diag( i + 1 )=ar_diag( i + 1 )+C1_ph_ph(inda,indj,inda,indj)
       ar_diag( i + 1 )=ar_diag( i + 1 )+CA_ph_ph(inda,inda)
       ar_diag( i + 1 )=ar_diag( i + 1 )+CB_ph_ph(indj,indj)
       ar_diag( i + 1 )=ar_diag( i + 1 )+CC_ph_ph(inda,indj,inda,indj)
    end do
    
!!$ Filling the 2p2h-2p2h block
    
    do i = ndim1 + 1 , ndim1 + ndim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ar_diag( i + 1 )=K_2p2h_2p2h(e(inda),e(indb),e(indj),e(indk))
    end do
    
    !Saving the diagonal part in file

    write(ilog,*) "Writing the diagonal part of ADC matrix in file ", UNIT_HAM

    write( UNIT_HAM ) buf_size
    write( UNIT_HAM ) ar_diag
       write(ilog,*) 'the first element diagonal saved in', UNIT_HAM,'is:', ar_diag(1)
       write(ilog,*) 'the last  element diagonal saved in', UNIT_HAM,'is:', ar_diag( ndim1 + ndim2 + 1 )



    deallocate(ar_diag)


  end subroutine get_diag_adc2_save_GS

!######################################################################

  subroutine get_diag_adc2ext_save_OK(ndim1,ndim2,kpq, UNIT_HAM )
  
    integer, intent(in) :: ndim1,ndim2
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    INTEGER, intent(in) :: UNIT_HAM
   
    integer  :: inda,indb,indj,indk,spin
    real(dp) ::ea,eb,ej,ek,temp
    
    integer :: i,ktype,dim_count,lim1,lim2,a,b,c,d1

    real(dp), dimension( ndim1 + ndim2 ) :: ar_diag
     
    
!!$ Filling the ph-ph block
    
    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ea=e(inda)
       ej=e(indj)
       ar_diag(i)=K_ph_ph(ea,ej)
       ar_diag(i)=ar_diag(i)+C1_ph_ph(inda,indj,inda,indj)
       ar_diag(i)=ar_diag(i)+CA_ph_ph(inda,inda)
       ar_diag(i)=ar_diag(i)+CB_ph_ph(indj,indj)
       ar_diag(i)=ar_diag(i)+CC_ph_ph(inda,indj,inda,indj)
    end do

!!$ Filling the 2p2h-2p2h block
!!$ Filling (1,1) block
    
    lim1=ndim1+1
    lim2=ndim1+kpq(2,0)
    
    do i = lim1 , lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_1_1(inda,indj,inda,indj)
    end do

!!$ Filling (2,2) block
    
    lim1=lim1+kpq(2,0)
    lim2=lim2+kpq(3,0)

    do i = lim1 , lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_2_2(inda,indb,indj,inda,indb,indj)
    end do
    
!!$ Filling (3,3) block
    
    lim1=lim1+kpq(3,0)
    lim2=lim2+kpq(4,0)

    do i = lim1 , lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_3_3(inda,indj,indk,inda,indj,indk)
    end do
     
!!$ Filling (4i,4i) block  
    
    lim1=lim1+kpq(4,0)
    lim2=lim2+kpq(5,0)

    do i = lim1 , lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_4i_4i(inda,indb,indj,indk,inda,indb,indj,indk)
    end do
    
!!$ Filling (4ii,4ii) block  
    
    lim1=lim1+kpq(5,0)
    lim2=lim2+kpq(5,0)

    do i = lim1 , lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag(i)=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag(i)=ar_diag(i)+C_4ii_4ii(inda,indb,indj,indk,inda,indb,indj,indk)
    end do
    
    !Saving the diagonal part in file
    write(ilog,*) "Writing", ndim1 + ndim2 ," diagonal elements of ADC-ext. matrix in file ", UNIT_HAM

    write( UNIT_HAM ) buf_size
    write( UNIT_HAM ) ar_diag
       write(ilog,*) 'the first element diagonal saved in', UNIT_HAM,'is:', ar_diag(1)
       write(ilog,*) 'the last  element diagonal saved in', UNIT_HAM,'is:', ar_diag( ndim1 + ndim2 )
   
    write(ilog,*) 'Writing successful at get_diag_adc2ext_save end'

  end subroutine get_diag_adc2ext_save_OK

!######################################################################

  subroutine get_diag_adc2ext_save_GS(ndim1,ndim2,kpq, UNIT_HAM )
  
    integer, intent(in) :: ndim1,ndim2
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    INTEGER, intent(in) :: UNIT_HAM
   
    integer  :: inda,indb,indj,indk,spin
    real(dp) ::ea,eb,ej,ek,temp
    
    integer :: i,ktype,dim_count,lim1,lim2,a,b,c,d1

    real(dp), dimension( ndim1 + ndim2 + 1 ) :: ar_diag
     
    
    ar_diag(:) = 0.d0

!!$ Filling the ph-ph block
    
    do i = 1 , ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       ea=e(inda)
       ej=e(indj)
       ar_diag( i + 1 )=K_ph_ph(ea,ej)
       ar_diag( i + 1 )=ar_diag( i + 1 )+C1_ph_ph(inda,indj,inda,indj)
       ar_diag( i + 1 )=ar_diag( i + 1 )+CA_ph_ph(inda,inda)
       ar_diag( i + 1 )=ar_diag( i + 1 )+CB_ph_ph(indj,indj)
       ar_diag( i + 1 )=ar_diag( i + 1 )+CC_ph_ph(inda,indj,inda,indj)
    end do

!!$ Filling the 2p2h-2p2h block
!!$ Filling (1,1) block
    
    lim1=ndim1+1
    lim2=ndim1+kpq(2,0)
    
    do i = lim1 , lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag( i + 1 )=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag( i + 1 )=ar_diag( i + 1 )+C_1_1(inda,indj,inda,indj)
    end do

!!$ Filling (2,2) block
    
    lim1=lim1+kpq(2,0)
    lim2=lim2+kpq(3,0)

    do i = lim1 , lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag( i + 1 )=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag( i + 1 )=ar_diag( i + 1 )+C_2_2(inda,indb,indj,inda,indb,indj)
    end do
    
!!$ Filling (3,3) block
    
    lim1=lim1+kpq(3,0)
    lim2=lim2+kpq(4,0)

    do i = lim1 , lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag( i + 1 )=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag( i + 1 )=ar_diag( i + 1 )+C_3_3(inda,indj,indk,inda,indj,indk)
    end do
     
!!$ Filling (4i,4i) block  
    
    lim1=lim1+kpq(4,0)
    lim2=lim2+kpq(5,0)

    do i = lim1 , lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag( i + 1 )=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag( i + 1 )=ar_diag( i + 1 )+C_4i_4i(inda,indb,indj,indk,inda,indb,indj,indk)
    end do
    
!!$ Filling (4ii,4ii) block  
    
    lim1=lim1+kpq(5,0)
    lim2=lim2+kpq(5,0)

    do i = lim1 , lim2
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin) 
       ea=e(inda)
       eb=e(indb)
       ej=e(indj)
       ek=e(indk)
       ar_diag( i + 1 )=K_2p2h_2p2h(ea,eb,ej,ek)
       ar_diag( i + 1 )=ar_diag( i + 1 )+C_4ii_4ii(inda,indb,indj,indk,inda,indb,indj,indk)
    end do
    
    !Saving the diagonal part in file
    write(ilog,*) "Writing", ndim1 + ndim2 + 1 ," diagonal elements of ADC-ext. matrix in file ", UNIT_HAM

    write( UNIT_HAM ) buf_size
    write( UNIT_HAM ) ar_diag
       write(ilog,*) 'the first element diagonal saved in', UNIT_HAM,'is:', ar_diag(1)
       write(ilog,*) 'the last  element diagonal saved in', UNIT_HAM,'is:', ar_diag( ndim1 + ndim2 + 1 ) 
   
    write(ilog,*) 'Writing successful at get_diag_adc2ext_save end'

  end subroutine get_diag_adc2ext_save_GS

!######################################################################

subroutine get_offdiag_adc2ext_save_OK(ndim,kpq,nbuf,count, UNIT_HAM )
   
  integer, intent(in) :: ndim
  integer*8, intent(out) :: count
  integer, intent(out) :: nbuf
  integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
  INTEGER, intent(in) :: UNIT_HAM
  
  integer :: inda,indb,indj,indk,spin
  integer :: indapr,indbpr,indjpr,indkpr,spinpr 
  
  integer  :: rec_count
  integer  :: i,j,nlim,dim_count,ndim1
  integer  :: lim1i, lim2i, lim1j, lim2j
  real(dp) :: arr_offdiag_ij
  
  integer, dimension(:), allocatable  :: oi,oj
  real(dp), dimension(:), allocatable :: file_offdiag

  allocate(oi(buf_size))
  allocate(oj(buf_size))
  allocate(file_offdiag(buf_size))

  
  count=0
  rec_count=0
  
  write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", UNIT_HAM

!!$ Filling the off-diagonal part of the ph-ph block

     ndim1=kpq(1,0)
       
     do i = 1 , ndim1
        call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
        do j = i + 1 , ndim1
           call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)             
           arr_offdiag_ij=C1_ph_ph(inda,indj,indapr,indjpr)
           if(indj .eq. indjpr)&
                arr_offdiag_ij=arr_offdiag_ij+CA_ph_ph(inda,indapr)
           if(inda .eq. indapr)&
                arr_offdiag_ij=arr_offdiag_ij+CB_ph_ph(indj,indjpr)
           arr_offdiag_ij=arr_offdiag_ij+CC_ph_ph(inda,indj,indapr,indjpr)
      if (abs(arr_offdiag_ij) .gt. minc) then
           call register1()
      end if
        end do
     end do
   
!!$ Filling the off-diagonal part of the ph-2p2h block 
!!$ Coupling to the i=j,a=b configs

       dim_count=kpq(1,0)
       
       do i = 1 , ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(2,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    
             arr_offdiag_ij=C5_ph_2p2h(inda,indj,indapr,indjpr)
      if (abs(arr_offdiag_ij) .gt. minc) then
             call register1()
      end if
          end do
       end do
          
!!$ Coupling to the i=j,a|=b configs   
       
       dim_count=dim_count+kpq(2,0)
       
       do i = 1 , ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(3,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)
             !Culling  small matrix elements
             if (abs(arr_offdiag_ij) .gt. minc) then
                call register1()
             end if
          end do
       end do

!!$ Coupling to the i|=j,a=b configs
       
       dim_count=dim_count+kpq(3,0)
             
       do i = 1 , ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(4,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)
      if (abs(arr_offdiag_ij) .gt. minc) then
             call register1()
      end if
          end do
       end do

!!$ Coupling to the i|=j,a|=b I configs
       
       dim_count=dim_count+kpq(4,0)

       do i = 1 , ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
             !Culling  small matrix elements
             if (abs(arr_offdiag_ij) .gt. minc) then
                call register1()
             end if
          end do
       end do

!!$ Coupling to the i|=j,a|=b II configs
       
       dim_count=dim_count+kpq(5,0)

       do i = 1 , ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
             !Culling  small matrix elements
      if (abs(arr_offdiag_ij) .gt. minc) then
             call register1()
      end if
          end do
       end do
    
!!$ Filling the 2p2h-2p2h block
    
!!$ (1,1) block
    
    lim1i=kpq(1,0)+1
    lim2i=kpq(1,0)+kpq(2,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_1_1(inda,indj,indapr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (2,1) block 

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_2_1(inda,indb,indj,indapr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (3,1) block
     
    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_1(inda,indj,indk,indapr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do          
         
!!$ (4i,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_1(inda,indb,indj,indk,indapr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do 
 
!!$ (4ii,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_1(inda,indb,indj,indk,indapr,indjpr)
            
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do 

!!$ (2,2) block

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          arr_offdiag_ij=C_2_2(inda,indb,indj,indapr,indbpr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (3,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_2(inda,indj,indk,indapr,indbpr,indjpr)
            
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do
        
!!$ (4i,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (4ii,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (3,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_3(inda,indj,indk,indapr,indjpr,indkpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (4i,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (4ii,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (4i,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (4ii,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)

    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          arr_offdiag_ij=C_4ii_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do
    
!!$ (4ii,4ii) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=lim1i

    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_4ii(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do
    
    call register2()

    write(ilog,*) 'rec_counts' , nbuf
    write(ilog,*) count,' off-diagonal elements saved in file ', UNIT_HAM

    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)

  contains
       
    subroutine register1()
      if (abs(arr_offdiag_ij) .gt. minc) then
         count=count+1
         IF ( count .eq. 1 ) then
         write(ilog,*) 'the first element not-diagonal saved in', UNIT_HAM,'is the', i , j,'one:', arr_offdiag_ij
         END IF
! buf_size*int(rec_count,8) can exceed the int*4 limit
         file_offdiag(count-buf_size*int(rec_count,8))=arr_offdiag_ij
         oi(count-buf_size*int(rec_count,8))=i
         oj(count-buf_size*int(rec_count,8))=j
         !Checking if the buffer is full 
         if(mod(count,buf_size) .eq. 0) then
            rec_count=rec_count+1
            nlim=buf_size
            !Saving off-diag part in file
            call wrtoffdg( UNIT_HAM ,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
         end if
      end if
    end subroutine register1
    
    subroutine register2()
      
      !Saving the rest in file
      nlim=count-buf_size*int(rec_count,8)
      call wrtoffdg( UNIT_HAM ,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
      rec_count=rec_count+1
      nbuf=rec_count
      
    end subroutine register2

  end subroutine get_offdiag_adc2ext_save_OK

!######################################################################

subroutine get_offdiag_adc2ext_save_GS(ndim,kpq,nbuf,count, UNIT_HAM )
   
  integer, intent(in) :: ndim
  integer*8, intent(out) :: count
  integer, intent(out) :: nbuf
  integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
  INTEGER, intent(in) :: UNIT_HAM
  
  integer :: inda,indb,indj,indk,spin
  integer :: indapr,indbpr,indjpr,indkpr,spinpr 
  
  integer  :: rec_count
  integer  :: i,j,nlim,dim_count,ndim1
  integer  :: lim1i, lim2i, lim1j, lim2j
  real(dp) :: arr_offdiag_ij
  
  integer, dimension(:), allocatable  :: oi,oj
  real(dp), dimension(:), allocatable :: file_offdiag

  allocate(oi(buf_size))
  allocate(oj(buf_size))
  allocate(file_offdiag(buf_size))
  
  count=0
  rec_count=0
  
  write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", UNIT_HAM

!!$ Filling the off-diagonal part of the ph-ph block


     i = 0
     do j = 1 , ndim
     arr_offdiag_ij = 0.d0
      if (abs(arr_offdiag_ij) .gt. minc) then
           call register1()
      end if
     end do



     ndim1=kpq(1,0)
       
     do i = 1 , ndim1
        call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
        do j = i + 1 , ndim1
           call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)             

           arr_offdiag_ij = 0.d0
           arr_offdiag_ij = C1_ph_ph(inda,indj,indapr,indjpr)

           if(indj .eq. indjpr)&
                arr_offdiag_ij = arr_offdiag_ij + CA_ph_ph(inda,indapr)

           if(inda .eq. indapr)&
                arr_offdiag_ij = arr_offdiag_ij + CB_ph_ph(indj,indjpr)

           arr_offdiag_ij = arr_offdiag_ij + CC_ph_ph(inda,indj,indapr,indjpr)

      if (abs(arr_offdiag_ij) .gt. minc) then
           call register1()
      end if
        end do
     end do
   
!!$ Filling the off-diagonal part of the ph-2p2h block 
!!$ Coupling to the i=j,a=b configs

       dim_count=kpq(1,0)
       
       do i = 1 , ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(2,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    
             arr_offdiag_ij=C5_ph_2p2h(inda,indj,indapr,indjpr)
      if (abs(arr_offdiag_ij) .gt. minc) then
             call register1()
      end if
          end do
       end do
          
!!$ Coupling to the i=j,a|=b configs   
       
       dim_count=dim_count+kpq(2,0)
       
       do i = 1 , ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(3,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)
             !Culling  small matrix elements
             if (abs(arr_offdiag_ij) .gt. minc) then
                call register1()
             end if
          end do
       end do

!!$ Coupling to the i|=j,a=b configs
       
       dim_count=dim_count+kpq(3,0)
             
       do i = 1 , ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(4,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)
      if (abs(arr_offdiag_ij) .gt. minc) then
             call register1()
      end if
          end do
       end do

!!$ Coupling to the i|=j,a|=b I configs
       
       dim_count=dim_count+kpq(4,0)

       do i = 1 , ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
             !Culling  small matrix elements
             if (abs(arr_offdiag_ij) .gt. minc) then
                call register1()
             end if
          end do
       end do

!!$ Coupling to the i|=j,a|=b II configs
       
       dim_count=dim_count+kpq(5,0)

       do i = 1 , ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)
             !Culling  small matrix elements
      if (abs(arr_offdiag_ij) .gt. minc) then
             call register1()
      end if
          end do
       end do
    
!!$ Filling the 2p2h-2p2h block
    
!!$ (1,1) block
    
    lim1i=kpq(1,0)+1
    lim2i=kpq(1,0)+kpq(2,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_1_1(inda,indj,indapr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (2,1) block 

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_2_1(inda,indb,indj,indapr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (3,1) block
     
    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_1(inda,indj,indk,indapr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do          
         
!!$ (4i,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_1(inda,indb,indj,indk,indapr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do 
 
!!$ (4ii,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_1(inda,indb,indj,indk,indapr,indjpr)
            
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do 

!!$ (2,2) block

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          arr_offdiag_ij=C_2_2(inda,indb,indj,indapr,indbpr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (3,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_2(inda,indj,indk,indapr,indbpr,indjpr)
            
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do
        
!!$ (4i,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (4ii,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_2(inda,indb,indj,indk,indapr,indbpr,indjpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (3,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_3(inda,indj,indk,indapr,indjpr,indkpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (4i,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (4ii,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (4i,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=lim1i
    
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do

!!$ (4ii,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)

    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          arr_offdiag_ij=C_4ii_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do
    
!!$ (4ii,4ii) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=lim1i

    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_4ii(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)
           
      if (abs(arr_offdiag_ij) .gt. minc) then
          call register1()
      end if
       end do
    end do
    
    call register2()

    write(ilog,*) 'rec_counts' , nbuf
    write(ilog,*) count,' off-diagonal elements saved in file ', UNIT_HAM

    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)

  contains
       
    subroutine register1()
      if (abs(arr_offdiag_ij) .gt. minc) then
         count=count+1
         IF ( count .eq. 1 ) then
         write(ilog,*) 'the first element not-diagonal saved in', UNIT_HAM,'is the', i+1 , j+1,'one:', arr_offdiag_ij
         END IF
! buf_size*int(rec_count,8) can exceed the int*4 limit
         file_offdiag(count-buf_size*int(rec_count,8))=arr_offdiag_ij
         oi(count-buf_size*int(rec_count,8)) = i + 1
         oj(count-buf_size*int(rec_count,8)) = j + 1
         !Checking if the buffer is full 
         if(mod(count,buf_size) .eq. 0) then
            rec_count=rec_count+1
            nlim=buf_size
            !Saving off-diag part in file
            call wrtoffdg( UNIT_HAM ,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
         end if
      end if
    end subroutine register1
    
    subroutine register2()
      
      !Saving the rest in file
      nlim=count-buf_size*int(rec_count,8)
      call wrtoffdg( UNIT_HAM ,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
      rec_count=rec_count+1
      nbuf=rec_count
      
    end subroutine register2

  end subroutine get_offdiag_adc2ext_save_GS

!#######################################################################
 
  subroutine get_offdiag_adc2ext_save_omp(ndim,kpq,nbuf,count,chr)
   
    use omp_lib
    use iomod
    
    implicit none
    
    integer, intent(in) :: ndim
    integer*8, intent(out) :: count
    integer, intent(out) :: nbuf
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    character(1), intent(in) :: chr
  
    integer :: inda,indb,indj,indk,spin
    integer :: indapr,indbpr,indjpr,indkpr,spinpr 
    
    character(30) :: name
    integer  :: rec_count
    integer  :: i,j,k,nlim,dim_count,ndim1,unt
    integer  :: lim1i, lim2i, lim1j, lim2j
    real(dp) :: arr_offdiag_ij
    
    integer, dimension(:), allocatable  :: oi,oj
    real(dp), dimension(:), allocatable :: file_offdiag
    
    integer                               :: a,b,nzero
    real(dp), dimension(:,:), allocatable :: ca,cb
    real(dp)                              :: tw1,tw2,tc1,tc2

    
    integer                                       :: nthreads,tid
    integer, dimension(:), allocatable            :: hamunit    
    integer, dimension(:,:), allocatable          :: oi_omp,oj_omp
    integer*8, dimension(:), allocatable          :: count_omp
    integer, dimension(:), allocatable            :: rec_count_omp
    integer, dimension(:), allocatable            :: nlim_omp
    integer*8                                     :: nonzero
    integer                                       :: n,nprev,itmp
    real(dp), dimension(:,:), allocatable         :: file_offdiag_omp
    character(len=120), dimension(:), allocatable :: hamfile

    integer  :: buf_size2
    real(dp) :: minc2

    integer, dimension(:), allocatable :: nsaved

    integer :: c,cr,cm

    buf_size2=buf_size
    minc2=minc

    call times(tw1,tc1)

!-----------------------------------------------------------------------
! Determine the no. threads
!-----------------------------------------------------------------------
  !$omp parallel
  nthreads=omp_get_num_threads()
  !$omp end parallel

  write(ilog,*) "nthreads:",nthreads

!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
  allocate(oi(buf_size))
  allocate(oj(buf_size))
  allocate(file_offdiag(buf_size))

  allocate(hamunit(nthreads))
  allocate(hamfile(nthreads))
  allocate(oi_omp(nthreads,buf_size))
  allocate(oj_omp(nthreads,buf_size))
  allocate(file_offdiag_omp(nthreads,buf_size))
  allocate(count_omp(nthreads))
  allocate(rec_count_omp(nthreads))
  allocate(nlim_omp(nthreads))
  allocate(nsaved(nthreads))

!-----------------------------------------------------------------------
! Open the working Hamiltonian files
!-----------------------------------------------------------------------
  do i=1,nthreads
     call freeunit(hamunit(i))
     hamfile(i)='SCRATCH/hmlt.off'//chr//'.'
     k=len_trim(hamfile(i))+1
     if (i.lt.10) then
        write(hamfile(i)(k:k),'(i1)') i
     else
        write(hamfile(i)(k:k+1),'(i2)') i
     endif
     open(unit=hamunit(i),file=hamfile(i),status='unknown',&
          access='sequential',form='unformatted')
  enddo

!-----------------------------------------------------------------------
! Precompute the results of calls to CA_ph_ph and CB_ph_ph
!-----------------------------------------------------------------------
  allocate(ca(nvirt,nvirt),cb(nocc,nocc))
  
  !$omp parallel do private(i,j) shared(ca)
  ! CA_ph_ph
  do i=1,nvirt
     do j=i,nvirt
        ca(i,j)=CA_ph_ph(nocc+i,nocc+j)
        ca(j,i)=ca(i,j)
     enddo
  enddo
  !$omp end parallel do

  !$omp parallel do private(i,j) shared(cb)
  ! CB_ph_ph
  do i=1,nocc
     do j=i,nocc
        cb(i,j)=CB_ph_ph(i,j)
        cb(j,i)=cb(i,j)
     enddo
  enddo
  !$omp end parallel do

!-----------------------------------------------------------------------
! Open the Hamiltonian file
!-----------------------------------------------------------------------
  name="SCRATCH/hmlt.off"//chr
  call freeunit(unt)
 
  write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", name
  OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
       FORM='UNFORMATTED')

!-----------------------------------------------------------------------
! Initialise counters
!-----------------------------------------------------------------------
  count=0
  rec_count=0

  count_omp=0
  rec_count_omp=0

!-----------------------------------------------------------------------
! ph-ph block
!-----------------------------------------------------------------------
     ndim1=kpq(1,0)
       
     !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
     do i=1,ndim1
        call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
        do j=1,i-1
           call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
           arr_offdiag_ij=C1_ph_ph(inda,indj,indapr,indjpr)

           if(indj .eq. indjpr)&
                arr_offdiag_ij= arr_offdiag_ij+ca(inda-nocc,indapr-nocc)

           if(inda .eq. indapr)&
                arr_offdiag_ij= arr_offdiag_ij+cb(indj,indjpr)

           arr_offdiag_ij=arr_offdiag_ij+CC_ph_ph(inda,indj,indapr,indjpr)

           tid=1+omp_get_thread_num()
             
           if (abs(arr_offdiag_ij).gt.minc) then
              count_omp(tid)=count_omp(tid)+1
              file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
              oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
              oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
              ! Checking if the buffer is full 
              if (mod(count_omp(tid),buf_size).eq.0) then
                 rec_count_omp(tid)=rec_count_omp(tid)+1
                 nlim_omp(tid)=buf_size
                 ! Saving off-diag part in file
                 call wrtoffdg(hamunit(tid),buf_size,&
                      file_offdiag_omp(tid,:),oi_omp(tid,:),&
                      oj_omp(tid,:),nlim_omp(tid))
              endif
           endif
           
        end do
     end do
     !$omp end parallel do

!-----------------------------------------------------------------------
! ph-2p2h block 
!-----------------------------------------------------------------------
!!$ Coupling to the i=j,a=b configs

     dim_count=kpq(1,0)

     !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(2,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)    
             arr_offdiag_ij=C5_ph_2p2h(inda,indj,indapr,indjpr)

             tid=1+omp_get_thread_num()
             
             if (abs(arr_offdiag_ij).gt.minc) then
                count_omp(tid)=count_omp(tid)+1
                file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
                oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
                oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
                ! Checking if the buffer is full 
                if (mod(count_omp(tid),buf_size).eq.0) then
                   rec_count_omp(tid)=rec_count_omp(tid)+1
                   nlim_omp(tid)=buf_size
                   ! Saving off-diag part in file
                   call wrtoffdg(hamunit(tid),buf_size,&
                        file_offdiag_omp(tid,:),oi_omp(tid,:),&
                        oj_omp(tid,:),nlim_omp(tid))
                endif
             endif
             
          end do
       end do
       !$omp end parallel do

!!$ Coupling to the i=j,a|=b configs   
       
       dim_count=dim_count+kpq(2,0)
       
       !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(3,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C4_ph_2p2h(inda,indj,indapr,indbpr,indjpr)

             tid=1+omp_get_thread_num()
             
             if (abs(arr_offdiag_ij).gt.minc) then
                count_omp(tid)=count_omp(tid)+1
                file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
                oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
                oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
                ! Checking if the buffer is full 
                if (mod(count_omp(tid),buf_size).eq.0) then
                   rec_count_omp(tid)=rec_count_omp(tid)+1
                   nlim_omp(tid)=buf_size
                   ! Saving off-diag part in file
                   call wrtoffdg(hamunit(tid),buf_size,&
                        file_offdiag_omp(tid,:),oi_omp(tid,:),&
                        oj_omp(tid,:),nlim_omp(tid))
                endif
             endif
             
          end do
       end do
       !$omp end parallel do

!!$ Coupling to the i|=j,a=b configs
       
       dim_count=dim_count+kpq(3,0)
       
       !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(4,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)

             tid=1+omp_get_thread_num()

             if (abs(arr_offdiag_ij).gt.minc) then
                count_omp(tid)=count_omp(tid)+1
                file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
                oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
                oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
                ! Checking if the buffer is full 
                if (mod(count_omp(tid),buf_size).eq.0) then
                   rec_count_omp(tid)=rec_count_omp(tid)+1
                   nlim_omp(tid)=buf_size
                   ! Saving off-diag part in file
                   call wrtoffdg(hamunit(tid),buf_size,&
                        file_offdiag_omp(tid,:),oi_omp(tid,:),&
                        oj_omp(tid,:),nlim_omp(tid))
                endif
             endif
             
          end do
       end do
       !$omp end parallel do

!!$ Coupling to the i|=j,a|=b I configs
       
       dim_count=dim_count+kpq(4,0)

       !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)

             tid=1+omp_get_thread_num()

             if (abs(arr_offdiag_ij).gt.minc) then
                count_omp(tid)=count_omp(tid)+1
                file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
                oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
                oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
                ! Checking if the buffer is full 
                if (mod(count_omp(tid),buf_size).eq.0) then
                   rec_count_omp(tid)=rec_count_omp(tid)+1
                   nlim_omp(tid)=buf_size
                   ! Saving off-diag part in file
                   call wrtoffdg(hamunit(tid),buf_size,&
                        file_offdiag_omp(tid,:),oi_omp(tid,:),&
                        oj_omp(tid,:),nlim_omp(tid))
              endif
           endif
             
          end do
       end do
       !$omp end parallel do

!!$ Coupling to the i|=j,a|=b II configs
       
       dim_count=dim_count+kpq(5,0)

       !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
             arr_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)

             tid=1+omp_get_thread_num()

             if (abs(arr_offdiag_ij).gt.minc) then
                count_omp(tid)=count_omp(tid)+1
                file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
                oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
                oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
                ! Checking if the buffer is full 
                if (mod(count_omp(tid),buf_size).eq.0) then
                   rec_count_omp(tid)=rec_count_omp(tid)+1
                   nlim_omp(tid)=buf_size
                   ! Saving off-diag part in file
                   call wrtoffdg(hamunit(tid),buf_size,&
                        file_offdiag_omp(tid,:),oi_omp(tid,:),&
                        oj_omp(tid,:),nlim_omp(tid))
                endif
             endif

          end do
       end do
       !$omp end parallel do

!-----------------------------------------------------------------------
! 2p2h-2p2h block
!-----------------------------------------------------------------------
!!$ (1,1) block
    
    lim1i=kpq(1,0)+1
    lim2i=kpq(1,0)+kpq(2,0)
    lim1j=lim1i

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i       
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          
          arr_offdiag_ij=C_1_1(inda,indj,indapr,indjpr)           

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif
          
       enddo
    enddo
    !$omp end parallel do

!!$ (2,1) block 

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
    
    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_2_1(inda,indb,indj,indapr,indjpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif
          
       end do
    end do
    !$omp end parallel do

!!$ (3,1) block
     
    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)
 
    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_1(inda,indj,indk,indapr,indjpr)
           
          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif

       end do
    end do
    !$omp end parallel do

!!$ (4i,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_1(inda,indb,indj,indk,indapr,indjpr)
           
          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif
          
       end do
    end do 
    !$omp end parallel do

!!$ (4ii,1) block

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+1
    lim2j=kpq(1,0)+kpq(2,0)

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_1(inda,indb,indj,indk,indapr,indjpr)
            
          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif

       end do
    end do 
    !$omp end parallel do

!!$ (2,2) block

    lim1i=kpq(1,0)+kpq(2,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)
    lim1j=lim1i

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          arr_offdiag_ij=C_2_2(inda,indb,indj,indapr,indbpr,indjpr)
          
          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif

       end do
    end do
    !$omp end parallel do

!!$ (3,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_2(inda,indj,indk,indapr,indbpr,indjpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif

       end do
    end do
    !$omp end parallel do

!!$ (4i,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_2(inda,indb,indj,indk,indapr,indbpr,indjpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif

       end do
    end do
    !$omp end parallel do

!!$ (4ii,2) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)
    
    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_2(inda,indb,indj,indk,indapr,indbpr,indjpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif

       end do
    end do
    !$omp end parallel do

!!$ (3,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=lim1i

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_3(inda,indj,indk,indapr,indjpr,indkpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif

       end do
    end do
    !$omp end parallel do

!!$ (4i,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_3(inda,indb,indj,indk,indapr,indjpr,indkpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif

       end do
    end do    
    !$omp end parallel do

!!$ (4ii,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
           
          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif
          
       end do
    end do
    !$omp end parallel do

!!$ (4i,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=lim1i

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif

       end do
    end do
    !$omp end parallel do

!!$ (4ii,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
 
    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          arr_offdiag_ij=C_4ii_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif

       end do
    end do
    !$omp end parallel do
   
!!$ (4ii,4ii) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=lim1i
 
    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_4ii(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size
                ! Saving off-diag part in file
                call wrtoffdg(hamunit(tid),buf_size,&
                     file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid))
             endif
          endif

       end do
    end do
    !$omp end parallel do

!-----------------------------------------------------------------------
! Assemble the complete hmlt.off file
!-----------------------------------------------------------------------
    write(ilog,*) "hmlt.off assembly..."

    count=0
    do i=1,nthreads
       count=count+count_omp(i)
    enddo

    ! Complete records
    write(ilog,*) "       complete records"
    do i=1,nthreads
       rewind(hamunit(i))
       do j=1,rec_count_omp(i)
          rec_count=rec_count+1
          read(hamunit(i)) file_offdiag(:),oi(:),oj(:),nlim
          call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),&
               buf_size)
       enddo
    enddo

    ! Incomplete records
    write(ilog,*) "       incomplete records"
    do i=1,nthreads
       nsaved(i)=mod(count_omp(i),buf_size)
    enddo
    n=nsaved(1)    
    file_offdiag(1:n)=file_offdiag_omp(1,1:n)
    oi(1:n)=oi_omp(1,1:n)
    oj(1:n)=oj_omp(1,1:n)
    nprev=n
    do i=2,nthreads

       n=n+nsaved(i)
              
       if (n.gt.buf_size) then
          ! The buffer is full. Write the buffer to disk and
          ! then save the remaining elements for thread i to the
          ! buffer
          !
          ! (i) Elements for thread i that can fit into the buffer
          itmp=buf_size-nprev
          file_offdiag(nprev+1:buf_size)=file_offdiag_omp(i,1:itmp)
          oi(nprev+1:buf_size)=oi_omp(i,1:itmp)
          oj(nprev+1:buf_size)=oj_omp(i,1:itmp)
          rec_count=rec_count+1
          call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),&
               buf_size)
          !
          ! (ii) Elements for thread i that couldn't fit into the buffer
          n=nsaved(i)-itmp
          file_offdiag(1:n)=file_offdiag_omp(i,itmp+1:nsaved(i))
          oi(1:n)=oi_omp(i,itmp+1:nsaved(i))
          oj(1:n)=oj_omp(i,itmp+1:nsaved(i))
       else
          ! The buffer is not yet full. Add all elements for thread i
          ! to the buffer
          file_offdiag(nprev+1:n)=file_offdiag_omp(i,1:nsaved(i))          
          oi(nprev+1:n)=oi_omp(i,1:nsaved(i))          
          oj(nprev+1:n)=oj_omp(i,1:nsaved(i))          
       endif

       nprev=n

    enddo

    ! Last, potentially incomplete buffer
    nlim=count-buf_size*int(rec_count,8)
    call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
    rec_count=rec_count+1
    nbuf=rec_count
        
!    ! Delete the working files
!    do i=1,nthreads
!       call system('rm -rf '//trim(hamfile(i)))
!    enddo

    write(ilog,*) 'rec_counts',nbuf
    write(ilog,*) count,' off-diagonal elements saved in file ', name

!-----------------------------------------------------------------------    
! Write any incomplete records to file and save the record counts
! for each file
!-----------------------------------------------------------------------    
    ! Write the incomplete records to file
    do i=1,nthreads       
       nlim=count_omp(i)-buf_size*int(rec_count_omp(i),8)       
       if (nlim.gt.0) then
          rec_count_omp(i)=rec_count_omp(i)+1
          call wrtoffdg(hamunit(i),buf_size,&
               file_offdiag_omp(i,:),oi_omp(i,:),&
               oj_omp(i,:),nlim)
       endif
    enddo

    ! Save the record counts to the nrec_omp array for use later on
    nrec_omp=rec_count_omp

!-----------------------------------------------------------------------    
! Close files
!-----------------------------------------------------------------------    
    close(unt)
    do i=1,nthreads
       close(hamunit(i))
    enddo

!-----------------------------------------------------------------------    
! Deallocate arrays
!-----------------------------------------------------------------------
    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)

    deallocate(hamunit)
    deallocate(hamfile)
    deallocate(oi_omp)
    deallocate(oj_omp)
    deallocate(file_offdiag_omp)
    deallocate(count_omp)
    deallocate(rec_count_omp)
    deallocate(nlim_omp)
    deallocate(nsaved)

    call times(tw2,tc2)
    write(ilog,*) "Time taken:",tw2-tw1

    return

  end subroutine get_offdiag_adc2ext_save_omp

!#######################################################################

  subroutine get_offdiag_adc2ext_save_cvs_omp(ndim,kpq,nbuf,count,chr)
   
    use omp_lib
    use iomod
    
    implicit none

    integer, intent(in) :: ndim
    integer*8, intent(out) :: count
    integer, intent(out) :: nbuf
    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq
    character(1), intent(in) :: chr
    
    integer :: inda,indb,indj,indk,spin
    integer :: indapr,indbpr,indjpr,indkpr,spinpr 
    
    character(30) :: name
    integer  :: rec_count
    integer  :: i,j,k,nlim,dim_count,ndim1,unt
    integer  :: lim1i, lim2i, lim1j, lim2j
    real(dp) :: arr_offdiag_ij
    
    integer, dimension(:), allocatable  :: oi,oj
    real(dp), dimension(:), allocatable :: file_offdiag
    
    integer                               :: a,b,nzero
    real(dp), dimension(:,:), allocatable :: ca,cb
    real(dp)                              :: tw1,tw2,tc1,tc2
    
    integer                                       :: nthreads,tid
    integer, dimension(:), allocatable            :: hamunit    
    integer, dimension(:,:), allocatable          :: oi_omp,oj_omp
    integer*8, dimension(:), allocatable          :: count_omp
    integer, dimension(:), allocatable            :: rec_count_omp
    integer, dimension(:), allocatable            :: nlim_omp
    integer*8                                     :: nonzero
    integer                                       :: n,nprev,itmp
    real(dp), dimension(:,:), allocatable         :: file_offdiag_omp
    character(len=120), dimension(:), allocatable :: hamfile

    integer  :: buf_size2
    real(dp) :: minc2

    integer, dimension(:), allocatable :: nsaved

    integer :: c,cr,cm

    buf_size2=buf_size
    minc2=minc

    call times(tw1,tc1)

!-----------------------------------------------------------------------
! Determine the no. threads
!-----------------------------------------------------------------------
  !$omp parallel
  nthreads=omp_get_num_threads()
  !$omp end parallel

  write(ilog,*) "nthreads:",nthreads

!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
  allocate(oi(buf_size))
  allocate(oj(buf_size))
  allocate(file_offdiag(buf_size))

  allocate(hamunit(nthreads))
  allocate(hamfile(nthreads))
  allocate(oi_omp(nthreads,buf_size))
  allocate(oj_omp(nthreads,buf_size))
  allocate(file_offdiag_omp(nthreads,buf_size))
  allocate(count_omp(nthreads))
  allocate(rec_count_omp(nthreads))
  allocate(nlim_omp(nthreads))
  allocate(nsaved(nthreads))

!-----------------------------------------------------------------------
! Open the working Hamiltonian files
!-----------------------------------------------------------------------
  do i=1,nthreads
     call freeunit(hamunit(i))
     hamfile(i)='SCRATCH/hmlt.off'//chr//'.'
     k=len_trim(hamfile(i))+1
     if (i.lt.10) then
        write(hamfile(i)(k:k),'(i1)') i
     else
        write(hamfile(i)(k:k+1),'(i2)') i
     endif
     open(unit=hamunit(i),file=hamfile(i),status='unknown',&
          access='sequential',form='unformatted')
  enddo

!-----------------------------------------------------------------------
! Precompute the results of calls to CA_ph_ph and CB_ph_ph
!-----------------------------------------------------------------------
  allocate(ca(nvirt,nvirt),cb(nocc,nocc))
  
  !$omp parallel do private(i,j) shared(ca)
  ! CA_ph_ph
  do i=1,nvirt
     do j=i,nvirt
        ca(i,j)=CA_ph_ph(nocc+i,nocc+j)
        ca(j,i)=ca(i,j)
     enddo
  enddo
  !$omp end parallel do

  !$omp parallel do private(i,j) shared(cb)
  ! CB_ph_ph
  do i=1,nocc
     do j=i,nocc
        cb(i,j)=CB_ph_ph(i,j)
        cb(j,i)=cb(i,j)
     enddo
  enddo
  !$omp end parallel do

!-----------------------------------------------------------------------
! Open the Hamiltonian file
!-----------------------------------------------------------------------
  name="SCRATCH/hmlt.off"//chr
  call freeunit(unt)
 
  write(ilog,*) "Writing the off-diagonal part of ADC matrix in file ", name
  OPEN(UNIT=unt,FILE=name,STATUS='UNKNOWN',ACCESS='SEQUENTIAL',&
       FORM='UNFORMATTED')

!-----------------------------------------------------------------------
! Initialise counters
!-----------------------------------------------------------------------
  count=0
  rec_count=0

  count_omp=0
  rec_count_omp=0

!-----------------------------------------------------------------------
! ph-ph block
!-----------------------------------------------------------------------
     ndim1=kpq(1,0)

     !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,ndim1)
     do i=1,ndim1
        call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
        do j=1,i-1
           call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
           arr_offdiag_ij=C1_ph_ph(inda,indj,indapr,indjpr)

           if(indj .eq. indjpr)&
                arr_offdiag_ij= arr_offdiag_ij+ca(inda-nocc,indapr-nocc)

           if(inda .eq. indapr)&
                arr_offdiag_ij= arr_offdiag_ij+cb(indj,indjpr)

           arr_offdiag_ij=arr_offdiag_ij+CC_ph_ph(inda,indj,indapr,indjpr)

           tid=1+omp_get_thread_num()
             
           if (abs(arr_offdiag_ij).gt.minc2) then
              count_omp(tid)=count_omp(tid)+1
              file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
              oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
              oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
              ! Checking if the buffer is full 
              if (mod(count_omp(tid),buf_size2).eq.0) then
                 rec_count_omp(tid)=rec_count_omp(tid)+1
                 nlim_omp(tid)=buf_size2
                 ! Saving off-diag part in file
                 write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                      oj_omp(tid,:),nlim_omp(tid)
              endif
           endif
           
        end do
     end do
     !$omp end parallel do

!-----------------------------------------------------------------------
! ph-2p2h block 
!-----------------------------------------------------------------------
!!$ Coupling to the i|=j,a=b configs

       dim_count=kpq(1,0)
             
       !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(4,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C3_ph_2p2h(inda,indj,indapr,indjpr,indkpr)

             tid=1+omp_get_thread_num()

             if (abs(arr_offdiag_ij).gt.minc2) then
                count_omp(tid)=count_omp(tid)+1
                file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
                oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
                oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
                ! Checking if the buffer is full 
                if (mod(count_omp(tid),buf_size2).eq.0) then
                   rec_count_omp(tid)=rec_count_omp(tid)+1
                   nlim_omp(tid)=buf_size2
                   ! Saving off-diag part in file
                   write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                        oj_omp(tid,:),nlim_omp(tid)
                endif
             endif
             
          end do
       end do
       !$omp end parallel do

!!$ Coupling to the i|=j,a|=b I configs

       dim_count=dim_count+kpq(4,0)

       !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)  
             arr_offdiag_ij=C1_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)

             tid=1+omp_get_thread_num()

             if (abs(arr_offdiag_ij).gt.minc2) then
                count_omp(tid)=count_omp(tid)+1
                file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
                oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
                oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
                ! Checking if the buffer is full 
                if (mod(count_omp(tid),buf_size2).eq.0) then
                   rec_count_omp(tid)=rec_count_omp(tid)+1
                   nlim_omp(tid)=buf_size2
                   ! Saving off-diag part in file
                   write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                        oj_omp(tid,:),nlim_omp(tid)
              endif
           endif
             
          end do
       end do
       !$omp end parallel do

!!$ Coupling to the i|=j,a|=b II configs
       
       dim_count=dim_count+kpq(5,0)

     !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,dim_count,ndim1)
       do i=1,ndim1
          call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
          do j=dim_count+1,dim_count+kpq(5,0)
             call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
             arr_offdiag_ij=C2_ph_2p2h(inda,indj,indapr,indbpr,indjpr,indkpr)

             tid=1+omp_get_thread_num()

             if (abs(arr_offdiag_ij).gt.minc2) then
                count_omp(tid)=count_omp(tid)+1
                file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
                oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
                oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
                ! Checking if the buffer is full 
                if (mod(count_omp(tid),buf_size2).eq.0) then
                   rec_count_omp(tid)=rec_count_omp(tid)+1
                   nlim_omp(tid)=buf_size2
                   ! Saving off-diag part in file
                   write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                        oj_omp(tid,:),nlim_omp(tid)
                endif
             endif

          end do
       end do
       !$omp end parallel do

!-----------------------------------------------------------------------
! 2p2h-2p2h block
!-----------------------------------------------------------------------
!!$ (3,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    lim1j=lim1i
    
    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_3_3(inda,indj,indk,indapr,indjpr,indkpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc2) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size2).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size2
                ! Saving off-diag part in file
                write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid)
             endif
          endif

       end do
    end do
    !$omp end parallel do

!!$ (4i,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_3(inda,indb,indj,indk,indapr,indjpr,indkpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc2) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size2).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size2
                ! Saving off-diag part in file
                write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid)
             endif
          endif

       end do
    end do
    !$omp end parallel do

!!$ (4ii,3) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)
    
    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_3(inda,indb,indj,indk,indapr,indjpr,indkpr)
           
          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc2) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size2).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size2
                ! Saving off-diag part in file
                write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid)
             endif
          endif
          
       end do
    end do
    !$omp end parallel do

!!$ (4i,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)
    lim1j=lim1i
    
    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4i_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc2) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size2).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size2
                ! Saving off-diag part in file
                write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid)
             endif
          endif

       end do
    end do
    !$omp end parallel do

!!$ (4ii,4i) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+1
    lim2j=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,lim2j
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)
          arr_offdiag_ij=C_4ii_4i(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc2) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size2).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size2
                ! Saving off-diag part in file
                write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid)
             endif
          endif

       end do
    end do
    !$omp end parallel do
    
!!$ (4ii,4ii) block 

    lim1i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+1
    lim2i=kpq(1,0)+kpq(2,0)+kpq(3,0)+kpq(4,0)+kpq(5,0)+kpq(5,0)
    lim1j=lim1i

    !$omp parallel do private(i,j,arr_offdiag_ij,inda,indb,indj,indk,spin,indapr,indbpr,indjpr,indkpr,spinpr,tid) shared(count_omp,file_offdiag_omp,rec_count_omp,nlim_omp,oi_omp,oj_omp,hamunit,kpq) firstprivate(buf_size2,minc2,lim1i,lim2i,lim1j,lim2j)
    do i=lim1i,lim2i
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       do j=lim1j,i-1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr) 
          arr_offdiag_ij=C_4ii_4ii(inda,indb,indj,indk,indapr,indbpr,indjpr,indkpr)

          tid=1+omp_get_thread_num()

          if (abs(arr_offdiag_ij).gt.minc2) then
             count_omp(tid)=count_omp(tid)+1
             file_offdiag_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=arr_offdiag_ij
             oi_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=i
             oj_omp(tid,count_omp(tid)-buf_size2*int(rec_count_omp(tid),8))=j
             ! Checking if the buffer is full 
             if (mod(count_omp(tid),buf_size2).eq.0) then
                rec_count_omp(tid)=rec_count_omp(tid)+1
                nlim_omp(tid)=buf_size2
                ! Saving off-diag part in file
                write(hamunit(tid)) file_offdiag_omp(tid,:),oi_omp(tid,:),&
                     oj_omp(tid,:),nlim_omp(tid)
             endif
          endif

       end do
    end do
    !$omp end parallel do

!-----------------------------------------------------------------------
! Assemble the complete hmlt.off file
!-----------------------------------------------------------------------
    count=0
    do i=1,nthreads
       count=count+count_omp(i)
    enddo

    ! Complete records
    do i=1,nthreads
       rewind(hamunit(i))
       do j=1,rec_count_omp(i)
          rec_count=rec_count+1
          read(hamunit(i)) file_offdiag(:),oi(:),oj(:),nlim
          call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),&
               buf_size)
       enddo
    enddo

    ! Incomplete records
    do i=1,nthreads
       nsaved(i)=mod(count_omp(i),buf_size)
    enddo
    n=nsaved(1)
    file_offdiag(1:n)=file_offdiag_omp(1,1:n)
    oi(1:n)=oi_omp(1,1:n)
    oj(1:n)=oj_omp(1,1:n)
    nprev=n
    do i=2,nthreads

       n=n+nsaved(i)
              
       if (n.gt.buf_size) then
          ! The buffer is full. Write the buffer to disk and
          ! then save the remaining elements for thread i to the
          ! buffer
          !
          ! (i) Elements for thread i that can fit into the buffer
          itmp=buf_size-nprev
          file_offdiag(nprev+1:buf_size)=file_offdiag_omp(i,1:itmp)
          oi(nprev+1:buf_size)=oi_omp(i,1:itmp)
          oj(nprev+1:buf_size)=oj_omp(i,1:itmp)
          rec_count=rec_count+1
          call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),&
               buf_size)
          !
          ! (ii) Elements for thread i that couldn't fit into the buffer
          n=nsaved(i)-itmp
          file_offdiag(1:n)=file_offdiag_omp(i,itmp+1:nsaved(i))
          oi(1:n)=oi_omp(i,itmp+1:nsaved(i))
          oj(1:n)=oj_omp(i,itmp+1:nsaved(i))
       else
          ! The buffer is not yet full. Add all elements for thread i
          ! to the buffer
          file_offdiag(nprev+1:n)=file_offdiag_omp(i,1:nsaved(i))          
          oi(nprev+1:n)=oi_omp(i,1:nsaved(i))          
          oj(nprev+1:n)=oj_omp(i,1:nsaved(i))          
       endif

       nprev=n

    enddo

    ! Last, potentially incomplete buffer
    nlim=count-buf_size*int(rec_count,8)
    call wrtoffdg(unt,buf_size,file_offdiag(:),oi(:),oj(:),nlim)
    rec_count=rec_count+1
    nbuf=rec_count
    
!    ! Delete the working files
!    do i=1,nthreads
!       call system('rm -rf '//trim(hamfile(i)))
!    enddo

    write(ilog,*) 'rec_counts',nbuf
    write(ilog,*) count,' off-diagonal elements saved in file ', name

!-----------------------------------------------------------------------    
! Write any incomplete records to file and save the record counts
! for each file
!-----------------------------------------------------------------------    
    ! Write the incomplete records to file
    do i=1,nthreads
       nlim=count_omp(i)-buf_size*int(rec_count_omp(i),8)       
       if (nlim.gt.0) then
          rec_count_omp(i)=rec_count_omp(i)+1
          call wrtoffdg(hamunit(i),buf_size,&
               file_offdiag_omp(i,:),oi_omp(i,:),&
               oj_omp(i,:),nlim)
       endif
    enddo

    ! Save the record counts to the nrec_omp array for use later on
    nrec_omp=rec_count_omp

!-----------------------------------------------------------------------    
! Close files
!-----------------------------------------------------------------------    
    close(unt)
    do i=1,nthreads
       close(hamunit(i))
    enddo

!-----------------------------------------------------------------------    
! Deallocate arrays
!-----------------------------------------------------------------------
    deallocate(oi)
    deallocate(oj)
    deallocate(file_offdiag)

    deallocate(hamunit)
    deallocate(hamfile)
    deallocate(oi_omp)
    deallocate(oj_omp)
    deallocate(file_offdiag_omp)
    deallocate(count_omp)
    deallocate(rec_count_omp)
    deallocate(nlim_omp)
    deallocate(nsaved)

    call times(tw2,tc2)
    write(ilog,*) "Time taken:",tw2-tw1

    return

  end subroutine get_offdiag_adc2ext_save_cvs_omp

!#######################################################################

  subroutine get_offdiag_adc1ext_save_omp(ndim,kpq,arr)

    use omp_lib
    use iomod

    implicit none

    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq

    integer, intent(in)                   :: ndim
    integer                               :: inda,indb,indj,indk,spin
    integer                               :: indapr,indbpr,indjpr,&
                                             indkpr,spinpr
    integer                               :: i,j
    integer                               :: nthreads,tid,ndim1
    real(dp), dimension(ndim,ndim)        :: arr
    real(dp), dimension(:,:), allocatable :: ca,cb

!-----------------------------------------------------------------------
! Determine the no. threads
!-----------------------------------------------------------------------
    !$omp parallel
    nthreads=omp_get_num_threads()
    !$omp end parallel
    
    write(ilog,*) "nthreads:",nthreads

!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
    allocate(ca(nvirt,nvirt),cb(nocc,nocc))
    
!-----------------------------------------------------------------------
! Precompute the results of calls to CA_ph_ph and CB_ph_ph
!-----------------------------------------------------------------------
    !$omp parallel do private(i,j) shared(ca)
    ! CA_ph_ph
    do i=1,nvirt
       do j=i,nvirt
          ca(i,j)=CA_ph_ph(nocc+i,nocc+j)
          ca(j,i)=ca(i,j)
       enddo
    enddo
    !$omp end parallel do

    !$omp parallel do private(i,j) shared(cb)
    ! CB_ph_ph
    do i=1,nocc
       do j=i,nocc
          cb(i,j)=CB_ph_ph(i,j)
          cb(j,i)=cb(i,j)
       enddo
    enddo
    !$omp end parallel do

!-----------------------------------------------------------------------
! ph-ph block
!-----------------------------------------------------------------------
    ndim1=kpq(1,0)

    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)

       do j=i+1,ndim1
          call get_indices(kpq(:,j),indapr,indbpr,indjpr,indkpr,spinpr)

          arr(i,j)=C1_ph_ph(inda,indj,indapr,indjpr)

          if(indj.eq.indjpr)&
               arr(i,j)=arr(i,j)+ca(inda-nocc,indapr-nocc)

          if(inda.eq.indapr)&
               arr(i,j)=arr(i,j)+cb(indj,indjpr)

          arr(i,j)=arr(i,j)+CC_ph_ph(inda,indj,indapr,indjpr)

          arr(j,i)=arr(i,j)
          
       enddo

    enddo

!-----------------------------------------------------------------------
! Deallocate arrays
!-----------------------------------------------------------------------
    deallocate(ca,cb)
    
    return
    
  end subroutine get_offdiag_adc1ext_save_omp

!#######################################################################

  subroutine get_diag_adc1ext_save_omp(ndim,kpq,arr)

    use omp_lib
    use iomod

    implicit none

    integer, dimension(7,0:nBas**2*nOcc**2), intent(in) :: kpq

    integer, intent(in)                   :: ndim
    integer                               :: inda,indb,indj,indk,spin
    integer                               :: indapr,indbpr,indjpr,&
                                             indkpr,spinpr
    integer                               :: i,j
    integer                               :: nthreads,tid,ndim1
    real(dp), dimension(ndim)             :: arr
    real(dp), dimension(:,:), allocatable :: ca,cb
    
!-----------------------------------------------------------------------
! Determine the no. threads
!-----------------------------------------------------------------------
    !$omp parallel
    nthreads=omp_get_num_threads()
    !$omp end parallel
    
    write(ilog,*) "nthreads:",nthreads

!-----------------------------------------------------------------------
! Allocate arrays
!-----------------------------------------------------------------------
    allocate(ca(nvirt,nvirt),cb(nocc,nocc))
    
!-----------------------------------------------------------------------
! Precompute the results of calls to CA_ph_ph and CB_ph_ph
!-----------------------------------------------------------------------
    !$omp parallel do private(i,j) shared(ca)
    ! CA_ph_ph
    do i=1,nvirt
       do j=i,nvirt
          ca(i,j)=CA_ph_ph(nocc+i,nocc+j)
          ca(j,i)=ca(i,j)
       enddo
    enddo
    !$omp end parallel do

    !$omp parallel do private(i,j) shared(cb)
    ! CB_ph_ph
    do i=1,nocc
       do j=i,nocc
          cb(i,j)=CB_ph_ph(i,j)
          cb(j,i)=cb(i,j)
       enddo
    enddo
    !$omp end parallel do

!-----------------------------------------------------------------------
! ph-ph block
!-----------------------------------------------------------------------
    ndim1=kpq(1,0)

    do i=1,ndim1
       call get_indices(kpq(:,i),inda,indb,indj,indk,spin)
       arr(i)=K_ph_ph(e(inda),e(indj))
       arr(i)=arr(i)+C1_ph_ph(inda,indj,inda,indj)
       arr(i)=arr(i)+ca(inda-nocc,inda-nocc)
       arr(i)=arr(i)+cb(indj,indj)
       arr(i)=arr(i)+CC_ph_ph(inda,indj,inda,indj)
    enddo
       
    return
    
  end subroutine get_diag_adc1ext_save_omp
  
!#######################################################################

end module get_matrix
