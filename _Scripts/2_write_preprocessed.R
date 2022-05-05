### Script for writing out preprocessed data for IDFR project ###

# Author: Austin Hurst


### Load required libraries ###

library(readr)
library(ggplot2)

source("./_Scripts/_functions/visualization.R")


### Create output paths ###

outdirs <- list(
  root = "./output/",
  task = "./output/task/",
  eye = "./output/eyelink/",
  fix = "./output/fixations/",
  sacc = "./output/saccades/", 
  img = "./output/aoi_images/"
)
for (dir in names(outdirs)) {
  dir.create(file.path(outdirs[[dir]]), showWarnings = FALSE)
}


### Write out EyeLink data ###

# Write out eye tracker settings and calibration/validation accuracy 

write_csv(eye_info, paste0(outdirs$eye, "eyelink_settings.csv"))
write_csv(recalibration_info, paste0(outdirs$eye, "recalibration_counts.csv"))
write_csv(last_validation_info, paste0(outdirs$eye, "validation_info.csv"))


# Write out fixation and saccade data for each participant

for (id in unique(fix_in_aoi$id)) {
  id_dat <- select(fix_in_aoi[fix_in_aoi$id == id, ], -c(offset_x, offset_y))
  write_csv(id_dat, paste0(outdirs$fix, id, "_fixations.csv"))
}
for (id in unique(sacc_in_aoi$id)) {
  id_dat <- select(sacc_in_aoi[sacc_in_aoi$id == id, ], -c(offset_x, offset_y))
  write_csv(id_dat, paste0(outdirs$sacc, id, "_saccades.csv"))
}


### Write out trial-by-trial task data ###

write_csv(studydat1, paste0(outdirs$task, "taskdata_encoding.csv"))
write_csv(testdat1, paste0(outdirs$task, "taskdata_recognition.csv"))
if (nrow(ratingdat1) > 0) {
  write_csv(ratingdat1, paste0(outdirs$task, "taskdata_ratings.csv"))
}


### Write out AOI data ###

# Write out the AOI polygon areas for each unique face image

write_csv(aoi_areas, paste0(outdirs$root, "aoi_areas_per_image.csv"))


# Write out images with AOIs overlayed for each face

img_path <- "./_Preprocessing/faces/_images"
unique_faces <- subset(image_index, str_detect(image, "_Encoding"))$image

for (face in unique_faces) {

  faceplot <- plot_face(face, img_path, landmarks, ovals, aoi_defs) +
    labs(x = NULL, y = NULL) +
    theme(
      plot.title = element_blank(),
      axis.line = element_blank(),
      axis.text.x = element_blank(),
      axis.text.y = element_blank(),
      axis.ticks = element_blank(),
      axis.ticks.length = unit(0, "pt"),
      axis.title = element_blank(),
      plot.margin = margin(0, 0, 0, 0, "pt"),
      legend.position = "none"
    )

  ggsave(
    gsub(".bmp", ".png", face), faceplot, path = outdirs$img,
    width = 5.90, height = 8.32, units = "in", dpi = 100
  )

}
