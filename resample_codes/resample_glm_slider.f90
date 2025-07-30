INCLUDE 'projection_module.f90'
INCLUDE 'goes_module.f90'
INCLUDE 'time87.f90'

!------------------------------------------------------------------
PROGRAM MAIN

USE goes_module
USE time87

IMPLICIT NONE
!------------------------------------------------------------------
! Modified by Yoo-Jeong.Noh in March 2018 for CIRA SLIDER GLM DISPLY,
!  based on Kyle's original code, and again changed the effective area (2024)
!  add 'workdir' for gitlab release by ynoh (20241016)
! > ifort resample_glm_slider.f90 -o resample_glm_slider.exe (OR)
! > gfortran resample_glm_slider.f90 -o resample_glm_slider.exe
! > resample_glm_slider.exe gtype filelist projfile stime etime sector txtindir
!------------------------------------------------------------------

! command line arguments:
character(5) :: gtype  !flash,group,event
character(5) :: sector  !RadC, RadF, RadM1, or RadM2
character(202) :: outfile
character(200) :: filelist
character(200) :: projfile
character(14) :: stime  !YYYYmmddHHMMSS
character(14) :: etime  !YYYYmmddHHMMSS
integer(4) :: arglen
integer(4) :: syear,smonth,sday,shour,sminute,ssecond
integer(4) :: eyear,emonth,eday,ehour,eminute,esecond
character(80), parameter :: time_format = '(i4.4,5(i2.2))'
!character(5),  parameter :: dirname = 'GLM19'
character(200) :: txtindir

integer(4) :: stime87,etime87,gtime87
logical(4) :: success
real(4), allocatable :: esum(:,:)
real(4), allocatable :: nsum(:,:)
real(4), allocatable :: nsum_cent(:,:)
integer(4), parameter :: flunit=9
integer(4) :: flios
integer(4) :: nfile, ndata
integer(4), parameter :: glmunit=8
character(200) :: glmfile
integer(4) :: glmios

! GLM data:
integer(4) :: gyear, gmonth, gday, ghour, gminute, gsecond
integer(4) :: gcount, ngrid
real(4) :: glat, glon, garea, gradius
!integer(4) :: gquality

real(8) :: alon,alat, genergy
real(8) :: xx,yy
integer(4) :: ilon,ilat
integer(4) :: klon,klat

!real(4), parameter :: missing_value = -1.E30  !for output files
real(4), parameter :: missing_value = -999.0  !for output files
integer(4), parameter :: outunit=7

!-------------------------------------
! For hole filling with area (ynoh)
real(8) :: xx1,yy1,alon2,alat2, dist, genergy_near
real(8), parameter :: dtor = 0.0174533

!---------------------------------------------------------------

CALL get_command_argument(1,gtype,arglen)
IF (arglen.ne.5) stop 'error, you must supply gtype as arg 1'

CALL get_command_argument(2,filelist,arglen)
IF (arglen.le.0) stop 'error, you must supply filelist as arg 2'

! e.g., ABI_RadC_proj.txt
CALL get_command_argument(3,projfile,arglen)
IF (arglen.le.0) stop 'error, you must supply projfile as arg 3'

CALL get_command_argument(4,stime,arglen)
IF (arglen.ne.14) stop 'error, you must supply stime as arg 4'

CALL get_command_argument(5,etime,arglen)
IF (arglen.ne.14) stop 'error, you must supply etime as arg 5'

CALL get_command_argument(6,sector,arglen)
!IF (arglen.ne.4) stop 'error, you must supply sector as arg 6'
IF (arglen.gt.5) stop 'error, you must supply sector as arg 6' !for meso

! Add for input and output by ynoh (20241016)
CALL get_command_argument(7,txtindir,arglen)
IF (arglen.gt.200) stop 'error, you must supply txtindir with a shorter length as arg 7'

READ(stime,time_format) syear,smonth,sday,shour,sminute,ssecond
READ(etime,time_format) eyear,emonth,eday,ehour,eminute,esecond

!---------------------------------------------------------------

CALL fd_time87(syear,smonth,sday,shour,sminute,ssecond, stime87)
CALL fd_time87(eyear,emonth,eday,ehour,eminute,esecond, etime87)

!!time check
!CALL fd_time87(gyear,gmonth,gday,ghour,gminute,gsecond, gtime87)

!IF (gtime87.lt.stime87 .AND. gtime87.gt.etime87) THEN
!---------------------------------------------------------------

CALL set_projection(projfile,success)
IF (.not.success) stop 'error setting projection'

ALLOCATE(nsum(xdim,ydim))
ALLOCATE(esum(xdim,ydim))
ALLOCATE(nsum_cent(xdim,ydim))

nsum_cent = 0.0
nsum = 0.0
esum = 0.0

nfile = 0
ndata = 0

ngrid = 45
IF (trim(sector).eq.'RadM1' .OR. trim(sector).eq.'RadM2') ngrid = 65
!---------------------------------------------------------------
! ynoh added convert='little_endian' (20240429)
!outfile=trim(dirname)//'/txtindir/'//trim(sector)//'/'//stime//'.glm_resample.bin'
outfile=trim(txtindir)//'/'//trim(sector)//'/'//stime//'.glm_resample.bin'
open(unit=outunit,file=outfile,status='replace',form='unformatted',access='stream',convert='little_endian')


OPEN(unit=flunit,file=filelist,status='old')
DO
    READ(flunit,*,iostat=flios) glmfile
    IF (flios.ne.0) exit
    nfile = nfile + 1

!    OPEN(unit=glmunit,file='/home/ynoh/'//trim(dirname)//'/run_SLIDER/txtindir/'//glmfile,status='old')
    OPEN(unit=glmunit,file=trim(txtindir)//'/'//glmfile,status='old')
        READ(glmunit,*,iostat=glmios) gcount
    DO

        READ(glmunit,*,iostat=glmios) glat,glon,garea,genergy
        ndata = ndata + 1
        IF (glmios.ne.0) exit

        alon = dble(glon)
        alat = dble(glat)

        CALL get_xy_from_lonlat(alon,alat,xx,yy,success)
        IF (.not.success) cycle
        CALL get_ij_from_xy(xx,yy,ilon,ilat)

        if (ilon.lt.2) cycle
        if (ilon.gt.xdim-1) cycle
        if (ilat.lt.2) cycle
        if (ilat.gt.ydim-1) cycle

!---------------------------------------------------------------
! Add the area info for hole filling (by ynoh)
! Calculate dist for some nearby pixels
! dist=arccos(sin(alat*dtor)*sin(alat2*dtor)+cos(alat*dtor)*cos(alat2*dtor)*cos((alon-alon2)*dtor))
! Note the area unit changed from (km^2) to (m^2) from 20190129
!---------------------------------------------------------------
! Add centroid numbers only, no effective area (ynoh 20240426)
        nsum_cent(ilon,ilat) = nsum_cent(ilon,ilat) + 1

!        gradius = SQRT(garea)*0.001  ! [km] ! Effective area as a square
        gradius = SQRT(garea/3.141592)*0.001  ! a narrow circle [km]  ! ynoh (20231207)
        genergy_near = 0.0

        DO klat = ilat- ngrid, ilat+ ngrid
            DO klon = ilon- ngrid, ilon+ ngrid
           

                !space check
                IF (klon.lt.1) cycle
                IF (klon.gt.xdim) cycle
                IF (klat.lt.1) cycle
                IF (klat.gt.ydim) cycle

               call get_xy_from_ij(klon,klat,xx1,yy1)
               call get_lonlat_from_xy(xx1,yy1,alon2,alat2)

               dist=6372.*acos(sin(alat*dtor)*sin(alat2*dtor)+cos(alat*dtor)*cos(alat2*dtor)*cos((alon-alon2)*dtor))

               IF (dist.le.gradius) then
                nsum(klon,klat) = nsum(klon,klat) + 1
!                esum(klon,klat) = esum(klon,klat) + genergy
! Inverse-distance Weighting on the closest pixels (test by ynoh for energy)
!                esum(klon,klat) = esum(klon,klat) + dble(genergy/garea)/dist
!                esum(klon,klat) = esum(klon,klat) + genergy/dist
!by 20190226                esum(klon,klat) = esum(klon,klat) + genergy*0.05/dist**2.
                esum(klon,klat) = esum(klon,klat) + genergy*0.03/dist**2.
! Take a half of energy and divide it into 100 grid points, and spread with IDW
                genergy_near = genergy_near + genergy*0.03/dist**2.
               ENDIF
            

           ENDDO !klon
       ENDDO !klat
!---------------------
! More weighting on the closest pixels (test by ynoh for energy)

       esum(ilon,ilat) = esum(ilon,ilat) + genergy - MINVAL([genergy,genergy_near])                           

! If too much energy distributed, remove extra from the central area
! (Want to keep energy conservation, but some artifacts occur...)
!    if(genergy-genergy_near.lt.0. .AND. abs(genergy_near-genergy)/genergy*100..gt.100.) then                                                      
!        esum(ilon-1:ilon+1,ilat-1:ilat+1) = esum(ilon-1:ilon+1,ilat-1:ilat+1)/ &   
!                                            (abs(genergy_near-genergy)/genergy)
!    endif

!---------------------------------------------------------------

    ENDDO !glmfile

ENDDO !filelist
!ENDIF ! timecheck
CLOSE(flunit)

!---------------------------------------------------------------

WRITE(outunit) nsum
WRITE(outunit) esum
!WRITE(outunit) nsum_cent
CLOSE(outunit)

!
DEALLOCATE(nsum)
DEALLOCATE(esum)
DEALLOCATE(nsum_cent)

!
END PROGRAM MAIN
