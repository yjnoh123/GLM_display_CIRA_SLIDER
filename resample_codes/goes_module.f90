! reference: Produce Definition and User's Guid (PUG)
! Volume 5: Level 2+ Products
! DCN 7035538, Revsion E

module goes_module

    use projection_module

    implicit none
    private

    ! public methods
    public set_projection
    public get_goes_latlon
    public get_xy_from_lonlat
    public get_lonlat_from_xy
    public get_xy_from_ij
    public get_ij_from_xy

    ! public data (from projection_module)
    public xdim
    public ydim

    ! mathematical constants:
    real(8), parameter :: dtor = 0.0174533
    real(8), parameter :: pi = 3.1415926536

    real(8), save :: bigh
    real(8), save :: rrat
    real(8), save :: eccen

    contains

        subroutine set_projection(filename,success)

            character(*), intent(in) :: filename
            logical(4), intent(out) :: success

            call read_projection(filename,success)
            if (.not.success) return

            bigh = requ + shgt
            rrat = (requ*requ)/(rpol*rpol)
            eccen = sqrt((requ*requ - rpol*rpol)/(requ*requ))

        end subroutine set_projection

        subroutine get_goes_latlon(lat,lon)

            real(4), allocatable, intent(out) :: lat(:,:)
            real(4), allocatable, intent(out) :: lon(:,:)

            integer(4) :: i,j
            real(8) :: x,y
            real(8) :: alat,alon

            if (allocated(lat)) deallocate(lat)
            if (allocated(lon)) deallocate(lon)
            allocate(lat(xdim,ydim))
            allocate(lon(xdim,ydim))

            do j = 1, ydim
                do i = 1, xdim

                    call get_xy_from_ij(i,j,x,y)
                    call get_lonlat_from_xy(x,y,alon,alat)

                    lat(i,j) = alat
                    lon(i,j) = alon

                enddo !i
            enddo !j

        end subroutine get_goes_latlon

        subroutine get_ij_from_xy(x,y,i,j)

            real(8), intent(in) :: x
            real(8), intent(in) :: y
            integer(4), intent(out) :: i
            integer(4), intent(out) :: j

            i = 1+nint((x-xoff)/xscl)
            j = 1+nint((y-yoff)/yscl)

        end subroutine get_ij_from_xy

        subroutine get_xy_from_ij(i,j,x,y)

            integer(4), intent(in) :: i
            integer(4), intent(in) :: j
            real(8), intent(out) :: x
            real(8), intent(out) :: y

            x = (i-1)*xscl + xoff
            y = (j-1)*yscl + yoff

        end subroutine get_xy_from_ij


        subroutine get_xy_from_lonlat(lon,lat,x,y,success)

            real(8), intent(in) :: lon  !deg
            real(8), intent(in) :: lat  !deg
            real(8), intent(out) :: x  !rad
            real(8), intent(out) :: y  !rad
            logical(4), intent(out) :: success

            real(8) :: phic, rc, sx, sy, sz
            real(8) :: aterm, bterm

            success = .false.  !lon,lat not visible from satellite
            x = -1.E30
            y = -1.E30

            phic = atan(tan(lat*dtor)/rrat)
            rc = rpol / sqrt( 1.0 - eccen*eccen*cos(phic)*cos(phic) )

            sx = bigh - (rc * cos(phic) * cos((lon-lon0)*dtor))
            sy = -rc * cos(phic) * sin((lon-lon0)*dtor)
            sz = rc * sin(phic)

!            print*,'phic=',phic
!            print*,'rc=',rc
!            print*,'sx=',sx
!            print*,'sy=',sy
!            print*,'sz=',sz

            aterm = bigh*(bigh-sx)
            bterm = sy*sy + rrat*sz*sz

            if (aterm.lt.bterm) then
                return
            endif

            y = atan(sz/sx)
            x = asin(-sy/sqrt(sx*sx + sy*sy + sz*sz))

            success = .true.

        end subroutine get_xy_from_lonlat

        subroutine get_lonlat_from_xy(x,y,lon,lat)

            real(8), intent(in) :: x   ! rad
            real(8), intent(in) :: y   ! rad
            real(8), intent(out) :: lon   ! deg
            real(8), intent(out) :: lat   ! deg

            real(8) :: a, b, c, rs, sx, sy, sz

            a = sin(x)**2 + (cos(x)**2)*( cos(y)**2 + rrat*(sin(y)**2) )
            b = -2*bigh*cos(x)*cos(y)
            c = bigh**2 - requ**2
            rs = (-b - sqrt(b*b - 4.*a*c))/(2.*a)
            sx = rs * cos(x) * cos(y)
            sy = -rs * sin(x)
            sz = rs * cos(x) * sin(y)

!            print*,'a=',a
!            print*,'b=',b
!            print*,'c=',c
!            print*,'rs=',rs
!            print*,'sx=',sx
!            print*,'sy=',sy
!            print*,'sz=',sz

            lat = (atan(rrat*sz/sqrt((bigh-sx)**2 + sy**2)))/dtor
            lon = (lon0*dtor - atan(sy/(bigh-sx)))/dtor

        end subroutine get_lonlat_from_xy

end module goes_module
