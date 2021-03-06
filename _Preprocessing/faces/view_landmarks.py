import os
import sys
import cv2
from mediapipe.python.solutions.face_mesh import FaceMesh
from _mediapipe2dlib import LM68_ALL, LM68_EXT, LM68_EXT_NO_MOUTH


### Keys ###
# Esc: Exit
# ] : Next image
# [ : Previous image
# \ : Cycle through detection stages
# / : Save a copy of the image to the current folder
# p : Print name of current image and current values of all parameters
# a : Increase lower bound of Canny edge detection filter
# z : Decrease lower bound of Canny edge detection filter
# s : Increase upper bound of Canny edge detection filter
# x : Decrease upper bound of Canny edge detection filter
# d : Increase sigmaColor parameter of blur filter
# c : Decrease sigmaColor parameter of blur filter
# q : Toggle all MediaPipe landmarks vs desired subset
# w : Toggle face landmark refinement in MediaPipe
# t : Toggle landmark indices overlayed on the landmarks

script_root = os.path.abspath(os.path.dirname(__file__))
imgdir = os.path.join(script_root, '_images')
imgfiles = os.listdir(imgdir)
imgfiles = [f for f in imgfiles if '_Encoding.bmp' in f]
numfiles = len(imgfiles)

# Select the desired landmark set (68-landmark or 68-landmark extended)
landmark_set = LM68_EXT_NO_MOUTH

kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (8, 8))

d = 10
sigmaColor = 10
sigmaSpace = 10
canny_lo = 25
canny_hi = 200
i = 0
showtype = 0 # 0 = ellipse, 1 = dilation, 2 = blur, 3 = canny
refine = True
show_all = False
show_text = False

testing = True
while testing:
    
    img = cv2.imread(os.path.join(imgdir, imgfiles[i]))
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (8, 8))
    img_erosion = cv2.erode(gray, kernel, iterations=1)
    img_dilation = cv2.dilate(img_erosion, kernel, iterations=1)

    blur = cv2.bilateralFilter(img_dilation, d, sigmaColor, sigmaSpace)
    edged = cv2.Canny(blur, canny_lo, canny_hi)

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
    center = (int(x + w / 2.0), int(y + h / 2.0))
    out = cv2.ellipse(img, center, (int(w / 2), int(h / 2)), 0, 0, 360, (0, 255, 0), 2)
    
    if showtype % 4 == 0: # only do this if looking at final out image
        with FaceMesh(static_image_mode=True, refine_landmarks=refine) as face:
            results = face.process(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
            landmarks = results.multi_face_landmarks[0].landmark
            for j in range(len(landmarks)):
                if j not in landmark_set:
                    if not show_all:
                        continue
                lx = int(landmarks[j].x * img.shape[1])
                ly = int(landmarks[j].y * img.shape[0])
                out = cv2.circle(out, (lx, ly), 3, (255, 255, 255), -1, cv2.LINE_AA)
                if show_text:
                    if not show_all:
                        j = landmark_set.index(j)
                    out = cv2.putText(
                        out, str(j), (lx, ly), 0, 0.3, (255, 0,0), 1, cv2.LINE_AA
                    )
    
    imglist = [out, img_dilation, blur, edged]
    cv2.imshow('image', imglist[showtype % 4])
    key = cv2.waitKey(0)
    if key == 27: # exit on ESC
        testing = False
        break
    elif key == 91: # [
        i = max(i - 1, 0)
    elif key == 93: # ]
        i = min(i + 1, numfiles - 1)
    elif key == 122: # z
        canny_lo = max(canny_lo - 1, 1)
    elif key == 97: # a
        canny_lo = min(canny_lo + 1, canny_hi - 1)
    elif key == 120: # x
        canny_hi = max(canny_hi - 1, canny_lo + 1)
    elif key == 115: # s
        canny_hi = min(canny_hi + 1, 255)
    elif key == 99: # c
        sigmaColor = max(sigmaColor - 1, 1)
    elif key == 100: # d
        sigmaColor = sigmaColor + 1
    elif key == 112: # p
        print(imgfiles[i], d, sigmaColor, sigmaSpace, canny_lo, canny_hi)
    elif key == 113: # q
        show_all = show_all != True
    elif key == 119: # w
        refine = refine != True
    elif key == 116: # t
        show_text = show_text != True
    elif key == 92: # \
        showtype += 1
    elif key == 47: # /
        outfile = "img_{0}.png".format(i)
        cv2.imwrite(outfile, imglist[showtype % 4])
