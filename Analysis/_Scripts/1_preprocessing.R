### Script for preprocessing IDFR project data after import ###

# Author: Austin Hurst


### Load required libraries ###

library(tidyr)
library(dplyr)
library(stringr)
library(tibble)

source("./_functions/aoi_functions.R")

options(readr.show_progress = FALSE)



### Import task, face, and eyelink data ###

source("./_import/01_import_task.R")
source("./_import/02_import_face.R")
source("./_import/03_import_eyelink.R")



### Summarize and aggregate misc info from eye tracking data ###

# Aggregate EDF metadata into a data frame to check settings

eye_info <- map_df(asc_ids, function(i) {
  df <- eyedat[[i]]$info
  df <- add_column(df, id = i, .before = 1)
  df
})


# Get EyeLink validation information for each study block/participant

validation_info <- map_df(asc_ids, function(i) {

  asc <- eyedat[[i]]

  # Define column names & types
  colnames <- c(
    "type", "eyes", "eye", "quality", "avg.err", "max.err",
    "err.deg", "offset.x", "offset.y"
  )
  coltypes <- "ccccddddd"

  # Get all validation lines in ASC messages
  is_val <- grepl("VALIDATION(?!.*ABORTED)", asc$msg$text, perl = TRUE)
  val <- asc$msg$text[is_val]
  while (length(val) < 2) {
    val <- c(val, "")
  }

  # Sanitize validation summary lines before parsing
  val_regex <- "!CAL\\s+|VALIDATION|ERROR|avg\\.|max|OFFSET|deg\\.| pix\\."
  val <- str_replace_all(val, ",", "  ")
  val <- str_replace_all(val, val_regex, "")

  # Read sanitized validation summary lines into dataframe
  df <- read_table(val, col_names = colnames, col_types = coltypes)
  df <- add_column(df, time = asc$msg$time[is_val], .before = 1)
  df <- add_column(df, block = asc$msg$block[is_val], .before = 1)
  df <- add_column(df, id = i, .before = 1)

  df
})
validation_info$type <- as.factor(validation_info$type)
validation_info$eyes <- as.factor(validation_info$eyes)
validation_info$quality <- as.factor(validation_info$quality)

recalibration_info <- validation_info %>%
  # Get number of recalibrations for each block / id
  group_by(id, block) %>%
  summarize(calibrations = n()) %>%
  ungroup()

last_validation_info <- validation_info %>%
  # Get final validation for ecah block / id
  group_by(id, block) %>%
  filter(row_number() == n()) %>%
  ungroup()


# Filter between-block events from eye data

for (i in asc_ids) {
  for (n in c("fix", "sacc", "msg")) {
    eyedat[[i]][[n]] <- subset(eyedat[[i]][[n]], block %% 1 == 0)
  }
}


# Get ids of participants who have more or less than 150 trials

eye_trials <- map_df(asc_ids, function(i) {
  eyedat[[i]]$msg %>%
    summarize(id = i, blocks = length(unique(block)))
})
subset(eye_trials, blocks != 150)


# Get ids of participants who have fixations on less than 150 trials
# (indicates calibration issues for participant)

fix_trials <- map_df(asc_ids, function(i) {
  eyedat[[i]]$fix %>%
    summarize(id = i, blocks = length(unique(block)))
})
subset(fix_trials, blocks < 150)



### Generate table of image info for each participant and trial ###

# Get table of images & face ids for each trial/participant

imginfo <- bind_rows(
  select(studydat1, c(id, trial, image, face_id)),
  select(testdat1, c(id, trial, image, face_id)),
  select(ratingdat1, c(id, trial, image, face_id))
)

imginfo <- imginfo %>%
  group_by(id) %>%
  arrange(trial, .by_group = TRUE) %>%
  ungroup()


# Calculate x/y offsets for each image based on trial number & image size

imginfo <- imginfo %>%
  left_join(select(ovals, c("image", "img_w", "img_h")), by = "image") %>%
  mutate(
    offset_x = (eye_info$screen.x[1] / 2) - as.integer(img_w / 2),
    offset_y = (eye_info$screen.y[1] / 2) - as.integer(img_h / 2)
  ) %>%
  mutate(
    offset_y = ifelse(trial >= 90, offset_y - 150, offset_y)
  )


# Create dataframe with names and index numbers of all images

image_index <- ovals %>%
  select(c(image)) %>%
  mutate(img_index = 1:n())


# Append image indices to imginfo list

imginfo <- left_join(imginfo, image_index, by = "image")



### Preprocess and prepare eye tracking data ###

# Check for failed trials, since they mess up trial indexing

faceon_msgs <- c(
  "Study Face Display",
  "Test Face Display",
  "Trust_Rating_Screen"
)
faceoff_msgs <- c(
  "StudyDisplayTimer",
  "Test Response Button",
  "Trust_Rating_Keyboard"
)

failed <- map_df(asc_ids, function(i) {
  # Get all trials that had "face off" (i.e. successful trial end) messages,
  # then get the imginfo rows of the trials (if any) that didn't have those
  # messages
  face_rows <- str_detect(
    eyedat[[i]]$msg$text, paste(faceoff_msgs, collapse = "|")
  )
  noerr <- subset(eyedat[[i]]$msg, face_rows)
  df <- subset(imginfo, id == i & !(trial %in% noerr$block))
  df
})


# Try to correct for failed trials by removing from the eye data

for (i in unique(failed$id)) {
  err_blocks <- subset(failed, id == i)$trial
  for (n in c("fix", "sacc", "msg")) {
    for (b in sort(err_blocks)) {
      # Drop data from blocks with errors and decrease numbers of subsequent
      # blocks by 1
      eyedat[[i]][[n]] <- subset(eyedat[[i]][[n]], block != b)
      blks <- eyedat[[i]][[n]]$block
      eyedat[[i]][[n]]$block[blks > b] <- eyedat[[i]][[n]]$block[blks > b] - 1
    }
  }
}


# Remove missing trials (if any) from eye data

stiminfo <- bind_rows(
  select(studydat, c(id, trial)),
  select(testdat, c(id, trial)),
  select(ratingdat, c(id, trial))
)

missing_trials <- map_df(unique(imginfo$id), function(i) {
  # Check for trial numbers in stimulus list but not task data for
  # each participant (indicates aborted trial)
  stim <- subset(stiminfo, id == i)
  actual <- subset(imginfo, id == i)$trial
  subset(stim, !(trial %in% actual))
})

for (i in unique(missing_trials$id)) {
  missing_blocks <- subset(missing_trials, id == i)$trial
  for (n in c("fix", "sacc", "msg")) {
    eyedat[[i]][[n]] <- subset(eyedat[[i]][[n]], !(block %in% missing_blocks))
  }
}


# Re-check eyelink trial counts for each participant after correction

eye_trials <- map_df(asc_ids, function(i) {
  eyedat[[i]]$msg %>%
    summarize(id = i, blocks = length(unique(block)))
})
subset(eye_trials, blocks != 150)


# Identify eye events where face was actually on screen

# NOTE: this code will break big-time if there are aren't a matching pair
# of on/off images for a given trial. Code ensuring all trials have "face off"
# messages helps makes this a safe bet
for (i in asc_ids) {

  # Get face on/off times from Experiment Builder EDF messages
  face_rows <- str_detect(
    eyedat[[i]]$msg$text, paste(c(faceon_msgs, faceoff_msgs), collapse = "|")
  )
  face_changes <- subset(eyedat[[i]]$msg, face_rows) %>%
    separate(
      "text", c("offset", "text"),
      sep = " ", extra = "merge", convert = TRUE
    ) %>%
    mutate(
      time = time - offset,
      face_on = ifelse(text %in% faceon_msgs, "TRUE", "FALSE")
    )

  # Determine which fixations appeared while face was on screen
  start_time <- min(face_changes$time) - 1000
  end_time <- max(face_changes$time) + 1000
  eyedat[[i]]$fix$face_on <- as.logical(cut(
    eyedat[[i]]$fix$stime,
    breaks = c(start_time, face_changes$time, end_time),
    labels = c("FALSE", face_changes$face_on)
  ))

  # Determine which saccades appeared while face was on screen
  eyedat[[i]]$sacc$face_on <- as.logical(cut(
    eyedat[[i]]$sacc$stime,
    breaks = c(start_time, face_changes$time, end_time),
    labels = c("FALSE", face_changes$face_on)
  ))

}


# Join image names and x/y offsets to eye data

for (i in asc_ids) {
  trialimgs <- subset(imginfo, id == i)
  trialimgs <- select(trialimgs, c(trial, image, img_index, offset_x, offset_y))
  names(trialimgs)[1] <- "block" # for joining to ASC
  eyedat[[i]]$fix <- left_join(eyedat[[i]]$fix, trialimgs, by = "block")
  eyedat[[i]]$sacc <- left_join(eyedat[[i]]$sacc, trialimgs, by = "block")
}



### Generate areas of interest from face landmarks ###

# Define Face AOIs from landmark points

aoi_defs <- list(
  eye_l = c(36:41, 36),
  eye_r = c(42:47, 42),
  eye_region_l = c(17:21, 88:81, 17),
  eye_region_r = c(22:26, 96:89, 22),
  nasion = c(21, 22, 89:90, 28, 87:88, 21),
  nose = c(28, 87, 97:98, 31:35, 100:99, 90, 28),
  mouth = c(48:59, 48)
)

aois_poly <- generate_aois(image_index$image, landmarks, aoi_defs)


# Calculate areas of each ROI for each face image

oval_areas <- ovals %>%
  mutate(
    aoi = "face",
    area = w * h * pi,
  ) %>%
  select(c(image, aoi, area))

aoi_areas <- map_df(names(aois_poly), function(img) {
  df <- enframe(st_area(aois_poly[[img]]))
  df$name <- names(aois_poly[[img]])
  names(df) <- c("aoi", "area")
  df <- add_column(df, image = img, .before = 1)
  df
})

aoi_areas <- aoi_areas %>%
  bind_rows(oval_areas) %>%
  spread(aoi, area) %>%
  group_by(image) %>%
  mutate(
    face_only = face - (eye_region_l + eye_region_r + nasion + nose + mouth)
  ) %>%
  gather(-image, key = "aoi", value = "area") %>%
  arrange(image)



### Determine which AOIs (if any) fixations and saccades belong to ###

# NOTE: Even on a faster computer, these can take 30 to 40 seconds

# Process fixations

fix_in_aoi <- map_df(asc_ids, function(id) {

  f <- eyedat[[id]]$fix

  # Adjust fixation coords to align with image ROI coordinates
  fx <- f$axp - f$offset_x
  fy <- f$ayp - f$offset_y

  # Check if fixations in face oval
  fix_imgid <- f$img_index
  f$on_face <- in_ellipse(fx, fy,
    ovals[fix_imgid, ]$cx, ovals[fix_imgid, ]$cy,
    ovals[fix_imgid, ]$w, ovals[fix_imgid, ]$h
  )

  # Check if fixations on defined AOIs
  f <- bind_cols(f, point_on_aois(fx, fy, f$image, aois_poly))

  # Add id column
  f <- add_column(f, id = id, .before = 1)
  f$img_index <- NULL

  f
})
fix_in_aoi$id <- as.factor(fix_in_aoi$id)
fix_in_aoi$image <- as.factor(fix_in_aoi$image)


# Process saccades

sacc_in_aoi <- map_df(asc_ids, function(id) {

  s <- eyedat[[id]]$sacc

  # Adjust saccade coords to align with image ROI coordinates
  sx_s <- s$sxp - s$offset_x
  sy_s <- s$syp - s$offset_y
  sx_e <- s$exp - s$offset_x
  sy_e <- s$eyp - s$offset_y

  # Check if saccades start in face oval and/or any defined AOIs
  sacc_imgid <- s$img_index
  start_on_face <- in_ellipse(sx_s, sy_s,
    ovals[sacc_imgid, ]$cx, ovals[sacc_imgid, ]$cy,
    ovals[sacc_imgid, ]$w, ovals[sacc_imgid, ]$h
  )
  end_on_face <- in_ellipse(sx_e, sy_e,
    ovals[sacc_imgid, ]$cx, ovals[sacc_imgid, ]$cy,
    ovals[sacc_imgid, ]$w, ovals[sacc_imgid, ]$h
  )

  # Check if saccade starts/ends on defined AOIs
  start_aois <- point_on_aois(sx_s, sy_s, s$image, aois_poly)
  end_aois <- point_on_aois(sx_e, sy_e, s$image, aois_poly)
  names(start_aois) <- gsub("^on_", "start_on_", names(start_aois))
  names(end_aois) <- gsub("^on_", "end_on_", names(end_aois))

  # Merge saccade data with AOI data
  s$start_on_face <- start_on_face
  s <- bind_cols(s, start_aois)
  s$end_on_face <- end_on_face
  s <- bind_cols(s, end_aois)

  # Add id column
  s <- add_column(s, id = id, .before = 1)
  s$img_index <- NULL

  s
})
sacc_in_aoi$id <- as.factor(sacc_in_aoi$id)
sacc_in_aoi$image <- as.factor(sacc_in_aoi$image)
