import os
import io
import csv
import shutil

import cv2
from mediapipe.python.solutions.face_mesh import FaceMesh
from _mediapipe2dlib import LM68_ALL, LM68_EXT

######################################################################
# This script processes all images in the '_images' directory in the
# same folder, attempts to extract the bounding ovals from each image
# using OpenCV contour detection and facial landmarks using MediaPipe,
# and returns a .csv file with the results.
#
# To view the detected ovals and landmarks overlayed on each image,
# you can use the 'view_detected.py' script.
######################################################################


output_images = True
outfile_name = 'facedata.csv'

# Set paths for script
script_root = os.path.abspath(os.path.dirname(__file__))
pipeline_root = os.path.realpath(os.path.join(script_root, '..', '..'))
data_dir = os.path.join(pipeline_root, "_Data")
imgdir = os.path.join(script_root, '_images')
outdir = os.path.join(script_root, '_landmarks') # Landmark overlay folder

# Select the desired landmark set (68-landmark or 68-landmark extended)
landmark_set = LM68_EXT

# Remove image folder if it already exists and we're generating new ones
if output_images and os.path.exists(outdir):
    shutil.rmtree(outdir)

# Get list of all .bmp images in the input folder
imgfiles = os.listdir(imgdir)
imgfiles = [f for f in imgfiles if '_Encoding.bmp' in f]
numfiles = len(imgfiles)
failures = []

# OpenCV oval detection parameters
d = 10
sigmaColor = 10
sigmaSpace = 10
canny_lo = 25
canny_hi = 200
kernelsize = 8

# Initialize OpenCV kernel for removing background noise
kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (kernelsize, kernelsize))

# Initialize .csv header and rows
header = [
    'image', 'img_w', 'img_h',
    'oval_cx', 'oval_cy', 'oval_w', 'oval_h'
]
for i in range(0, len(landmark_set)):
    header += ['x_{0}'.format(i), 'y_{0}'.format(i)]
missing = 'NA'
rows = [header]

# Initialize values for printing progress percentages
print('\n\n=== Processing {0} images ===\n'.format(numfiles))
num_processed = 0
pct = 0


# Iterate over all image files
for f in imgfiles:
    
    # Import image and convert to grayscale
    img = cv2.imread(os.path.join(imgdir, f))
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Use erosion/dilation via OpenCV to remove background noise, allowing oval edges
    # to be properly detected
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (8, 8))
    img_erosion = cv2.erode(gray, kernel, iterations=1)
    img_dilation = cv2.dilate(img_erosion, kernel, iterations=1)

    # Apply mild edge-preserving blur to image and reduce to black/white face contour
    blur = cv2.bilateralFilter(img_dilation, d, sigmaColor, sigmaSpace)
    edged = cv2.Canny(blur, canny_lo, canny_hi)

    # Extract contours from filtered image and use contour coordinates to determine
    # face oval bounds, discarding all small contours (unwanted background noise)
    contours = cv2.findContours(edged.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)[-2]
    min_w = 40
    min_h = 40
    x1, y1, x2, y2 = (img.shape[1], img.shape[0], 0, 0)
    for c in contours:
        x, y, w, h = cv2.boundingRect(c)
        if w < min_w and h < min_h:
            continue
        if x < x1:
            x1 = x
        if y < y1:
            y1 = y
        if x + w > x2:
            x2 = x + w
        if y + h > y2:
            y2 = y + h

    x, y, w, h = (x1, y1, x2-x1, y2-y1)
    oval_success = x2 != 0 and y2 != 0
    
    # Extract landmarks from image w/ MediaPipe
    landmarks = []
    with FaceMesh(static_image_mode=True, refine_landmarks=True) as face:
        results = face.process(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
        if results.multi_face_landmarks != None:
            landmarks_raw = results.multi_face_landmarks[0].landmark
            for j in landmark_set:
                lx = landmarks_raw[j].x * img.shape[1]
                ly = landmarks_raw[j].y * img.shape[0]
                landmarks.append((lx, ly))

    
    # Pre-process collected data for later writing to .csv
    row = [f, img.shape[1], img.shape[0]]
    if oval_success:
        cx, cy = (round(x + w / 2.0, 3), round(y + h / 2.0, 3))
        row = row + [cx, cy, w, h]
    else:
        row = row + [missing] * 4
    if landmarks:
        for lm in landmarks:
            row.append(round(lm[0], 3)) # x
            row.append(round(lm[1], 3)) # y
    else:
        row = row + [missing] * (len(landmark_set) * 2)
    rows.append(row)
    if not (oval_success and landmarks):
        failures.append(f)
    
    if output_images:
        out = img
        # Draw oval and landmarks on image
        if oval_success:
            center = (int(x + w / 2.0), int(y + h / 2.0))
            size = (int(w / 2), int(h / 2))
            out = cv2.ellipse(out, center, size, 0, 0, 360, (0, 255, 0), 2, cv2.LINE_AA)
        if landmarks:
            for lm in landmarks:
                lm_int = [int(i) for i in lm]
                out = cv2.circle(out, lm_int, 3, (0, 0, 255), -1, cv2.LINE_AA)
        # Write out image to output directory
        if not os.path.isdir(outdir):
            os.mkdir(outdir)
        outname = f.split('.')[0] + '.png'
        outpath = os.path.join(outdir, outname)
        cv2.imwrite(outpath, out)
        
    # Print out progress percentage
    num_processed += 1
    pct_complete = int((num_processed / float(numfiles)) * 10) * 10
    if pct_complete > pct:
        print('{0}% ...'.format(pct_complete))
        pct = pct_complete
        

# Write processed landmark data to .csv
local_outfile = os.path.join(script_root, outfile_name)
data_outfile = os.path.join(data_dir, outfile_name)
for outfile in [local_outfile, data_outfile]:
    if os.path.exists(outfile):
        os.remove(outfile)
    with io.open(outfile, 'w', encoding='utf-8') as dat:
        writer = csv.writer(dat)
        for row in rows:
            writer.writerow(row)

# Write out completion/failures messages
if len(failures):
    print('\nUnable to properly detect faces for {0} images:'.format(len(failures)))
    for f in failures:
        print(' - {0}'.format(f))
    
print('\n=== Processing completed ===\n')
