module time87

implicit none
private

public fd_time87

integer(4) :: idayfx(12,2)
data idayfx/1,32,60,91,121,152,182,213,244,274,305,335, &
            1,32,61,92,122,153,183,214,245,275,306,336/

contains

    subroutine fd_time87(lyear,imon,idaymo,ihour,imin,isec, itime87)                  

        integer(4), intent(in) :: lyear
        integer(4), intent(in) :: imon
        integer(4), intent(in) :: idaymo
        integer(4), intent(in) :: ihour
        integer(4), intent(in) :: imin
        integer(4), intent(in) :: isec
        integer(4), intent(out) :: itime87

        integer(4) :: ileap, idayjl, isecdy

        if (lyear.lt.1987) stop 'lyear error'
        if ((imon.lt.1).or.(imon.gt.12)) stop 'imon error'
        if ((idaymo.lt.1).or.(idaymo.gt.31)) stop 'idaymo error'
        if ((ihour.lt.0).or.(ihour.gt.24)) stop 'ihour error'
        if ((imin.lt.0).or.(imin.gt.60)) stop 'imin error'
        if ((isec.lt.0).or.(isec.gt.60)) stop 'isec error'

        ileap=1
        if(lyear.eq.4*int(lyear/4)) ileap=2

        idayjl=idayfx(imon,ileap)-1+idaymo

        isecdy= 3600*ihour + 60*imin + isec

        itime87=isecdy + 86400*(idayjl-1) +  31536000*(lyear-1987) + 86400*int((lyear-1985)/4)

    end subroutine fd_time87

end module time87
