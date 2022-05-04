### Script for importing IDFR task data into R ###

# Author: Austin Hurst


### Load required libraries ###

library(readr)
library(purrr)
library(tibble)
library(tidyr)
library(dplyr)



### Read task data files ###

id_dirs <- list.dirs("../_Data", recursive = FALSE)


# Read study phase data

studycols <- c("list", "image", "face_id", "face_gender")

studydat <- map_df(id_dirs, function(d) {
  studyfile <- list.files(d, full.names = TRUE, pattern = "*actual_STUDY*")
  dat <- read_tsv(studyfile, col_names = studycols, col_types = "cccc")
  dat <- add_column(dat, trial = 1:nrow(dat), .before = 1)
  dat <- add_column(dat, id = basename(d), .before = 1)
  dat
})

studydat$id <- as.factor(studydat$id)
studydat$list <- as.factor(studydat$list)
studydat$face_id <- as.factor(studydat$face_id)
studydat$face_gender <- as.factor(studydat$face_gender)


# Read test phase data

testcols <- c(
  "list", "image", "face_id", "distractor",
  "face_gender", "correct_resp"
)

testdat <- map_df(id_dirs, function(d) {
  testfile <- list.files(d, full.names = TRUE, pattern = "*actual_TEST*")
  dat <- read_tsv(testfile, col_names = testcols, col_types = "ccccci")
  dat$distractor <- dat$distractor == "Distractor"
  dat$correct_resp <- ifelse(dat$correct_resp == 7, "New", "Old")
  dat <- add_column(dat, trial = 1:nrow(dat) + 30, .before = 1)
  dat <- add_column(dat, id = basename(d), .before = 1)
  dat
})

testdat$id <- as.factor(testdat$id)
testdat$list <- as.factor(testdat$list)
testdat$face_id <- as.factor(testdat$face_id)
testdat$face_gender <- as.factor(testdat$face_gender)
testdat$correct_resp <- as.factor(testdat$correct_resp)


# Read rating phase data

ratingcols <- c("list", "image", "face_id", "distractor", "face_gender")

ratingdat <- map_df(id_dirs, function(d) {
  ratingfile <- list.files(d, full.names = TRUE, pattern = "*actual_RATING*")
  dat <- read_tsv(ratingfile, col_names = ratingcols, col_types = "ccccc")
  dat$distractor <- dat$distractor == "Distractor"
  dat <- add_column(dat, trial = 1:nrow(dat) + 90, .before = 1)
  dat <- add_column(dat, id = basename(d), .before = 1)
  dat
})

ratingdat$id <- as.factor(ratingdat$id)
ratingdat$list <- as.factor(ratingdat$list)
ratingdat$face_id <- as.factor(ratingdat$face_id)
ratingdat$face_gender <- as.factor(ratingdat$face_gender)


# Read awful results data

# prefixes: s_ == study, t_ == test, r_ == rating
resultscols <- c(
  "version", "eye",
  # Study phase columns
  "s_list", "s_trial", "s_face_onset", "s_image", "s_face_id",
  "s_face_gender",
  # Interphase columns
  "st_intervening_task_time", "test_instr_time", "test_cal_time",
  "st_interphase_time",
  # Test phase columns
  "t_list", "t_trial", "t_face_onset", "t_image", "t_face_id",
  "t_face_gender", "t_distractor", "t_correct_resp", "t_response_button",
  "t_response", "t_resp_type", "t_rt", "t_accuracy", "t_total_correct",
  # Interphase columns
  "rating_instr_time", "rating_cal_time", "tr_interphase_time",
  # Rating phase columns
  "r_list", "r_trial", "r_face_onset", "r_image", "r_face_id",
  "r_distractor", "r_face_gender", "r_rt", "r_trust"
)

resultsdat <- map_df(id_dirs, function(d) {

  # Determine results file name from id
  id_num <- as.numeric(strsplit(basename(d), "_")[[1]][2])
  version <- id_num %/% 100
  v_pattern <- paste0("*V", as.character(version), ".txt")

  # Actually read in results
  resultsfile <- list.files(d, full.names = TRUE, pattern = v_pattern)
  dat <- read_tsv(resultsfile, col_types = cols(), na = ".")

  # Rename columns and add id
  names(dat) <- resultscols
  dat <- add_column(dat, id = basename(d), .before = 1)
  dat
})


### Wrangle results into cleaner separate dataframes ###

# Participant-level info

participant_info <- resultsdat %>%
  group_by(id) %>%
  summarize(
    version = version[1],
    eye = eye[1],
    trials = length(id),
    st_intervening_task_time = max(st_intervening_task_time),
    test_instr_time = max(test_instr_time),
    test_cal_time = max(test_cal_time),
    st_interphase_time = max(st_interphase_time),
    total_correct = max(t_total_correct),
    rating_instr_time = max(rating_instr_time),
    rating_cal_time = max(rating_cal_time),
    tr_interphase_time = max(tr_interphase_time)
  )
participant_info$id <- as.factor(participant_info$id)
participant_info$eye <- as.factor(participant_info$eye)


# Study phase results

studydat1 <- resultsdat %>%
  subset(test_cal_time == 0) %>% # select study phase rows
  select(c("id", starts_with("s_"))) %>% # select only study phase cols
  select(-s_face_onset, s_face_onset) # move face onset time to last col

names(studydat1) <- gsub("^s_", "", names(studydat1))

studydat1$id <- as.factor(studydat1$id)
studydat1$list <- as.factor(studydat1$list)
studydat1$face_id <- as.factor(studydat1$face_id)
studydat1$face_gender <- as.factor(studydat1$face_gender)


# Test phase results

testdat1 <- resultsdat %>%
  subset(test_cal_time != 0 & rating_cal_time == 0) %>% # select test phase rows
  select(c("id", starts_with("t_"))) %>% # select only test phase cols
  mutate(
    t_distractor = t_distractor == "Distractor",
    t_accuracy = as.numeric(t_accuracy == "Correct"),
    t_correct_resp = ifelse(t_correct_resp == 7, "New", "Old"),
  ) %>%
  select(-t_total_correct, -t_response_button)

# Rename and rearrange columns
names(testdat1) <- gsub("^t_", "", names(testdat1))
testdat1 <- testdat1 %>%
  select(
    id, list, trial, image, face_id, face_gender, distractor, face_onset,
    correct_resp, response, rt, accuracy, resp_type
  )

testdat1$id <- as.factor(testdat1$id)
testdat1$list <- as.factor(testdat1$list)
testdat1$face_id <- as.factor(testdat1$face_id)
testdat1$face_gender <- as.factor(testdat1$face_gender)
testdat1$response <- as.factor(testdat1$response)
testdat1$correct_resp <- as.factor(testdat1$correct_resp)
testdat1$resp_type <- as.factor(testdat1$resp_type)
testdat1$trial <- testdat1$trial + 30


# Rating phase results

ratingdat1 <- resultsdat %>%
  subset(rating_cal_time != 0) %>% # select rating phase rows
  select(c("id", starts_with("r_"))) %>% # select only rating phase cols
  select(-r_face_onset, -r_rt, -r_trust, everything()) %>%
  mutate(r_distractor = r_distractor == "Distractor")

names(ratingdat1) <- gsub("^r_", "", names(ratingdat1))

ratingdat1$id <- as.factor(ratingdat1$id)
ratingdat1$list <- as.factor(ratingdat1$list)
ratingdat1$face_id <- as.factor(ratingdat1$face_id)
ratingdat1$face_gender <- as.factor(ratingdat1$face_gender)
ratingdat1$trial <- ratingdat1$trial + 90
