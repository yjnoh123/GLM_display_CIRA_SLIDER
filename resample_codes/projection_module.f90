module projection_module

    implicit none
    private

    ! public methods
    public read_projection

    ! public data
    public shgt
    public requ
    public rpol
    public lon0
    public xscl
    public xoff
    public xdim
    public yscl
    public yoff
    public ydim

    real(8), save :: shgt
    real(8), save :: requ
    real(8), save :: rpol
    real(8), save :: lon0
    real(8), save :: xscl
    real(8), save :: xoff
    integer(4), save :: xdim
    real(8), save :: yscl
    real(8), save :: yoff
    integer(4), save :: ydim

    character(4) :: vname

    integer(4), parameter :: unit=9

    contains

        subroutine read_projection(filename,success)

            character(*), intent(in) :: filename
            logical(4), intent(out) :: success

            logical(4) :: exist, opened

            success = .false.

            inquire(file=filename,exist=exist)
            if (.not.exist) then
                print*,'file not found: '//trim(filename)
                return
            endif

            inquire(unit=unit,opened=opened)
            if (opened) then
                print*, 'error, unit already opened in projection_module'
                return
            endif

            open(unit=unit,file=filename,status='old')

            read(unit,*,err=999) vname, shgt
            if (vname.ne.'shgt') return

            read(unit,*,err=999) vname, requ
            if (vname.ne.'requ') return

            read(unit,*,err=999) vname, rpol
            if (vname.ne.'rpol') return

            read(unit,*,err=999) vname, lon0
            if (vname.ne.'lon0') return

            read(unit,*,err=999) vname, xscl
            if (vname.ne.'xscl') return

            read(unit,*,err=999) vname, xoff
            if (vname.ne.'xoff') return

            read(unit,*,err=999) vname, xdim
            if (vname.ne.'xdim') return

            read(unit,*,err=999) vname, yscl
            if (vname.ne.'yscl') return

            read(unit,*,err=999) vname, yoff
            if (vname.ne.'yoff') return

            read(unit,*,err=999) vname, ydim
            if (vname.ne.'ydim') return

!            print*,'shgt=',shgt
!            print*,'requ=',requ
!            print*,'rpol=',rpol
!            print*,'lon0=',lon0
!            print*,'xscl=',xscl
!            print*,'xoff=',xoff
!            print*,'xdim=',xdim
!            print*,'yscl=',yscl
!            print*,'yoff=',yoff
!            print*,'ydim=',ydim

            close(unit)

            success = .true.

            999 return

        end subroutine read_projection

end module projection_module
