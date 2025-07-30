#!/bin/bash
############################################################################
# Run GLM IDL code to write out ascii txt files every min using GLM 20-sec L2
# It should come with ${runrootdir}/read_write_GLM.pro
# Yoo-Jeong.Noh@colostate.edu (CIRA/CSU, since 2017)
# Yoo-Jeong.Noh@colostate.edu (CIRA/CSU, 20 July 2025) updated with Python from IDL
# Run this script every minute as below, but you can change for an hour, etc.
# crontab: * * * * * /home/ynoh/glm_codes/run_goes_glm_extract.sh > glm_run.log 2>&1
############################################################################

# Read jdate from the server
# For GOES-R series
satnumber=19
sat_fullname='goes'${satnumber}
satdirname='GLM'${satnumber}

# For a realtime run at CIRA, it should consider about 3 min delay until finishing up L2 data ingest per minute
#jdate=$(date +%j -d "170 seconds ago")
#s_hhmm=$(date +%H%M -d "170 seconds ago")

yyyy=2025
mm=07
dd=29
s_hhmm=1505
jdate=$(date +%j -d "${yyyy}${mm}${dd}")
jdayname=$jdate

# Set the directories
runrootdir=${satdirname}/
outdir=${satdirname}/txtindir/
mkdir -p ${satdirname}
mkdir -p ${outdir}

# For this test sample (GLM L2 LCFA data)
glmncdir=${runrootdir}/input/
# General data digest at CIRA/CSU
#glmncdir='/mnt/grb/'${sat_fullname}/${yyyy}/${yyyy}_${mm}_${dd}_${jdayname}/glm/L2/LCFA/

###################################################################
# Run Python code converted from the original IDL version  
# for extracting GLM L2 Group Energy and Count with lat/lon 
# and save in text output
###################################################################
## Original IDL code
#/usr/local/harris/idl/bin/idl<<EOF
#.run ${runrootdir}/read_write_GLM.pro
#read_write_GLM, $yyyy,$mm,$dd,$jdate,${s_hhmm},${satnumber},'${glmncdir}'
#EOF

echo python read_write_GLM.py $yyyy $mm $dd $jdate ${s_hhmm} ${satnumber} ${glmncdir}
python read_write_GLM.py $yyyy $mm $dd $jdate ${s_hhmm} ${satnumber} ${glmncdir}
