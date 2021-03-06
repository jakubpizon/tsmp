#' Anytime univariate SCRIMP++ algorithm
#'
#' Computes the best so far Matrix Profile and Profile Index for Univariate Time Series.
#' DISCLAIMER: This algorithm still in development by its authors.
#' Join similarity, RMP and LMP not implemented yet.
#'
#' @details
#' The Matrix Profile, has the potential to revolutionize time series data mining because of its
#' generality, versatility, simplicity and scalability. In particular it has implications for time
#' series motif discovery, time series joins, shapelet discovery (classification), density
#' estimation, semantic segmentation, visualization, rule discovery, clustering etc. The anytime
#' SCRIMP computes the Matrix Profile and Profile Index in such manner that it can be stopped before
#' its complete calculation and return the best so far results allowing ultra-fast approximate
#' solutions. `verbose` changes how much information is printed by this function; `0` means nothing,
#' `1` means text, `2` adds the progress bar, `3` adds the finish sound. `exclusion_zone` is used to
#' avoid  trivial matches.
#'
#' @param ... a `matrix` or a `vector`.
#' @param window_size an `int`. Size of the sliding window.
#' @param exclusion_zone a `numeric`. Size of the exclusion zone, based on window size (default is
#'   `1/2`). See details.
#' @param verbose an `int`. See details. (Default is `2`).
#' @param s_size a `numeric`. for anytime algorithm, represents the size (in observations) the
#'   random calculation will occur (default is `Inf`).
#' @param pre_scrimp a `numeric`. Set the pre-scrimp step based on `window_size`, if `0`, disables pre-scrimp.
#' (default is `1/4`).
#'
#' @return Returns a `MatrixProfile` object, a `list` with the matrix profile `mp`, profile index `pi`
#'   left and right matrix profile `lmp`, `rmp` and profile index `lpi`, `rpi`, window size `w` and
#'   exclusion zone `ez`.
#' @export
#'
#' @family matrix profile computations
#'
#' @references Website: <http://www.cs.ucr.edu/~eamonn/MatrixProfile.html>
#'
#' @examples
#' mp <- scrimp(mp_toy_data$data[1:200, 1], window_size = 30, verbose = 0)
#' \dontrun{
#' ref_data <- mp_toy_data$data[, 1]
#' query_data <- mp_toy_data$data[, 2]
#' # self similarity
#' mp <- scrimp(ref_data, window_size = 30, s_size = round(nrow(ref_data) * 0.1))
#' # join similarity
#' mp <- scrimp(ref_data, query_data, window_size = 30, s_size = round(nrow(query_data) * 0.1))
#' }
#' 
scrimp <- function(..., window_size, exclusion_zone = 1 / 2, verbose = 2, s_size = Inf, pre_scrimp = 1 / 4) {
  args <- list(...)
  data <- args[[1]]
  if (length(args) > 1) {
    message("Join similarity not implemented yet.")
    query <- args[[2]]
    exclusion_zone <- 0 # don't use exclusion zone for joins
  } else {
    query <- data
  }

  # transform data into matrix
  if (is.vector(data)) {
    data <- as.matrix(data)
  }
  else if (is.matrix(data)) {
    if (ncol(data) > nrow(data)) {
      data <- t(data)
    }
  } else {
    stop("Error: Unknown type of data. Must be: a column matrix or a vector.")
  }

  if (is.vector(query)) {
    query <- as.matrix(query)
  } else if (is.matrix(query)) {
    if (ncol(query) > nrow(query)) {
      query <- t(query)
    }
  } else {
    stop("Error: Unknown type of query. Must be: a column matrix or a vector.")
  }

  ez <- exclusion_zone # store original
  exclusion_zone <- round(window_size * exclusion_zone + vars()$eps)
  data_size <- nrow(data)
  query_size <- nrow(query)

  if (query_size > data_size) {
    stop("Error: Query must be smaller or the same size as reference data.")
  }
  if (window_size > query_size / 2) {
    stop("Error: Time series is too short relative to desired window size.")
  }
  if (window_size < 4) {
    stop("Error: `window_size` must be at least 4.")
  }

  matrix_profile_size <- data_size - window_size + 1
  num_queries <- query_size - window_size + 1

  # check skip position
  skip_location <- rep(FALSE, matrix_profile_size)

  for (i in 1:matrix_profile_size) {
    if (any(is.na(data[i:(i + window_size - 1)])) || any(is.infinite(data[i:(i + window_size - 1)]))) {
      skip_location[i] <- TRUE
    }
  }

  data[is.na(data)] <- 0
  data[is.infinite(data)] <- 0

  query[is.na(query)] <- 0
  query[is.infinite(query)] <- 0

  matrix_profile <- matrix(Inf, matrix_profile_size, 1)
  profile_index <- matrix(-1, matrix_profile_size, 1)

  if (length(args) > 1) {
    # no RMP and LMP for joins
    left_matrix_profile <- right_matrix_profile <- NULL
    left_profile_index <- right_profile_index <- NULL
  } else {
    left_matrix_profile <- right_matrix_profile <- matrix_profile
    left_profile_index <- right_profile_index <- profile_index
  }

  orig_index <- seq_len(matrix_profile_size)

  order <- orig_index[orig_index > (exclusion_zone + 1)]
  if (pre_scrimp > 0) {
    current_step <- floor(window_size * pre_scrimp + vars()$eps)
    pre_scrimp_idxs <- seq(2, matrix_profile_size, by = current_step)
  }
  ssize <- min(s_size, length(order))
  order <- sample(order, size = ssize)

  if (verbose > 1) {
    if (pre_scrimp > 0) {
      pb <- progress::progress_bar$new(
        format = "PRE-SCRIMP [:bar] :percent at :tick_rate it/s, elapsed: :elapsed, eta: :eta",
        clear = FALSE, total = length(pre_scrimp_idxs), width = 80
      )
    } else {
      pb <- progress::progress_bar$new(
        format = "SCRIMP [:bar] :percent at :tick_rate it/s, elapsed: :elapsed, eta: :eta",
        clear = FALSE, total = ssize, width = 80
      )
    }
  }
  if (verbose > 2) {
    on.exit(beep(sounds[[1]]), TRUE)
  }
  # anytime must return the result always
  on.exit(return({
    obj <- list(
      mp = matrix_profile, pi = profile_index,
      rmp = right_matrix_profile, rpi = right_profile_index,
      lmp = left_matrix_profile, lpi = left_profile_index,
      w = window_size,
      ez = ez
    )
    class(obj) <- "MatrixProfile"
    obj
  }), TRUE)

  pre <- mass_pre(data, data_size, query, query_size, window_size)

  tictac <- Sys.time()

  # PRE-SCRIMP ----
  if (pre_scrimp > 0) {
    # initialization
    # compute the matrix profile
    dotproduct <- matrix(0, matrix_profile_size, 1)
    refine_distance <- matrix(Inf, matrix_profile_size, 1)

    j <- 1
    for (i in pre_scrimp_idxs) {
      # compute the distance profile
      query_window <- data[i:(i + window_size - 1)]
      distance_profile <- mass(pre$data_fft, query_window, data_size, window_size, pre$data_mean, pre$data_sd, pre$query_mean[i], pre$query_sd[i])$distance_profile
      distance_profile <- abs(sqrt(distance_profile))

      # apply exclusion zone
      exc_st <- max(1, (i - exclusion_zone))
      exc_ed <- min(matrix_profile_size, (i + exclusion_zone))
      distance_profile[exc_st:exc_ed] <- Inf

      # figure out and store the neareest neighbor
      if (j == 1) {
        matrix_profile <- as.matrix(distance_profile)
        profile_index[] <- i
        min_idx <- which.min(distance_profile)
        profile_index[i] <- min_idx
        matrix_profile[i] <- distance_profile[min_idx]
        j <- j + 1
      } else {
        update_pos <- distance_profile < matrix_profile
        profile_index[update_pos] <- i
        matrix_profile[update_pos] <- distance_profile[update_pos]
        min_idx <- which.min(distance_profile)
        profile_index[i] <- min_idx
        matrix_profile[i] <- distance_profile[min_idx]
      }

      idx_nn <- profile_index[i]
      idx_diff <- idx_nn - i
      dotproduct[i] <- (window_size - matrix_profile[i]^2 / 2) * pre$data_sd[i] * pre$data_sd[idx_nn] +
        window_size * pre$data_mean[i] * pre$data_mean[idx_nn]

      endidx <- min(matrix_profile_size, (i + current_step - 1), (matrix_profile_size - idx_diff))

      dotproduct[(i + 1):endidx] <- dotproduct[i] +
        cumsum(data[(i + window_size):(endidx + window_size - 1)] *
          data[(idx_nn + window_size):(endidx + window_size - 1 + idx_diff)] -
          data[i:(endidx - 1)] * data[idx_nn:(endidx - 1 + idx_diff)])

      refine_distance[(i + 1):endidx] <-
        sqrt(abs(2 * (window_size - (dotproduct[(i + 1):endidx] - window_size * pre$data_mean[(i + 1):endidx] *
          pre$data_mean[(idx_nn + 1):(endidx + idx_diff)]) /
          (pre$data_sd[(i + 1):endidx] * pre$data_sd[(idx_nn + 1):(endidx + idx_diff)]))))

      beginidx <- max(1, (i - current_step + 1), (1 - idx_diff))

      dotproduct[(i - 1):beginidx] <- dotproduct[i] +
        cumsum(data[(i - 1):beginidx] * data[(idx_nn - 1):(beginidx + idx_diff)] -
          data[(i - 1 + window_size):(beginidx + window_size)] *
            data[(idx_nn - 1 + window_size):(beginidx + idx_diff + window_size)])

      refine_distance[beginidx:(i - 1)] <-
        sqrt(abs(2 * (window_size - (dotproduct[beginidx:(i - 1)] - window_size * pre$data_mean[beginidx:(i - 1)] *
          pre$data_mean[(beginidx + idx_diff):(idx_nn - 1)]) /
          (pre$data_sd[beginidx:(i - 1)] * pre$data_sd[(beginidx + idx_diff):(idx_nn - 1)]))))

      update_pos1 <- which(refine_distance[beginidx:endidx] < matrix_profile[beginidx:endidx])
      matrix_profile[(update_pos1 + beginidx - 1)] <- refine_distance[(update_pos1 + beginidx - 1)]
      profile_index[(update_pos1 + beginidx - 1)] <- orig_index[(update_pos1 + beginidx - 1)] + idx_diff

      update_pos2 <- which(refine_distance[beginidx:endidx] < matrix_profile[(beginidx + idx_diff):(endidx + idx_diff)])
      matrix_profile[(update_pos2 + beginidx + idx_diff - 1)] <- refine_distance[(update_pos2 + beginidx - 1)]
      profile_index[(update_pos2 + beginidx + idx_diff - 1)] <- orig_index[(update_pos2 + beginidx + idx_diff - 1)] - idx_diff

      if (verbose > 1) {
        pb$tick()
      }
    }

    if (verbose > 1) {
      pb <- progress::progress_bar$new(
        format = "SCRIMP [:bar] :percent at :tick_rate it/s, elapsed: :elapsed, eta: :eta",
        clear = FALSE, total = ssize, width = 80
      )
    }
  }
  # SCRIMP ----
  curlastz <- rep(0, num_queries)
  curdistance <- rep(0, num_queries)
  dist1 <- rep(Inf, num_queries)
  dist2 <- rep(Inf, num_queries)

  for (i in order) {
    curlastz[i] <- sum(data[1:window_size] * query[i:(i + window_size - 1)])

    curlastz[(i + 1):num_queries] <-
      curlastz[i] +
      cumsum(
        query[(i + window_size):data_size] * data[(window_size + 1):(query_size - i + 1)] # a_term
        - data[1:(num_queries - i)] * query[i:(num_queries - 1)] # m_term
      )

    curdistance[i:num_queries] <-
      sqrt(abs(2 * (window_size -
        (curlastz[i:num_queries] - # x_term
          window_size * pre$query_mean[i:num_queries] * pre$data_mean[1:(num_queries - i + 1)]) /
          (pre$query_sd[i:num_queries] * pre$data_sd[1:(num_queries - i + 1)])
      )))

    # Skip positions
    curdistance[is.na(curdistance)] <- Inf
    skipped_curdistance <- curdistance
    skipped_curdistance[pre$data_sd[i:num_queries] < vars()$eps] <- Inf
    if (skip_location[i] || any(pre$query_sd[i] < vars()$eps)) {
      skipped_curdistance[] <- Inf
    }
    skipped_curdistance[skip_location[i:num_queries]] <- Inf

    # update matrix profile
    dist1[1:(i - 1)] <- Inf
    dist1[i:num_queries] <- skipped_curdistance[i:num_queries]
    dist2[1:(num_queries - i + 1)] <- skipped_curdistance[i:num_queries]
    dist2[(num_queries - i + 2):num_queries] <- Inf

    loc1 <- (dist1 < matrix_profile)
    matrix_profile[loc1] <- dist1[loc1]
    profile_index[loc1] <- orig_index[loc1] - i + 1
    loc2 <- (dist2 < matrix_profile)
    matrix_profile[loc2] <- dist2[loc2]
    profile_index[loc2] <- orig_index[loc2] + i - 1

    if (length(args) == 1) {
      # left matrix_profile
      loc1 <- (dist1 < left_matrix_profile)
      left_matrix_profile[loc1] <- dist1[loc1]
      left_profile_index[loc1] <- orig_index[loc1] - i + 1

      # right matrix_profile
      loc2 <- (dist2 < right_matrix_profile)
      right_matrix_profile[loc2] <- dist2[loc2]
      right_profile_index[loc2] <- orig_index[loc2] + i - 1
    }

    if (verbose > 1) {
      pb$tick()
    }
  }

  tictac <- Sys.time() - tictac

  if (verbose > 0) {
    message(sprintf("Finished in %.2f %s", tictac, units(tictac)))
  }

  # return() is at on.exit() function
}
