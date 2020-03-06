### Script for writing out preprocessed data for IDFR project ###

# Author: Austin Hurst


### Load required libraries ###

library(readr)
library(ggplot2)

source("./_functions/visualization.R")



### Write out EyeLink info ###

dir.create(file.path("csv_out"), showWarnings = FALSE)
dir.create(file.path("csv_out", "eyelink_info"), showWarnings = FALSE)
elinfo_path <- "./csv_out/eyelink_info/"

write_csv(eye_info, paste0(elinfo_path, "eyelink_settings.csv"))
write_csv(recalibration_info, paste0(elinfo_path, "recalibration_counts.csv"))
write_csv(last_validation_info, paste0(elinfo_path, "validation_info.csv"))


### Write out fixation and saccade data to .csvs for each participant ###


dir.create(file.path("csv_out", "fixations"), showWarnings = FALSE)
dir.create(file.path("csv_out", "saccades"), showWarnings = FALSE)

for (id in unique(fix_in_aoi$id)) {
  id_dat <- select(fix_in_aoi[fix_in_aoi$id == id, ], -c(offset_x, offset_y))
  write_csv(id_dat, paste0("./csv_out/fixations/", id, "_fixations.csv"))
}

for (id in unique(sacc_in_aoi$id)) {
  id_dat <- select(sacc_in_aoi[sacc_in_aoi$id == id, ], -c(offset_x, offset_y))
  write_csv(id_dat, paste0("./csv_out/saccades/", id, "_saccades.csv"))
}


### Write out task data for all participants ###

dir.create(file.path("csv_out", "task"), showWarnings = FALSE)

write_csv(studydat1, paste0("./csv_out/task/", "taskdata_encoding.csv"))
write_csv(testdat1, paste0("./csv_out/task/", "taskdata_recognition.csv"))
write_csv(ratingdat1, paste0("./csv_out/task/", "taskdata_ratings.csv"))


### Write out AOI area data ###

write_csv(aoi_areas, paste0("./csv_out/", "aoi_areas_per_image.csv"))


### Write out images with AOIs overlayed for each face ###

dir.create(file.path("aoi_out"), showWarnings = FALSE)

unique_faces <- subset(image_index, str_detect(image, "_Encoding"))$image

for (face in unique_faces) {

  faceplot <- plot_face(face, "../_Faces/_images", landmarks, ovals, aoi_defs) +
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
    gsub(".bmp", ".png", face), faceplot, path = "./aoi_out/",
    width = 5.90, height = 8.32, units = "in", dpi = 100
  )

}
