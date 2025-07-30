PRO sample_plot_GLM_Noh, yyyy, month, day, jday, utc_time, input, satdirname, domain
;---------------------------------------------------------------------------------------
; Read GOES-R GLM Level-2 LCFA 'Group' data fields and Plot GLM over ABI sectors
; The original data is, for instance, OR_GLM-L2-LCFA_G18_*.nc
; (Converted into text data output through remaping/accumulating already with separate fortran codes)
; Created by ynoh Yoo-Jeong.Noh@colostate.edu (02/27/2018)  
; and modified (20241016) for gitlab release 
;---------------------------------------------------------------------------------------
;
case domain of
   'RadF': begin
	nx = 5424L & ny = 5424L  ; ABI FD
   end
   'RadC': begin
	nx = 2500 & ny = 1500  ; ABI CONUS
   end
   'RadM1' OR 'RadM2': begin
	nx = 1000 & ny = 1000  ; ABI Meso 1 or 2
   end
else: STOP
endcase
	
yyyy = string(yyyy,format='(I4.4)')
mm = string(month,format='(I2.2)')
dd = string(day,format='(I2.2)')
jday = string(jday,format='(I3.3)')
utc_time = string(utc_time,format='(I6.6)')  ; ABI FD UTC time
 yyyymmdd = yyyy+mm+dd
;
workdir = '$HOME/glm_codes/'
outdir = workdir+'/'+satdirname+'/'+domain+'/output/'+yyyy+jday+'/'
;------------------------------------------------------------------------------
; (already reprocessed through remaping/accumulating with separate fortran codes)
; csum: frequency numbers hit by group_area - accumulated for ABI scan time per each sector
; esum: group_energy - redistributed/accumulated for ABI scan time per each sector
  csum = fltarr(nx,ny)
  esum = fltarr(nx,ny) 

; Read the input bin file
 OPENR, 1, input
   READU,1,csum  ; count
   READU,1,esum  ; energy
 CLOSE,1

 GLM_count = csum
 GLM_energy = esum  
;------------------------------------------------------------------------------
; Plotting with transparency to make the figures overlaying on ABI GeoColor or other imagery
;------------------------------------------------------------------------------
 xp=nx & yp=ny
set_plot, 'Z', /copy
device, set_resolution=[xp,yp], Z_buffer = 0, Decomposed = 0, set_pixel_depth=24, $
 set_character_size=[15, 15]
Erase
;
;------------------------------------
For ifig=0, 1 Do Begin

  IF(ifig eq 0) THEN BEGIN
     output= GLM_count   ; [unitless]
     minv = 1
     maxv = 2.56
     varname = 'group_counts'
; Set transparency at the begining. Range is 0 (completely transparent)to 255 (completely opaque).
; Note that the transparency thresholds different for count and energy
      transparency_min = 100 
      edge_thresh_value = 50

  ENDIF
  IF(ifig eq 1) THEN BEGIN
     output= GLM_energy   ; [J]
     output= output * 1.E+12  ; from [J] to [pJ]

; Just for better visual plot over meso sectors
    IF(domain eq 'RadM1' or domain eq 'RadM2') THEN BEGIN
         no_glm_p = where(GLM_count le 1)
         output(no_glm_p) = output(no_glm_p) * 0.5
    ENDIF

    IF(domain eq 'RadC') THEN output= output /5. ; from [J] to [pJ/min], (60 pJ/min= 1 pW if needed)
    IF(domain eq 'RadF') THEN output= output /10. ; from [J] to [pJ]/min

; Supress error data (but don't want to miss little lights)
      invalid_p = where(output lt 0., invalid_p0)
      if(invalid_p0 gt 0) then output(invalid_p) = 0.0

; Please adjust min & max as needed. The values below are just from several trial errors/tests.
      minv = -6.0 & maxv = 0.6 ; for [pJ]/min
     varname = 'group_energy'
; Set transparency at the begining. Range is 0 (completely transparent)to 255 (completely opaque).
; Note that the transparency thresholds different for count and energy
      transparency_min = 2 
      edge_thresh_value = 170  
  ENDIF
;------------------------------------

 output = reverse(output,2)
  tmp = where(output gt 0.)
  tmp_zero = where(output eq 0.,tmp_zero0)
  output(tmp) = Alog10( output(tmp) )  ; just for display

 img=BYTSCL(output,min=minv,max=maxv,top=254,/NaN)
 if(tmp_zero0 gt 0) then img(tmp_zero)=0

;----------------------
ctable = 34   ; rainbow
LoadCT, ctable

if(ctable eq 34) then begin
Gamma_CT, 1.5, /current
 TVLCT, r, g, b, /Get
 r(0)=0 & g(0)=0 & b(0)=0
 TVLCT, r, g, b
endif

if(varname eq 'group_energy') then begin
; Call YJ Noh's modified violet light color table
; See Noh's color generation code in color_tables/modified_violet_blue_ynoh.pro
n_col=256
noh_energy_color_table = workdir+'/color_tables/'+'Noh_violet_glm_energy_rgb.txt'
r=bytarr(n_col)
g=bytarr(n_col)
b=bytarr(n_col)
OPENR, tmpunit, noh_energy_color_table, /GET_LUN
 FOR nn=0, n_col-1 DO BEGIN
   READF,tmpunit, rtmp, gtmp, btmp
   r(nn) = rtmp
   g(nn) = gtmp
   b(nn) = btmp
 ENDFOR
FREE_LUN, tmpunit

 TVLCT, r, g, b

 ; Blur the boundary
 boundary=where(img gt 1 and img lt 50, shadow0)
 if(shadow0 gt 0) then begin
   smoothing=SMOOTH(img, 5, /EDGE_TRUNCATE)
   img(boundary)=smoothing(boundary)
 endif
endif

;-------------------------------
; Add light glow effects around sharp edges

if(varname eq 'group_energy') then begin
 shadow  = where(img gt 25, shadow0)
   s = SIZE(img)
   ncol = s(1)
   index = shadow
   col = index MOD ncol
   row = index / ncol

 if(shadow0 gt 0) then begin
  img_tmp = bytarr(nx,ny)

  for iy=-2, 2 do begin
  for ix=-2, 2 do begin
   img_tmp(col+ix,row+iy) = 12
  endfor
  endfor

  for iy=-1, 1 do begin
  for ix=-1, 1 do begin
   img_tmp(col+ix,row+iy) = fix(img(col,row)*0.7)
  endfor
  endfor

 final_shadow = where(img_tmp gt 1 and img lt 10 and (img_tmp-img) gt 5, final_shadow0)
 if(final_shadow0 gt 0) then img(final_shadow) = fix(( img_tmp(final_shadow)*3.+img(final_shadow)*2. )/5.)

 endif  ; shadow0

endif  ; for group_energy only

;-------------------------------
; Add the resampled GLM limits, just for full disk (The original data from Max Marchand at CIRA, 20190114)
; Link a proper GLM limit info file for GOES-W or GOES-E to 'glm_fulldisk_limits_resample.txt'
IF(domain eq 'RadF') THEN BEGIN
glmlimits_bin = workdir + '/glm_fulldisk_limits_resample_goes.txt'
xlimits=lonarr(10045)
ylimits=lonarr(10045)
 OPENR, dmyunit, glmlimits_bin, /GET_LUN
 FOR kk=0, 10044L DO BEGIN
   READF,dmyunit,xlimits_tmp, ylimits_tmp
   xlimits(kk) = xlimits_tmp
   ylimits(kk) = ylimits_tmp
 ENDFOR
FREE_LUN, dmyunit
img(xlimits,ylimits) = 70B
ENDIF ; RadF
;;-------------------------------

 TV,img
;
;----------------------
;Make black bg transparent
transparentImage = TVRD(true=1)

 image=TVRD(true=1)
 image = Transpose(image, [1,2,0])
 red=image[*,*,0]
 grn=image[*,*,1]
 blu=image[*,*,2]
 targetIndices = Where((red eq 0) and (grn eq 0) and (blu eq 0), count)  ; black gb to transparent
 alpha = BytArr(xp, yp) + 245B   ; Give a bit transparency for all pixels
 IF (count GT 0) THEN alpha[targetIndices] = 0

;
    ; Create a mask to remove lower pixels values from array.
    mask = BYTARR(xp, yp)
;
;    ; For selected pixels, vary transparency gradually
    edge_thresh = edge_thresh_value
    mask = (img LT edge_thresh and img GT 0)
    edges = Where(mask)

; Try gamma for transparency
    transparency = fix( (245.- transparency_min) * ( (img(edges)-3.)/(edge_thresh-3.) )^(0.9) ) + transparency_min
    alpha(edges) = transparency  
;
 transparentImage = [ [[red]], [[grn]], [[blu]], [[alpha]] ]
 transparentImage = Transpose(transparentImage, [2,0,1])
;
;----------------------
; Save as png
 pngfile = outdir + 'cira_glm_l2_'+varname+'_'+ yyyymmdd+utc_time+'.png'
 write_png,pngfile,transparentImage

ENDFOR ; ifig

;------------------------------------------------------------------------------
stop
END

