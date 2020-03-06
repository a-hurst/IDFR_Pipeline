### Script for importing IDFR project into R ###

# Author: Austin Hurst


### Load required libraries ###

library(readr)
library(tidyr)
library(dplyr)



### Read face data file ###

a <- read_csv("../_Faces/facedata.csv", col_types = cols())
test_size <- c(445, 624) # size of test images (smaller than encoding images)


# Separate detector & detection confidence info

faceinfo <- a %>%
  mutate(oval_success = !is.na(oval_w), face_success = !is.na(x_0)) %>%
  select(c(
    image, img_w, img_h, detector, confidence, oval_success, face_success
  ))
faceinfo$detector <- as.factor(faceinfo$detector)



### Preprocess face landmark and oval data ###

# Add mirrored eyebrow landmarks flipped around midpoints of eyes

# First, calculate y midpoint of each eye for each participant
eye_l_cy <- (a$y_38 + a$y_38 + a$y_41 + a$y_40) / 4
eye_r_cy <- (a$y_43 + a$y_44 + a$y_47 + a$y_46) / 4

# Then, add mirrored eyebrow landmarks flipped around eye midpoints
# (mirror of point 17 == point -17, mirror of 18 == -18, etc.)
for (point in 17:26) {
  refpoint_x <- paste0("x_", as.character(point))
  refpoint_y <- paste0("y_", as.character(point))
  newpoint_x <- paste0("x_-", as.character(point))
  newpoint_y <- paste0("y_-", as.character(point))
  a[newpoint_x] <- a[refpoint_x]
  a[newpoint_y] <- a[refpoint_y] + 2 * (eye_l_cy - a[refpoint_y])
}


# Separate landmark data and convert to long format

landmarks <- a %>%
  select(c(image, img_w, img_h, starts_with("x_"), starts_with("y_")))

coord_cols <- which(grepl("^x_|^y_", names(landmarks)))
landmarks <- landmarks %>%
  gather(coord_cols, key = "coord", value = "val") %>%
  separate("coord", into = c("xy", "point"), sep = "_", convert = TRUE) %>%
  spread("xy", "val")


# Calculate landmarks for test faces based on encoding faces
# (test faces are same as encoding faces, but scaled ~75%)

test_landmarks <- landmarks %>%
  mutate(
    x = x * (test_size[1] / img_w),
    y = y * (test_size[2] / img_h),
    image = gsub("_Encoding", "_Test", image)
  )
test_landmarks$img_w <- test_size[1]
test_landmarks$img_h <- test_size[2]
landmarks <- bind_rows(landmarks, test_landmarks) 


# Separate oval data & calculate ovals for test faces

ovals <- a %>%
  select(c(image, img_w, img_h, starts_with("oval_")))
names(ovals) <- gsub("oval_", "", names(ovals))

test_ovals <- ovals %>%
  mutate(
    cx = cx * (test_size[1] / img_w),
    cy = cy * (test_size[2] / img_h),
    w = w * (test_size[1] / img_w),
    h = h * (test_size[2] / img_h),
    image = gsub("_Encoding", "_Test", image)
  )
test_ovals$img_w <- test_size[1]
test_ovals$img_h <- test_size[2]
ovals <- bind_rows(ovals, test_ovals)
