### Script for importing IDFR eyelink data into R ###

# Author: Austin Hurst


### Load required libraries ###

library(eyelinker)
library(purrr)



### Import raw EyeLink data  ###

# Get full list of .asc files and correspondings ids

ascs <- list.files(
  "../_Data", pattern = "*.asc.zip",
  full.names = TRUE, recursive = TRUE
)
#ascs <- ascs[1:6] # for testing on subset
asc_ids <- gsub(".asc.zip", "", basename(ascs))


# Actually import .asc files 

if (file.exists("eyedata.Rds")) {
  # If cached eye data already exists, load that to save time
  eyedat <- readRDS("eyedata.Rds")
} else {
  # Otherwise, import all raw .asc files and cache them
  eyedat <- lapply(ascs, function(f) {
    cat(paste0("Importing ", basename(f), "...\n"))
    read.asc(f, samples = FALSE, parse_all = TRUE)
  })
  names(eyedat) <- asc_ids
  saveRDS(eyedat, file = "eyedata.Rds")
}
