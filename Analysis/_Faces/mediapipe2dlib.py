### MediaPipe 468 landmark to dlib 68 landmark maps ###

# MediaPipe's 468 landmark BlazeFace model is great, but the numbers of the
# landmarks aren't sequential enough to be easily joined and there are way too
# many to easily work with. This file defines mappings from the MediaPipe face
# landmark indices to the 68 points defined by the dlib/OpenFace model, as well
# as some additional useful landmarks in sequential order.


### Define the indices for the base 68 landmarks ###

LM68_FACE = [
    127, 234, 132, 58, 172, 150, 149, 148, 152,
    377, 378, 379, 397, 288, 361, 454, 356
]
LM68_EYEBROW_R = [70, 63, 105, 66, 107]
LM68_EYEBROW_L = [336, 296, 334, 293, 300]
LM68_NOSE_LINE = [168, 197, 5, 4]
LM68_NOSE_BASE = [98, 97, 2, 326, 327]
LM68_EYE_R = [130, 160, 158, 133, 153, 144]
LM68_EYE_L = [362, 385, 387, 263, 373, 380]
LM68_MOUTH_OUTER = [
    61, 39, 37, 0, 267, 269,
    291, 321, 314, 17, 84, 91
]
LM68_MOUTH_INNER = [
    78, 82, 13, 312,
    308, 317, 14, 87
]
LM68_ALL = (
    LM68_FACE + LM68_EYEBROW_R + LM68_EYEBROW_L +
    LM68_NOSE_LINE + LM68_NOSE_BASE +
    LM68_EYE_R + LM68_EYE_L +
    LM68_MOUTH_OUTER + LM68_MOUTH_INNER
)


### Define the indices for additional landmark regions ###

LM68_EXT_FOREHEAD = [
    162, 21, 54, 103, 67, 109, 10, 338, 297, 332, 284, 251, 389
]
LM68_EXT_LOWER_EYE_R = [143, 117, 118, 119, 120, 121, 128, 193]
LM68_EXT_LOWER_EYE_L = [417, 357, 350, 349, 348, 347, 346, 372]
LM68_EXT_NOSE_CONTOUR = [209, 48, 429, 278]
LM68_EXT_MOUTH_REGION = [
    57, 186, 92, 165, 167, 164, 393, 391, 322, 410,
    287, 273, 335, 406, 313, 18, 83, 182, 106, 43
]
LM68_EXT = (
    LM68_ALL + LM68_EXT_FOREHEAD +
    LM68_EXT_LOWER_EYE_R + LM68_EXT_LOWER_EYE_L +
    LM68_EXT_NOSE_CONTOUR + LM68_EXT_MOUTH_REGION
)

LM68_EXT_NO_MOUTH = (
    LM68_ALL + LM68_EXT_FOREHEAD +
    LM68_EXT_LOWER_EYE_R + LM68_EXT_LOWER_EYE_L +
    LM68_EXT_NOSE_CONTOUR
)
