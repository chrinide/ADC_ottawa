  module rdinput

  contains

!#######################################################################

    subroutine read_input
      
      use parameters
      use parsemod
      use iomod

      implicit none
      
      integer            :: i
      character(len=120) :: ain,atmp
      logical            :: iscvs,energyonly,ldav,llanc

!-----------------------------------------------------------------------
! Set 'traps'
!-----------------------------------------------------------------------
      ain=''
      energyonly=.false.
      ldav=.false.
      llanc=.false.
      iscvs=.false.

!-----------------------------------------------------------------------
! Read input file name
!-----------------------------------------------------------------------
      call getarg(1,ain)

!-----------------------------------------------------------------------
! Read input file
!-----------------------------------------------------------------------
5     continue
      call rdinp(iin)
        
      i=0
      if (keyword(1).ne.'end-input') then
10       continue
         i=i+1
         
         if (keyword(i).eq.'method') then
            if (keyword(i+1).eq.'=') then
               i=i+2
               if (keyword(i).eq.'adc1') then
                  method=1
               else if (keyword(i).eq.'adc2'.or.keyword(i).eq.'adc2-s') then
                  method=2
               else if (keyword(i).eq.'adc2-x') then
                  method=3
               endif
            else
               goto 100
            endif
            
         else if (keyword(i).eq.'istate_symm') then
            if (keyword(i+1).eq.'=') then
               i=i+2
               read(keyword(i),*) nirrep
            else
               goto 100
            endif

         else if (keyword(i).eq.'dipole_symm') then
            if (keyword(i+1).eq.'=') then
               i=i+2
               read(keyword(i),*) nirrep2
            else
               goto 100
            endif

         else if (keyword(i).eq.'initial_state') then
            if (keyword(i+1).eq.'=') then
               i=i+2
               read(keyword(i),*) statenumber
            else
               goto 100
            endif

         else if (keyword(i).eq.'dipole_component') then
            if (keyword(i+1).eq.'=') then
               i=i+2
               read(keyword(i),'(a)') tranmom
               tranmom2=tranmom
            else
               goto 100
            endif
            
         else if (keyword(i).eq.'cvs') then
            iscvs=.true.

         else if (keyword(i).eq.'energy_only') then
            energyonly=.true.

         else if (keyword(i).eq.'fakeip') then
            lfakeip=.true.

         else if (keyword(i).eq.'motype') then
            if (keyword(i+1).eq.'=') then
               i=i+2
               read(keyword(i),'(a)') motype
            else
               goto 100
            endif

         else if (keyword(i).eq.'davidson_section') then
            ldav=.true.
15          continue
            call rdinp(iin)
            if (keyword(1).ne.'end-davidson_section') goto 15
            i=inkw

         else if (keyword(i).eq.'lanczos_section') then
            llanc=.true.
20          continue
            call rdinp(iin)
            if (keyword(1).ne.'end-lanczos_section') goto 20
            i=inkw

         else if (keyword(i).eq.'no_tdm') then
            ltdm_gs2i=.false.

           else
              ! Exit if the keyword is not recognised
              errmsg='Unknown keyword: '//trim(keyword(i))
              call error_control
              STOP
         endif

           ! If there are more keywords to be read on the current line,
           ! then read them, else read the next line
           if (i.lt.inkw) then
              goto 10
           else
              goto 5
           endif
           
           ! Exit if a required argument has not been given with a keyword
100        continue
           errmsg='No argument given with the keyword '//trim(keyword(i))
           call error_control
           STOP

        endif

!-----------------------------------------------------------------------
! Set CVS flags
!-----------------------------------------------------------------------
        if (iscvs) then
           if (energyonly) then
              lcvs=.true.
           else
              lcvsfinal=.true.
           endif
        endif

!-----------------------------------------------------------------------
! If an energy-only calculation has been requested, reset method
! accordingly
!-----------------------------------------------------------------------
        if (energyonly) method=-method

!-----------------------------------------------------------------------
! Read the Davidson section
!-----------------------------------------------------------------------
        if (statenumber.gt.0.and.ldav) call rddavinp

!-----------------------------------------------------------------------
! Read the Lanczos section
!-----------------------------------------------------------------------
        if (llanc) call rdlancinp

!-----------------------------------------------------------------------
! Check that all required information has been given
!-----------------------------------------------------------------------
        call checkinp(ldav,llanc)

      return

    end subroutine read_input

!#######################################################################

    subroutine checkinp(ldav,llanc)

      use parameters
      use iomod

      implicit none

      character(len=120) :: msg
      logical            :: ldav,llanc

!-----------------------------------------------------------------------
! ADC level
!-----------------------------------------------------------------------
      if (method.eq.0) then
         msg='The method has not been been given'
         goto 999
      endif

!-----------------------------------------------------------------------
! Initial state symmetry
!-----------------------------------------------------------------------
      if (nirrep.eq.0) then
         msg='The initial state symmetry has not been given'
         goto 999
      endif

!-----------------------------------------------------------------------
! Dipole operator symmetry
!-----------------------------------------------------------------------
      if (nirrep2.eq.0) then
         msg='The dipole operator symmetry has not been given'
         goto 999
      endif

!-----------------------------------------------------------------------
! Initial state number
!-----------------------------------------------------------------------
      if (statenumber.eq.-1) then
         msg='The initial state number has not been given'
         goto 999
      endif

!-----------------------------------------------------------------------
! Dipole operator component
!-----------------------------------------------------------------------
      if (tranmom2.eq.'') then
         msg='The dipole operator component has not been given'
         goto 999
      endif

!-----------------------------------------------------------------------
! MO storage
!-----------------------------------------------------------------------
      if (motype.ne.'incore'.and.motype.ne.'disk') then
         msg='Unknown MO storage flag - '//trim(motype)
         goto 999
      endif

!-----------------------------------------------------------------------
! Davidson section
!-----------------------------------------------------------------------
      if (statenumber.gt.0.and..not.ldav) then
         msg='The initial state is not the ground state, but &
              Davidson section has been found'
         goto 999
      endif

      if (statenumber.gt.0.) then
         if (davstates.eq.0) then
            msg='The number of Davidson states has not been given'
            goto 999
         else if (maxiter.eq.0) then
            msg='The maximum no. Davidson iterations has not been &
                 given'
            goto 999
         else if (dmain.eq.0) then
            msg='The Davidson block size has not been given'
            goto 999
         endif
      endif

!-----------------------------------------------------------------------
! Lanczos section
!-----------------------------------------------------------------------
      if (.not.llanc) then
         msg='No Lanczos section has been found'
         goto 999
      endif

      if (lmain.eq.0) then
         msg='The Lanczos block size has not been given'
         goto 999
      endif

      if (ncycles.eq.0) then
         msg='The no. Lanczos iterations has not been given'
      endif

      return

999   continue
      errmsg='Problem with the input file: '//trim(msg)
      call error_control

    end subroutine checkinp

!#######################################################################

    subroutine rddavinp

      use parameters
      use parsemod
      use iomod
      
      implicit none

      integer :: i

!-----------------------------------------------------------------------
! Read to the Davidson section
!-----------------------------------------------------------------------
      rewind(iin)

1     call rdinp(iin)
      if (keyword(1).ne.'davidson_section') goto 1

!-----------------------------------------------------------------------
! Read the Davidson parameters
!-----------------------------------------------------------------------
5    call rdinp(iin)
      
      i=0

      if (keyword(1).ne.'end-davidson_section') then

10       continue
         i=i+1

         if (keyword(i).eq.'nstates') then
            if (keyword(i+1).eq.'=') then
               i=i+2
               read(keyword(i),*) davstates
            else
               goto 100
            endif

         else if (keyword(i).eq.'block_size') then
            if (keyword(i+1).eq.'=') then
               i=i+2
               read(keyword(i),*) dmain
            else
               goto 100
            endif

         else if (keyword(i).eq.'tol') then
            if (keyword(i+1).eq.'=') then
               i=i+2
               read(keyword(i),*) davtol
            else
               goto 100
            endif

         else if (keyword(i).eq.'guess') then
            if (keyword(i+1).eq.'=') then
               i=i+2
               if (keyword(i).eq.'adc1') then
                  ladc1guess=.true.
               else
                  errmsg='Unknown keyword: '//trim(keyword(i))
                  call error_control
               endif
            else
               goto 100
            endif

         else if (keyword(i).eq.'maxit') then
            if (keyword(i+1).eq.'=') then
               i=i+2
               read(keyword(i),*) maxiter
            else
               goto 100
            endif

         else
            ! Exit if the keyword is not recognised
            errmsg='Unknown keyword: '//trim(keyword(i))
            call error_control
         endif

         ! If there are more keywords to be read on the current line,
           ! then read them, else read the next line
           if (i.lt.inkw) then
              goto 10
           else
              goto 5
           endif

         ! Exit if a required argument has not been given with a keyword
100      continue
         errmsg='No argument given with the keyword '//trim(keyword(i))
         call error_control

        endif

      return

    end subroutine rddavinp

!#######################################################################

    subroutine rdlancinp

      use parameters
      use parsemod
      use iomod

      implicit none

      integer :: i

!-----------------------------------------------------------------------
! Read to the Lanczos section
!-----------------------------------------------------------------------
      rewind(iin)

1     call rdinp(iin)
      if (keyword(1).ne.'lanczos_section') goto 1

!-----------------------------------------------------------------------
! Read the Lanczos parameters
!-----------------------------------------------------------------------
5    call rdinp(iin)
      
      i=0

      if (keyword(1).ne.'end-lanczos_section') then

10       continue
         i=i+1

         if (keyword(i).eq.'block_size') then
            if (keyword(i+1).eq.'=') then
               i=i+2
               read(keyword(i),*) lmain
            else
               goto 100
            endif

         else if (keyword(i).eq.'iter') then
            if (keyword(i+1).eq.'=') then
               i=i+2
               read(keyword(i),*) ncycles
            else
               goto 100
            endif

         else
            ! Exit if the keyword is not recognised
            errmsg='Unknown keyword: '//trim(keyword(i))
            call error_control
         endif

         ! If there are more keywords to be read on the current line,
         ! then read them, else read the next line
         if (i.lt.inkw) then
            goto 10
         else
            goto 5
         endif
         
         ! Exit if a required argument has not been given with a keyword
100      continue
         errmsg='No argument given with the keyword '//trim(keyword(i))
         call error_control

        endif

      return

    end subroutine rdlancinp

!#######################################################################

  end module rdinput