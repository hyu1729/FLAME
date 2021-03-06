n <- 250
p <- 5
data <- gen_data(n = n, p = p)
holdout <- gen_data(n = n, p = p)
flout_not_0_ind <- FLAME(data, holdout, C = 1e5)

mapping <- as.character(c(1, 2, 3, 4))
names(mapping) <- as.character(c(0, 1, 2, 3))
mapping <- rep(list(mapping), p)

data_0_ind <- factor_remap(data, mapping = mapping)$df
holdout_0_ind <- factor_remap(holdout, mapping = mapping)$df

flout_0_ind <- FLAME(data_0_ind, holdout_0_ind, C = 1e5)

test_that("non 0 indexed factors work", {
  expect_identical(flout_not_0_ind$MGs, flout_0_ind$MGs)
})

test_that("non consecutive-level factors work", {
  mapping <- as.character(c(1, 2, 3, 4))
  names(mapping) <- as.character(c(1, 3, 5, 8))
  mapping <- rep(list(mapping), p)

  data_non_consec <- factor_remap(data, mapping = mapping)$df
  holdout_non_consec <- factor_remap(holdout, mapping = mapping)$df

  flout_non_consec <- FLAME(data_non_consec, holdout_non_consec, C = 1e5)
  expect_identical(flout_non_consec$MGs, flout_0_ind$MGs)
})


test_that("non numeric factors work", {
  mapping <- as.character(c(1, 2, 3, 4))
  names(mapping) <- c('white', 'hispanic', 'black', 'asian')
  mapping <- rep(list(mapping), p)

  data_non_num <- factor_remap(data, mapping = mapping)$df
  holdout_non_num <- factor_remap(holdout, mapping = mapping)$df

  flout_non_num <- FLAME(data_non_num, holdout_non_num, C = 1e5)
  expect_identical(flout_non_num$MGs, flout_0_ind$MGs)
})

test_that("missing data 3 doesn't leave new levels", {
  mapping <- as.character(c(1, 2, 3, 4))
  names(mapping) <- c('white', 'hispanic', 'black', 'asian')
  mapping <- rep(list(mapping), p)

  data_non_num <- factor_remap(data, mapping = mapping)$df
  holdout_non_num <- factor_remap(holdout, mapping = mapping)$df

  levels_in <- lapply(data_non_num[, 1:p], levels)
  for (i in 1:p) {
    data_non_num[[i]][sample(1:n, 10)] <- NA
  }
  flout <- FLAME(data_non_num, holdout_non_num, missing_data = 3)
  levels_out <- lapply(flout$data[, 1:p], levels)
  for (j in 1:p) {
    expect_equivalent(sort(levels_out[[j]]), sort(c(levels_in[[j]], '*')))
  }
})







