### Configuration settings for the analysis pipeline ###


# The facial areas of interest (AOIs) to check for fixations & saccades
#
# These are defined as sequences of facial landmarks, each defining
# a closed polygon. These are applied to each face individually using
# the landmark coordinates detected for that specific face image.

aoi_defs <- list(
  eye_l = c(36:41, 36),
  eye_r = c(42:47, 42),
  eye_region_l = c(17:21, 88:81, 17),
  eye_region_r = c(22:26, 96:89, 22),
  nasion = c(21, 22, 89:90, 28, 87:88, 21),
  nose = c(28, 87, 97:98, 31:35, 100:99, 90, 28),
  mouth = c(48:59, 48)
)
