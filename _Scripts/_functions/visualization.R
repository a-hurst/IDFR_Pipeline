### Functions and script for plotting IDFR face data ###

# By: Austin Hurst


### Import required libraries ###

library(bmp)
library(purrr)
library(ggplot2)
library(ggforce) # for drawing ovals
library(ggpubr) # for background images



### Define functions for plotting AOIs on faces ###

#' Plots the face oval and landmark-defined areas-of-interest over top of a
#' given face image, given an image name, the landmark data, the oval data,
#' and the defined AOIs.
plot_face <- function(imagename, imagedir, landmark_dat, oval_dat, aois) {

  # Import .bmp face image
  imgpath <- paste0(imagedir, "/", imagename)
  img <- read.bmp(imgpath) / 255

  # Get oval and landmark data for face
  ov <- subset(oval_dat, image == imagename)
  z <- subset(landmark_dat, image == imagename)

  # Use landmark data to create new df of AOI points in correct sequences
  dat <- map_df(names(aois), function(aoi) {
    aoi_rows <- match(aois[[aoi]], z$point)
    df <- z[aoi_rows, ]
    df$aoi <- aoi
    df
  })

  # Plot AOIs and oval from provided data on face image
  ggplot(dat, aes(x = x, y = y, group = aoi, color = aoi, fill = aoi)) +
    background_image(img) +
    geom_ellipse(aes(
      x0 = cx, y0 = cy, a = w / 2, b = h / 2, angle = 0,
      fill = "oval", color = "oval"
    ), alpha = 0.2, data = ov, inherit.aes = FALSE) +
    geom_polygon(alpha = 0.4) +
    geom_point() +
    scale_x_continuous(expand = c(0, 0), limits = c(0, z$img_w[1])) +
    scale_y_reverse(expand = c(0, 0), limits = c(z$img_h[1], 0)) +
    coord_fixed() +
    ggtitle(imagename)

}


#' Plots the landmark-defined areas-of-interest over top of a given face image
#' from the AOI polygons created by `generate_aois()`. Does not plot the face
#' oval, which is not easily defined as a polygon.
plot_aois <- function(imagename, imagedir, aoi_dat) {

  # Import .bmp face image
  imgpath <- paste0(imagedir, "/", imagename)
  img <- read.bmp(imgpath) / 255

  # Get aoi data for face
  dat <- map_df(names(aoi_dat[[imagename]]), function(aoi) {
    df <- as.data.frame(aoi_dat[[imagename]][[aoi]][1])
    names(df) <- c("x", "y")
    df$aoi <- aoi
    df
  })

  # Plot AOIs from provided data on face image
  ggplot(dat, aes(x = x, y = y, group = aoi, color = aoi, fill = aoi)) +
    background_image(img) +
    geom_polygon(alpha = 0.4) +
    geom_point() +
    scale_x_continuous(expand = c(0, 0), limits = c(0, ncol(img))) +
    scale_y_reverse(expand = c(0, 0), limits = c(nrow(img), 0)) +
    coord_fixed() +
    ggtitle(imagename)

}


#' Plots the fixations for a given participant/trial over top of the
#' face image for that trial, colour-coding fixation points by the 
#' AOI (if any) they fall into.
plot_fix <- function(trial, id, imagedir, fixdat) {

  # Subset fixation data to id/trial of interest
  f <- fixdat[fixdat$block == trial & fixdat$id == id, ]
  imagename <- f$image[1]

  # Import .bmp face image
  imgpath <- paste0(imagedir, "/", imagename)
  img <- read.bmp(imgpath) / 255

  # Determine AOI for each fixation
  f$aoi <- ifelse(f$on_face,
    ifelse(f$on_eye_l, "eye_l",
      ifelse(f$on_eye_r, "eye_r",
        ifelse(f$on_nose, "nose",
          ifelse(f$on_nasion, "nasion",
            ifelse(f$on_mouth, "mouth", "face")
          )
        )
      )
    ),
  "none"
  )

  # Plot colour-coded fixations from provided data on face image
  ggplot(f, aes(x = axp - offset_x, y = ayp - offset_y, color = aoi)) +
    background_image(img) +
    geom_point(aes(size = dur), alpha = 0.4) +
    scale_x_continuous(expand = c(0, 0), limits = c(0, ncol(img))) +
    scale_y_reverse(expand = c(0, 0), limits = c(nrow(img), 0)) +
    coord_fixed() +
    ggtitle(imagename)

}


#' Plots the saccades for a given participant/trial over top of the
#' face image for that trial, colour-coding saccade arrows by the 
#' AOI (if any) they end in.
plot_sacc <- function(trial, id, imagedir, saccdat) {

  # Subset saccade data to id/trial of interest
  s <- saccdat[saccdat$block == trial & saccdat$id == id, ]
  imagename <- s$image[1]

  # Import .bmp face image
  imgpath <- paste0(imagedir, "/", imagename)
  img <- read.bmp(imgpath) / 255

  # Determine AOI for each saccade end
  s$aoi <- ifelse(s$end_on_face,
    ifelse(s$end_on_eye_l, "eye_l",
      ifelse(s$end_on_eye_r, "eye_r",
        ifelse(s$end_on_nose, "nose",
          ifelse(s$end_on_nasion, "nasion",
            ifelse(s$end_on_mouth, "mouth", "face")
          )
        )
      )
    ),
  "none"
  )

  # Plot colour-coded saccades from provided data on face image
  ggplot(s, aes(
    x = sxp - offset_x, y = syp - offset_y,
    xend = exp - offset_x, yend = eyp - offset_y,
    color = aoi
  )) +
    background_image(img) +
    geom_segment(arrow = arrow(), size = 1, alpha = 0.7) +
    scale_x_continuous(expand = c(0, 0), limits = c(0, ncol(img))) +
    scale_y_reverse(expand = c(0, 0), limits = c(nrow(img), 0)) +
    coord_fixed() +
    ggtitle(imagename)

}
