### Functions for working with AOIs for the IDFR project ###

# By: Austin Hurst


### Import required libraries ###

library(tibble)
library(sf)



### Define functions for generating AOIs from landmarks ###

generate_aois <- function(images, landmark_dat, aois, colname = "image") {

  out <- list()
  for (img in images) {

    # Get landmark data for face
    z <- landmark_dat[landmark_dat[colname] == img, ]

    # Get named polygon for each defined AOI
    aoi_list <- lapply(names(aois), function(aoi) {
      aoi_rows <- z[match(aois[[aoi]], z$point), ]
      st_polygon(list(cbind(aoi_rows$x, aoi_rows$y)))
    })
    names(aoi_list) <- names(aois)
    out[[as.character(img)]] <- st_sfc(aoi_list)
  }
  out
}



### Define functions for checking if points are within AOIs ###

in_ellipse <- function(x, y, cx, cy, w, h) {
  # Tests whether the point (x, y) is within the ellipse defined by
  # cx, cy (center coordinates) and w, h (height and width)
  rx <- w / 2
  ry <- h / 2
  ( (x - cx) ** 2 / (rx ** 2) ) + ( (y - cy) ** 2 / (ry ** 2) ) <= 1
}

point_on_aois <- function(x, y, image, aois) {

  # NA coordinates break st_intersects, so we replace them w/ -1 here
  x[is.na(x)] <- -1
  y[is.na(y)] <- -1

  # Gather input coords in to sf points and test against AOIs
  out <- matrix(FALSE, nrow = length(x), ncol = length(aois[[1]]))
  points <- st_as_sf(data.frame(x = x, y = y), coords = c("x", "y"))
  for (img in unique(image)) {
    img_rows <- image == img
    out[img_rows, ] <- t(st_intersects(
      aois[[img]], points[img_rows, ], sparse = FALSE
    ))
  }

  # Convert output matrix to tibble and name columns based on AOIs
  out <- as_tibble(out, .name_repair = "minimal")
  names(out) <- paste0("on_", names(aois[[1]]))
  out
}
