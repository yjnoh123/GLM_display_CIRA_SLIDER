#
"""
####################################################################################
GOES-R GLM display
 Read GOES-R GLM Level-2 LCFA 'Group' data fields and Plot GLM over ABI sectors
 The original input data is, for instance, OR_GLM-L2-LCFA_G19_*.nc collected for ABI scan time
 (Converted into text data output through remaping/accumulating already with separate fortran codes)

 Created by Y.J. Noh (CIRA/Colorado State University) Yoo-Jeong.Noh@colostate.edu (IDL, 02/27/2018)
 and modified (20241016) for gitlab release and test-converted in Python (Y.J. Noh 07/09/2025)
 Tested with Python 3.8.8
####################################################################################
"""

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
from PIL import Image
#from fortranfile import FortranFile
from scipy.io import FortranFile
import os
import sys
import argparse

#########################
"""
Several image adjustment functions
"""
def read_custom_colormap(filepath, n_col=256):
    r, g, b = np.zeros(n_col), np.zeros(n_col), np.zeros(n_col)
    with open(filepath, 'r') as f:
        for i in range(n_col):
            r[i], g[i], b[i] = map(int, f.readline().split())
    return np.stack([r, g, b], axis=1).astype(np.uint8)

def make_plot_image(data, minv, maxv, custom_cmap=None):
    data = data.T
    mask_pos = data > 0
    mask_zero = data == 0
    data = np.where(mask_pos, np.log10(data), 0.0)
    data[~mask_pos] = 0.0
    img_scaled = np.clip(((data - minv) / (maxv - minv)) * 254, 0, 254).astype(np.uint8)
    if custom_cmap is not None:
        rgb = custom_cmap[img_scaled]
    else:
        cmap = plt.get_cmap('jet', 256)
        rgb = (cmap(img_scaled / 255.0)[:, :, :3] * 255).astype(np.uint8)
    rgb[mask_zero] = [0, 0, 0]
    return rgb, img_scaled

def apply_alpha(img, img_scaled, transparency_min, edge_thresh):
    red, grn, blu = img[:,:,0], img[:,:,1], img[:,:,2]
    xp, yp = img.shape[:2]
    alpha = np.full((xp, yp), 245, dtype=np.uint8)
    black_mask = (red == 0) & (grn == 0) & (blu == 0)
    alpha[black_mask] = 0
    edge_mask = (img_scaled < edge_thresh) & (img_scaled > 0)
    edge_indices = np.where(edge_mask)
    if edge_indices[0].size > 0:
        relative_vals = (img_scaled[edge_indices] - 3) / (edge_thresh - 3)
        transparency = ((245 - transparency_min) * (relative_vals ** 0.9)).astype(np.uint8) + transparency_min
        alpha[edge_indices] = transparency
    return np.dstack([red, grn, blu, alpha])

##########################################################################
# Example input setup
satdirname = 'ABI'
domain = 'RadC'  # 'RadF', 'RadC', 'RadM1', or 'RadM2'

if len(sys.argv) == 1:
    # For test
    input_file = 'remapped_glm_group_g19_radf.bin'
    yyyy = 2025
    mm = 7
    dd = 29
    jday = 210
    utc_hhmmss = 150117
else:
    parser = argparse.ArgumentParser(description="Reproject the extracted GLM group data and plot for SLIDER.")
    parser.add_argument("yyyy", type=int, help="4-digit year")
    parser.add_argument("mm", type=int, help="Month (1-12)")
    parser.add_argument("dd", type=int, help="Day (1-31)")
    parser.add_argument("jday", type=int, help="Julian day (1-366)")
    parser.add_argument("utc_hhmmss", type=int, help="UTC time in HHMMSS format (e.g., 153017)")
    parser.add_argument("input_file", type=str, help=" (e.g., GLM19/RadC/20250729150117.glm_resample.bin)")
    parser.add_argument("satdirname", type=str, help="Which GOES GLM (e.g., GLM19)")
    parser.add_argument("sector", type=str, help="ABI sector name (e.g., RadC)")
    args = parser.parse_args()

    yyyy=args.yyyy
    mm=args.mm
    dd=args.dd
    jday=args.jday
    input_file=args.input_file
    satdirname=args.satdirname
    sector=args.sector

yyyymmdd = f"{yyyy:04d}{mm:02d}{dd:02d}"
utc_time_str = f"{args.utc_hhmmss:06d}"

workdir = os.getcwd()
#outdir = os.path.join(satdirname, domain, 'output', f"{yyyy:04d}{jday:03d}")
outdir = os.path.join(satdirname, domain, 'output')
os.makedirs(outdir, exist_ok=True)

# Domain and dimension setup
if domain == 'RadF':
    nx, ny = 5424, 5424
elif domain == 'RadC':
    nx, ny = 2500, 1500
elif domain in ('RadM1', 'RadM2'):
    nx, ny = 1000, 1000
else:
    raise ValueError(f"Unsupported domain for ABI: {domain}")

# Read pre-processed GLM group area count/energy data - remapped and accumulated for ABI sectors using fortran
with open(input_file, 'rb') as f:
    csum = np.fromfile(f, dtype=np.float32, count=nx*ny).reshape((nx, ny), order='F')
    esum = np.fromfile(f, dtype=np.float32, count=nx*ny).reshape((nx, ny), order='F')

GLM_count = csum
GLM_energy = esum

# Read pre-processed GLM group area count/energy data - remapped and accumulated for ABI sectors
# Note that transparency min and edge threshold values are different for count and energy

for ifig in range(2):
    if ifig == 0:
        output = GLM_count.copy()
        minv, maxv = 1, 2.56
        varname = 'group_counts'
        transparency_min = 100
        edge_thresh_value = 50
        use_custom_cmap = False
    else:
        output = GLM_energy.copy() * 1e12
        if domain in ('RadM1', 'RadM2'):
            output[GLM_count <= 1] *= 0.5
        elif domain == 'RadC':
            output /= 5
        elif domain == 'RadF':
            output /= 10
        output[output < 0] = 0.0
        minv, maxv = -6.0, 0.6
        varname = 'group_energy'
        transparency_min = 2
        edge_thresh_value = 170
        use_custom_cmap = True
    if use_custom_cmap:
        cmap_path = os.path.join(workdir, 'color_tables/Noh_violet_glm_energy_rgb.txt')
        cmap_array = read_custom_colormap(cmap_path)
    else:
        cmap_array = None

#
    img_rgb, img_scaled = make_plot_image(output, minv, maxv, cmap_array)
    rgba_img = apply_alpha(img_rgb, img_scaled, transparency_min, edge_thresh_value)

#
    out_filename = os.path.join(outdir, f'cira_glm_l2_{varname}_{yyyymmdd}{utc_time_str}.png')
    Image.fromarray(rgba_img).save(out_filename)

    print(f"Saved {out_filename}")

print(f"Test Done!")

