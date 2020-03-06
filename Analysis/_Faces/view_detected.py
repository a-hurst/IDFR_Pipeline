import os
import cv2
import pyopenface as of

### Keys ###
# Esc: Exit
# ] : Next image
# [ : Previous image
# \ : Cycle through detection stages
# p : Print name of current image and current values of all parameters
# a : Increase lower bound of Canny edge detection filter
# z : Decrease lower bound of Canny edge detection filter
# s : Increase upper bound of Canny edge detection filter
# x : Decrease upper bound of Canny edge detection filter
# d : Increase sigmaColor parameter of blur filter
# c : Decrease sigmaColor parameter of blur filter

p = of.FaceParams()
mod = of.FaceModel()
det_order = [of.MTCNN_DETECTOR, of.HAAR_DETECTOR, of.HOG_SVM_DETECTOR]

imgdir = os.path.join(os.getcwd(), '_images')
imgfiles = os.listdir(imgdir)
imgfiles = [f for f in imgfiles if '_Encoding.bmp' in f]
numfiles = len(imgfiles)

kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (8, 8))

d = 10
sigmaColor = 10
sigmaSpace = 10
canny_lo = 25
canny_hi = 200
i = 0
showtype = 0 # 0 = ellipse, 1 = dilation, 2 = blur, 3 = canny
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
        bbox = None
        for det in det_order:
            confidence, bbox = of.detect_face(gray, mod, face_det = det)
            if bbox != None:
                break
                
        if not bbox:
            bbox = (x, y, w, h) # use ellipse rectangle for face region
            
        landmarks = of.detect_landmarks(gray, mod, p, bbox = bbox)
        if landmarks:
            halflen = int(len(landmarks)/ 2)
            for l in range(0, halflen, 1):
                x, y = (int(landmarks[l]), int(landmarks[l+halflen]))
                out = cv2.circle(out, (x, y), 3, (0, 0, 255), -1, cv2.LINE_AA)
    
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
    elif key == 92: # \
        showtype += 1
