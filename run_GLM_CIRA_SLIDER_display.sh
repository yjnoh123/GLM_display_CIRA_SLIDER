#!/bin/bash
############################################################################
# Run GLM codes for L2 LCFA data and plot group energy/counts with the background transparency 
# for CIRA's SLIDER display (RadC or RadF)
# Yoo-Jeong.Noh@colostate.edu (CIRA/CSU, 07 March 2018)
# Yoo-Jeong.Noh@colostate.edu (CIRA/CSU, 02 Oct 2024) for GOES-19
# Yoo-Jeong.Noh@colostate.edu (CIRA/CSU, 16 Oct 2024) for gitlab (conus/fulldisk)
# Yoo-Jeong.Noh@colostate.edu (CIRA/CSU, 20 Jul 2025) including python codes converted from the original IDL codes
# Note: It is designed for CIRA's SLIDER real-time display, but for your test, sample data sets are in ./data/
############################################################################
# GOES-R ABI/GLM sectors: RadF or RadC
# For meso sectors with 30sec ABI scan (usually 1 min but sometimes 30 sec - the code will be added), 
#     accumate two or three GLM 20-sec files for matchup and divided by 2 roughly for energy image disply
gtype='group'
sector='RadC'
if [ ${sector} = 'RadC' ]; then sector_fullname='conus'; fi
if [ ${sector} = 'RadF' ]; then sector_fullname='full_disk'; fi

satnumber=19
satname='goes-'${satnumber}
sat_fullname='goes'${satnumber}
sat_shortname='G'${satnumber}
satdirname='GLM'${satnumber}

# Adjust the realtime cron jub run time considering data ingest latency at CIRA
# and the incoming delay period of ABI
# RadC crontab starts 5 or 6 min after ABI scan
# For RadF, collect GLM data within 10-min for MODE6) window (s_hhmm & e_hhmm) from the crontab starting time
#jdate=$(date +%j -d "6 mins ago")
#if [ ${sector} = 'RadF' ]; then jdate=$(date +%j -d "13 mins ago"); fi

# For the sample test
yyyy=2025
mm=07
dd=29
s_hhmm=1501
jdate=$(date +%j -d "${yyyy}${mm}${dd}")
jdayname=$jdate
yyyymmdd=$yyyy$mm$dd

###################################################################
# Set input/output directories  - Adjust by users
###################################################################

# For the sample test
runrootdir=./

runrootdir=./
satdir=${runrootdir}/${satdirname}
mkdir -p ${satdir}
mkdir -p ${satdir}/txtindir
glmrundir=${satdir}/${sector}
txtindir=${satdir}/txtindir/

# CIRA regular GRB GOES data directory
#abidir=/mnt/grb/${sat_fullname}/${yyyy}/${yyyy}_${mm}_${dd}_${jdayname}/abi/L1b/${sector}/
# For the sample test
abidir=${satdir}/input/

mkdir -p ${glmrundir}
mkdir -p ${txtindir}
mkdir -p ${txtindir}/${sector}
 
#outdir=${glmrundir}'/output/'${yyyy}${jdayname}
outdir=${glmrundir}'/output/'
mkdir -p ${outdir}
chmod uog+rwx ${outdir}

# Check sat geo info for GOES-West or East
# No need to specify for RadC or RadF using fixed navigation info files (ABI_RadC_proj.txt or ABI_RadF_proj.txt)
# but need for RadM1 or M2 moving locations. OR you can direactly read the sub-longitude info from ABI L1b files (any 2km IR Bands)
#lon0=-75. #(GOES-E)
#lon0=-137. #(GOES-W)
# GOES center longitude location (before drifting to the operational position)
#lon0=-89.5 #GOES center
projfile=${runrootdir}/'ABI_'${sector}'_proj.txt'
ln -sf ${runrootdir}/ABI_${sector}_proj_G${satnumber}.txt  ${projfile}

# Link a glm limit boundary file for plotting RadF only if you want
#if [ ${satnumber} = '16' ] || [ ${satnumber} = '19' ]; then ln -sf ${runrootdir}/glm_fulldisk_limits_resample_goese.txt ${runrootdir}/glm_fulldisk_limits_resample_goes.txt; fi
#if [ ${satnumber} = '18' ]; then ln -sf ${runrootdir}/glm_fulldisk_limits_resample_goesw.txt ${runrootdir}/glm_fulldisk_limits_resample_goes.txt; fi

###################################################################
# Find the same timestamp with ABI from direct ABI GRB file list
# Set the start & end times  including seconds
###################################################################
# Pick the latest file applicable to either RadF or RadC for ABI-GLM time matchup
abifile=`find ${abidir} -name 'OR_ABI-L1b-'${sector}'-M?C16_*.nc' -type f -exec stat -c '%X %n' {} \; | sort -nr | awk -F'/' 'NR==1 {print $NF}'`
echo $abifile

if [ `ls ${abidir}/${abifile} | wc -l` -ne 0 ]; then
 j=${abifile}
  mode=$(echo ${j} | cut -c 18)
  allstime=$(echo ${j} | cut -f 4 -d '_')
  utctime=$(echo $allstime | cut -c 9-15)
  ahh=$(echo $utctime | cut -c 1-2)
  amm=$(echo $utctime | cut -c 3-4)
  ass=$(echo $utctime | cut -c 5-6)
  echo $ahh $amm $ass
  ss=$ass
else
 echo "No ABI file for GLM timestamp!"
 exit 1
fi

if [ -z ${ss+x} ]; then
 ss=$(cat ${runrootdir}/ss_${sector_fullname}.done | cut -c1-2)
fi
echo $ss > ${runrootdir}/ss_${sector_fullname}.done

s_hhmm=${ahh}${amm}
# For RadC 5 min scan
e_hhmm=$(date +%H%M -d "${yyyymmdd} ${s_hhmm} 5 mins")
  yyyymmdd2=$(date +%Y%m%d -d "${yyyymmdd} ${s_hhmm} 5 mins")
  jdayname2=$(date +%j -d "${yyyymmdd} ${s_hhmm} 5 mins")

# Only for RadF (now all 10-min mode 6. no more 15-min mode 5)
if [ ${sector} = 'RadF' ]; then
  e_hhmm=$(date +%H%M -d "${yyyymmdd} ${s_hhmm} 10 mins")
  yyyymmdd2=$(date +%Y%m%d -d "${yyyymmdd} ${s_hhmm} 10 mins")
  jdayname2=$(date +%j -d "${yyyymmdd} ${s_hhmm} 10 mins")
fi

jdate2=${jdayname2}
stime=${s_hhmm}$ss
etime=${e_hhmm}$ss

echo 'ABI start end times:' $stime $etime ${sector}
###################################################################
# Run GLM codes (f90 plus idl or python) within a time window 
# GLM txt Files converted on goest machine after transfered from grb disk every minute
###################################################################

gfiles_all0=dmy.txt
if [ ${s_hhmm} -eq '0000' ]; then
  jdayname0=$(date +%j -d "${yyyymmdd} ${s_hhmm} 1 day ago")
  gfiles_all0=GLM_${sat_shortname}_${yyyy}${jdayname0}'_s235*.'${gtype}.txt
fi

gfiles_all2=GLM_${sat_shortname}_${yyyy}${jdayname2}'_s*.'${gtype}.txt
gfiles_all=dmy.txt
if [ ${jdate} -ne ${jdate2} ]; then
gfiles_all=GLM_${sat_shortname}_${yyyy}${jdayname}'_s*.'${gtype}.txt
fi

gfilelist=${txtindir}/filelist_${sector}
rm -rf $gfilelist

t1=$(date -d "${yyyymmdd} ${s_hhmm}" +%s)
t2=$(date -d "${yyyymmdd2} ${e_hhmm}" +%s)

# Only for RadF  (GLM is a bit late)
# - 2:40-3min, Modified by ynoh (20180425) to match the SLIDER tilting time with Geo 
if [ ${sector} = 'RadF' ]; then
 t1=`expr ${t1} - 180`
 t2=`expr ${t2} - 180`
fi

if [ `ls ${txtindir}/${gfiles_all0} ${txtindir}/${gfiles_all} ${txtindir}/${gfiles_all2}| wc -l` -ne 0 ]; then

for i in `ls -a ${txtindir}/${gfiles_all} ${txtindir}/${gfiles_all2} ${txtindir}/${gfiles_all0}`
do

gyyyyjday_tmp=$(echo ${i##*/} | cut -f 3 -d '_')
yyyy_tmp=$(echo ${gyyyyjday_tmp} | cut -c1-4)
jday_tmp=$(echo ${gyyyyjday_tmp} | cut -c5-7)
yyyymmdd_tmp=$(date -d "${yyyy_tmp}-01-01 +$(( ${jday_tmp} - 1 ))days" +%Y%m%d)

gstime_tmp=$(echo ${i##*/} | cut -f 4 -d '_')
gstime=$(echo ${gstime_tmp} | cut -c2-7)
gs_hh=$(echo ${gstime_tmp} | cut -c2-3)
gs_mm=$(echo ${gstime_tmp} | cut -c4-5)
gs_ss=$(echo ${gstime_tmp} | cut -c6-7)

getime_tmp=$(echo ${i##*/} | cut -f 5 -d '_')
getime=$(echo ${getime_tmp} | cut -c2-7)
ge_hh=$(echo ${getime_tmp} | cut -c2-3)
ge_mm=$(echo ${getime_tmp} | cut -c4-5)
ge_ss=$(echo ${getime_tmp} | cut -c6-7)

gst_str=$(date -d "${yyyymmdd_tmp} ${gs_hh}:${gs_mm}:${gs_ss}")
gstsec=$(date -d "${gst_str}" +%s)
get_str=$(date -d "${yyyymmdd_tmp} ${ge_hh}:${ge_mm}:${ge_ss}")
getsec=$(date -d "${get_str}" +%s)

if [ ${gs_hh} -eq '23' ] && [ ${ge_hh} -eq '00' ]; then
get_str=$(date -d "${yyyymmdd2} ${ge_hh}:${ge_mm}:${ge_ss} 1 day")
fi

gstsec=$(date -d "${gst_str}" +%s)
getsec=$(date -d "${get_str}" +%s)

gstsec=`expr ${gstsec} + 0`
getsec=`expr ${getsec} + 0`

if [ $gstsec -ge $t1 ] && [ $getsec -le $t2 ] ; then 
echo ${i##*/}
ls ${txtindir}/${i##*/} | xargs -n 1 basename >> ${gfilelist}
fi

done

fi

###################################################################
# Fortran codes for each GLM centroid reprojection onto ABI sectors 
#  and redistribution of GLM energy values over each effective area 
# Process each GLM txt file (fixed sat projection only for RadF and RadC)
###################################################################

resample_file=${txtindir}/${sector}/${yyyymmdd}${stime}'.glm_resample.bin'

echo 'Run GLM resampling for' ${satdirname} ${sector} ${yyyy}${mm}${dd}_${s_hhmm}${ss}
${runrootdir}/resample_glm_slider.exe $gtype $gfilelist $projfile ${yyyymmdd}${stime} ${yyyymmdd}${etime} ${sector} ${txtindir}


###################################################################
# Run IDL or Python code for final plotting (Change accordingly per user' system below)
# Note the color bar particularly for group area counts may not be the same in IDL and Python
# (similar rainbow colors but the sample color bar from IDL color table =34 rainbow)
###################################################################

echo 'Final Image fie (png) plot...'

# IDL
#/usr/local/bin/idl<<EOF
#.run ${runrootdir}/plot_GLM.pro
#sample_plot_GLM_Noh, ${yyyy}, ${mm}, ${dd}, ${jdayname}, ${stime}, '${resample_file}', '${satdirname}', '${sector}'
#EOF

python sample_plot_GLM_Noh.py ${yyyy} ${mm} ${dd} ${jdayname} ${stime} ${resample_file} ${satdirname} ${sector}
