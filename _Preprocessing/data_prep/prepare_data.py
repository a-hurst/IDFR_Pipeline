import os
import sys
import shutil
import subprocess as sp
from zipfile import ZipFile, ZIP_DEFLATED

# NOTE: This script assumes the 'edf2asc' command-line tool from
# the EyeLink Developer Kit is installed to your path (e.g. copied
# to /usr/local/bin/ on a Mac or Linux machine).

# All processed output from this script should be included with any
# online repository of an experiment's data, so you shouldn't need
# to run it yourself unless you really want to.


rawdir = 'Raw'
outdir = '_Data'
excludedir = '_Exclude'

outdir = os.path.join(os.getcwd(), outdir)
excludedir = os.path.join(os.getcwd(), excludedir)
for d in [outdir, excludedir]:
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.mkdir(d)

exts_to_copy = ['dat', 'txt']
    
missing = []
renamed = []
weird = []


folders = os.listdir(rawdir)
for f in folders:
    
    if 'idfr_' not in f:
        continue
        
    # Check if EDF exists for a given participant folder
    rawdir_id = os.path.join(rawdir, f)
    outdir_id = os.path.join(outdir, f)
    edfname = f + '.edf'
    ascname = f + '.asc'
    edfpath = os.path.join(rawdir_id, edfname)
    asc_outpath = os.path.join(outdir_id, ascname)
    if not os.path.exists(edfpath):
        edffiles = [n for n in os.listdir(rawdir_id) if n.split('.')[-1] == 'edf']
        if len(edffiles) == 1:
            edfname = edffiles[0]
            edfpath = os.path.join(rawdir_id, edfname)
            asc_outpath = os.path.join(outdir_id, edfname.split('.')[0] + '.asc')
            renamed.append("{0} -> {1}".format(edfname, ascname))
        else:
            missing.append(f)
            continue
    
    # If EDF exists, create particpant folder and copy data
    if os.path.isdir(outdir_id):
        shutil.rmtree(outdir_id)
    os.mkdir(outdir_id)
    for datafile in os.listdir(rawdir_id):
        if datafile.split('.')[-1] in exts_to_copy:
            filepath = os.path.join(rawdir_id, datafile)
            filedest = os.path.join(outdir_id, datafile)
            shutil.copyfile(filepath, filedest)
            
    # Check for weirdnesses in data for any IDs (mismatch between id and version)
    stimfiles = [n for n in os.listdir(rawdir_id) if '.dat' in n]
    id_num = f.split('_')[-1] # id number (e.g. 123) as string
    id_version = int(id_num[0]) # first digit of participant id
    stimdat_version = int(stimfiles[0].split('.')[0][-1]) # version from stimfile
    if id_version != stimdat_version:
        id_num = str(stimdat_version) + id_num[1:]
        new_id = 'idfr_' + id_num
        new_outdir_id = os.path.join(outdir, new_id)
        os.rename(outdir_id, new_outdir_id)
        outdir_id = new_outdir_id
        ascname = new_id + '.asc'
        asc_outpath = os.path.join(outdir_id, edfname.split('.')[0] + '.asc')
        weird.append("{0} -> {1}".format(f, new_id))
            
    # Convert EDF to ASC and save to output directory
    print("\n\n=== Converting '{0}' to ASC... ===".format(edfname))
    cmd = [
        'edf2asc', '-c', # -c flag avoids issues w/ some files
        '-p', outdir_id, # save to output dir
        edfpath
    ]
    p = sp.Popen(cmd, stdout=sys.stdout, stderr=sys.stderr)
    p.communicate() # no way of checking exit code for some silly reason
    
    # If EDF name mismatches participant id from folder, rename it
    if edfname.split('.')[0] != ascname.split('.')[0]:
        os.rename(asc_outpath, os.path.join(outdir_id, ascname))
    asc_outpath = os.path.join(outdir_id, ascname)
        
    # Finally, compress the .ASC as .zip to save space, since readr supports this
    zip_outpath = asc_outpath + '.zip'
    with ZipFile(zip_outpath, 'w', compression=ZIP_DEFLATED) as zf:
        zf.write(asc_outpath, arcname = ascname)
    os.remove(asc_outpath)


if len(missing):
    print("\n\nMissing EDF files for the following participants:\n")
    for i in missing:
        print(" - {0}".format(i))
        
if len(renamed):
    print("\n\nThe following output ASC files were renamed:\n")
    for i in renamed:
        print(" - {0}".format(i))
        
if len(weird):
    print("\n\nThe following ids were renamed due to version/id mismatch:\n")
    for i in weird:
        print(" - {0}".format(i))

print("\n\n=== Data preparation script complete ===\n")
