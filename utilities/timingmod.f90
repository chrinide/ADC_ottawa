  module timingmod

    implicit none

    save

    real*8 :: t1,t2,dt

    contains

!#######################################################################

      subroutine get_time(it)

        use parameters, only: ilog

        implicit none

        integer :: it

        if (it.eq.1) then
           call cpu_time(t1)
        else if (it.eq.2) then
           call cpu_time(t2)
           dt=t2-t1
        else
           write(ilog,'(/,2x,a,/)') 'Error in get_time'
           STOP
        endif

        return
        
      end subroutine get_time

!#######################################################################    

  end module timingmod