PRO read_write_GLM, yyyy, mm, dd, jday, utc_hhmm, satnumber, indir 
;---------------------------------------------------------------------------
; IDL code for reading GLM Level-2 nc data and writing out txt file per min
; Created by Yoo-Jeong.Noh@colostate.edu 
; using Steve Miller's original idl read code (26 Feb 2018)
; Several more updates by yjnoh on 20220517 for GOES18 and 20240923 for GOES19
; It runs as part of run_goes_glm_extract.sh through crontab every min.
;---------------------------------------------------------------------------

;choose file and variable (we use L2 group energy and count through pre-exam at CIA)
gtype = 'group'
satnumber = string(satnumber,format='(I2.2)')
sat_fullname = 'goes'+(satnumber)
sat_name = 'G'+(satnumber)
satdirname = 'GLM'+(satnumber)

yyyy = string(yyyy,format='(I4.4)')
jday = string(jday,format='(I3.3)')
mm   = string(mm,format='(I2.2)')
dd   = string(dd,format='(I2.2)')
utc_hhmm = string(utc_hhmm,format='(I4.4)')
;
indir = string(indir)
outdir = 'txtindir/'+satdirname+'/'

glm_search_string = 'OR_GLM-L2-LCFA_'+sat_name+'_s'+yyyy+jday+utc_hhmm+'*.nc'
filenames = FILE_SEARCH(indir, glm_search_string, count=nglm_files)

print, indir
print, glm_search_string
print, nglm_files


FOR ifile = 0, nglm_files-1 DO BEGIN
;---------------------------------------------
; Read each NetCDF file

 filename = filenames(ifile)
; print,filename

 a1=strpos(filename,'_s')
 a2=strpos(filename,'_e')
 str_gstime = strmid(filename,a1+9,7)
 str_getime = strmid(filename,a2+9,7)

 outfile = outdir+'GLM_'+sat_name+'_'+ yyyy+jday+'_s'+str_gstime+'_e'+str_getime

; Get netCDF ID
 ncID = NCDF_OPEN(filename,/NOWRITE)
 contents_loc = NCDF_INQUIRE(ncID)

;*****
; LAT (degrees)
; event_lat_varID = NCDF_VARID(ncID,'event_lat')
; NCDF_VARGET,ncID,event_lat_varID,event_lat
; event_lat_info = NCDF_VARINQ(ncID,event_lat_varID)
; event_lat_att4 = NCDF_ATTNAME(ncID,event_lat_varID,3)
; NCDF_ATTGET,ncID,event_lat_varID,event_lat_att4,scale_factor
; event_lat_att5 = NCDF_ATTNAME(ncID,event_lat_varID,4)
; NCDF_ATTGET,ncID,event_lat_varID,event_lat_att5,add_offset
; event_lat = uint(event_lat)*scale_factor + add_offset

; flash_lat_varID = NCDF_VARID(ncID,'flash_lat')
; NCDF_VARGET,ncID,flash_lat_varID,flash_lat


 group_lat_varID = NCDF_VARID(ncID,'group_lat')
 NCDF_VARGET,ncID,group_lat_varID,group_lat
;*****

;*****
; LON (degrees)
; varID = NCDF_VARID(ncID,'event_lon')
; NCDF_VARGET,ncID,varID,event_lon
; event_lon_info = NCDF_VARINQ(ncID,varID)
; event_lon_att4 = NCDF_ATTNAME(ncID,varID,3)
; NCDF_ATTGET,ncID,varID,event_lon_att4,scale_factor
; event_lon_att5 = NCDF_ATTNAME(ncID,varID,4)
; NCDF_ATTGET,ncID,varID,event_lon_att5,add_offset
; event_lon = uint(event_lon)*scale_factor + add_offset

; flash_lon_varID = NCDF_VARID(ncID,'flash_lon')
; NCDF_VARGET,ncID,flash_lon_varID,flash_lon

 group_lon_varID = NCDF_VARID(ncID,'group_lon')
 NCDF_VARGET,ncID,group_lon_varID,group_lon
;*****

;*****
; GROUP AREA - note the unit changed from (km^2) to (m^2) from 20190129 
 group_count_varID = NCDF_VARID(ncID,'group_count')
 NCDF_VARGET,ncID,group_count_varID,group_count
;
 group_area_varID = NCDF_VARID(ncID,'group_area')
 NCDF_VARGET,ncID,group_area_varID,group_area
 group_area_att5 = NCDF_ATTNAME(ncID,group_area_varID,4)
 NCDF_ATTGET,ncID,group_area_varID,group_area_att5,scale_factor
 group_area_att6 = NCDF_ATTNAME(ncID,group_area_varID,5)
 NCDF_ATTGET,ncID,group_area_varID,group_area_att6,add_offset
 group_area = uint(group_area)*scale_factor + add_offset
;*****

;*****
; GROUP ENERGY (J)
 group_energy_varID = NCDF_VARID(ncID,'group_energy')
 NCDF_VARGET,ncID,group_energy_varID,group_energy
 group_energy_att6 = NCDF_ATTNAME(ncID,group_energy_varID,5)
 NCDF_ATTGET,ncID,group_energy_varID,group_energy_att6,scale_factor
 group_energy_att7 = NCDF_ATTNAME(ncID,group_energy_varID,6)
 NCDF_ATTGET,ncID,group_energy_varID,group_energy_att7,add_offset
 group_energy = uint(group_energy)*scale_factor + add_offset

; Quality Flags (0 = ok, probably 3 for KOMODOS)
 group_quality_flagID = NCDF_VARID(ncID,'group_quality_flag')
 NCDF_VARGET,ncID,group_quality_flagID,group_quality_flag

;*****

;Close netCDF file
 NCDF_CLOSE,ncID


;---------------------------------------------
; Write out the ascii files

sz = group_count

; Skip error data
;valid_p = WHERE( group_energy gt 0.0 and group_energy lt 1.E-11, valid_p0)
valid_p = WHERE( group_energy gt 0.0 and group_energy lt 1.E-11 and group_quality_flag eq 0, valid_p0)

IF( valid_p0 gt 0 ) THEN BEGIN
 group_lat = group_lat(valid_p)
 group_lon = group_lon(valid_p)
 group_area   = group_area(valid_p)
 group_energy = group_energy(valid_p)
 sz = n_elements(group_lat)
ENDIF
;

;Group Locations (lat/lon), area, and energy
;sz = size(group_lat,/dimension)
openw,1,outfile+'.'+gtype+'.txt'
  printf,1,sz
for i = 0,sz(0)-1 do begin
  printf,1,group_lat(i),group_lon(i), group_area(i), group_energy(i)
 endfor ;i
close,1
;


;---------------------------------------------

ENDFOR; ifile

;---------------------------------------------

stop
end

