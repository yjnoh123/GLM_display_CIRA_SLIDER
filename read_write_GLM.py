#
"""
####################################################################################
 Sample Python code converted from the IDL code for reading GLM Level-2 LCFA nc data 
 and writing out txt file per min (read_write_GLM.py = read_write_GLM.pro)
 Created in IDL and converted to Python by Yoo-Jeong.Noh@colostate.edu 
 adopting Steve Miller's original idl read code (26 Feb 2018)
 Several more updates by yjnoh on 20220517 for GOES18 and 20240923 for GOES19
 It runs as part of run_goes_glm_extract.sh through crontab every min.

# For this sample,
#> python read_write_GLM.py 2025 07 22 209 1540 19 ./input/
# For GOES-19 GLM at CIRA/CSU, '19' below is GOES sat number. Change indir and outdir.
#> python read_write_GLM.py 2025 07 28 209 2250 19 /mnt/grb/goes19/2025/2025_07_28_209/glm/L2/LCFA/
####################################################################################
"""

import os
import glob
import numpy as np
import xarray as xr
import argparse

def read_write_GLM(yyyy, mm, dd, jday, utc_hhmm, satnumber, indir):
    gtype = 'group'
    satnumber_str = f"{satnumber:02d}"
    sat_name = f"G{satnumber_str}"
    current_dir = os.getcwd()

    satdirname = f"{current_dir}/GLM{satnumber_str}"
    os.makedirs(satdirname, exist_ok=True)

    yyyy_str = f"{yyyy:04d}"
    mm_str   = f"{mm:02d}"
    dd_str   = f"{dd:02d}"
    jday_str = f"{jday:03d}"
    utc_hhmm_str = f"{utc_hhmm:04d}"

    outdir = os.path.join(satdirname, "txtindir")
    print(f"Output directory: {outdir}")
    os.makedirs(outdir, exist_ok=True)

    glm_search_pattern = f"OR_GLM-L2-LCFA_{sat_name}_s{yyyy_str}{jday_str}{utc_hhmm_str}*.nc"
    file_list = sorted(glob.glob(os.path.join(indir, glm_search_pattern)))
    print(f"Input L2 directory: {indir}")

    for filename in file_list:
        a1 = filename.find('_s')
        a2 = filename.find('_e')
        str_gstime = filename[a1+9:a1+16]
        str_getime = filename[a2+9:a2+16]

        outfile = os.path.join(outdir, f"GLM_{sat_name}_{yyyy_str}{jday_str}_s{str_gstime}_e{str_getime}.{gtype}.txt")

        ds = xr.open_dataset(filename)  # decode_cf=True by default

        # Note that variables automatically scaled and masked with xr
        group_lat = ds['group_lat'].values
        group_lon = ds['group_lon'].values
        group_area = ds['group_area'].values
        group_energy = ds['group_energy'].values
        group_quality_flag = ds['group_quality_flag'].values

        # Filtering to use valid values only
        valid_mask = (group_energy > 0.0) & (group_energy < 1e-11) & (group_quality_flag == 0)

        if np.any(valid_mask):
            group_lat = group_lat[valid_mask]
            group_lon = group_lon[valid_mask]
            group_area = group_area[valid_mask]
            group_energy = group_energy[valid_mask]

        sz = len(group_lat)

        # Write to ASCII file per min
        with open(outfile, 'w') as f:
            f.write(f"{sz}\n")
            for lat, lon, area, energy in zip(group_lat, group_lon, group_area, group_energy):
                f.write(f"{lat:.6f} {lon:.6f} {area:.6f} {energy:.6e}\n")
#
if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Extract GLM group data and write ASCII files.")
    parser.add_argument("yyyy", type=int, help="4-digit year")
    parser.add_argument("mm", type=int, help="Month (1-12)")
    parser.add_argument("dd", type=int, help="Day (1-31)")
    parser.add_argument("jday", type=int, help="Julian day (1-366)")
    parser.add_argument("utc_hhmm", type=int, help="UTC time in HHMM format (e.g., 1530)")
    parser.add_argument("satnumber", type=int, help="Satellite number (e.g., 16 for GOES-16)")
    parser.add_argument("indir", type=str, help="Input directory containing GLM NetCDF files")

    args = parser.parse_args()

    read_write_GLM(
        yyyy=args.yyyy,
        mm=args.mm,
        dd=args.dd,
        jday=args.jday,
        utc_hhmm=args.utc_hhmm,
        satnumber=args.satnumber,
        indir=args.indir
    )
