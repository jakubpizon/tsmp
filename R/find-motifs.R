#' Search for Motifs
#'
#' @param .mp a TSMP object of class `MatrixProfile` or `MultiMatrixProfile`.
#' @param ... further arguments to be passed to class specific function.
#' @name find_motif
#' @export

find_motif <- function(.mp, ...) {
  UseMethod("find_motif", .mp)
}

#' @param data the data used to build the Matrix Profile, if not embedded.
#' @param n_motifs an `int`. Number of motifs to find. (Default is `3`).
#' @param n_neighbors an `int`. Number of neighbors to find. (Default is `10`).
#' @param radius an `int`. Set a threshold to exclude matching neighbors with distance > current
#' motif distance * `radius`. (Default is `3`).
#' @param exclusion_zone if a `number` will be used instead of embedded value. (Default is `NULL`).
#' @name find_motif
#' @export
#' @return For class `MatrixProfile`, returns the input `.mp` object with a new name `motif`. It contains: `motif_idx`, a `list`
#' of motif pairs founded and `motif_neighbor` a `list` with respective motif's neighbors.
#' @examples
#' # Single dimension data
#' w <- 50
#' data <- mp_gait_data
#' mp <- tsmp(data, window_size = w, exclusion_zone = 1 / 4, verbose = 0)
#' mp <- find_motif(mp)
find_motif.MatrixProfile <- function(.mp, data, n_motifs = 3, n_neighbors = 10, radius = 3, exclusion_zone = NULL, ...) {
  if (!("MatrixProfile" %in% class(.mp))) {
    stop("Error: First argument must be an object of class `MatrixProfile`.")
  }

  if ("Valmod" %in% class(.mp)) {
    valmod <- TRUE
  } else {
    valmod <- FALSE
  }

  if (missing(data) && !is.null(.mp$data)) {
    data <- .mp$data[[1]]
  }

  # transform data list into matrix
  if (is.matrix(data) || is.data.frame(data)) {
    if (is.data.frame(data)) {
      data <- as.matrix(data)
    } # just to be uniform
    if (ncol(data) > nrow(data)) {
      data <- t(data)
    }
    data_len <- nrow(data)
    data_dim <- ncol(data)
  } else if (is.list(data)) {
    data_len <- length(data[[1]])
    data_dim <- length(data)

    for (i in 1:data_dim) {
      len <- length(data[[i]])
      # Fix TS size with NaN
      if (len < data_len) {
        data[[i]] <- c(data[[i]], rep(NA, data_len - len))
      }
    }
    # transform data into matrix (each column is a TS)
    data <- sapply(data, cbind)
  } else if (is.vector(data)) {
    data_len <- length(data)
    data_dim <- 1
    # transform data into 1-col matrix
    data <- as.matrix(data) # just to be uniform
  } else {
    stop("Error: `data` must be `matrix`, `data.frame`, `vector` or `list`.")
  }


  matrix_profile <- .mp$mp # keep mp intact
  matrix_profile_size <- length(matrix_profile)
  data_size <- nrow(data)
  motif_idxs <- list(motifs = list(NULL), neighbors = list(NULL), windows = list(NULL))

  if (is.null(exclusion_zone)) {
    exclusion_zone <- .mp$ez
  }

  exclusion_zone <- round(.mp$w * exclusion_zone + vars()$eps)

  if (!valmod) {
    # precompute here for classic matrix profile
    nn_pre <- mass_pre(data, data_size, window_size = .mp$w)
  }

  for (i in seq_len(n_motifs)) {
    min_idx <- which.min(matrix_profile)
    motif_distance <- matrix_profile[min_idx]
    motif_idxs[[1]][[i]] <- sort(c(min_idx, .mp$pi[min_idx]))
    motif_idx <- motif_idxs[[1]][[i]][1]

    if (valmod) {
      # precompute for each window size in valmod
      nn_pre <- mass_pre(data, data_size, window_size = .mp$w[min_idx])
      window <- .mp$w[min_idx]
      e_zone <- exclusion_zone[min_idx]
    } else {
      window <- .mp$w
      e_zone <- exclusion_zone
    }

    # query using the motif to find its neighbors
    query <- data[motif_idx:(motif_idx + window - 1)]

    distance_profile <- mass(
      nn_pre$data_fft, query, data_size, window, nn_pre$data_mean, nn_pre$data_sd,
      nn_pre$data_mean[motif_idx], nn_pre$data_sd[motif_idx]
    )

    distance_profile <- Re(distance_profile$distance_profile)

    if (valmod) {
      distance_profile <- distance_profile * sqrt(1.0 / window)
    }

    distance_profile[distance_profile > (motif_distance * radius)^2] <- Inf
    motif_zone_start <- pmax(1, motif_idx - e_zone)
    motif_zone_end <- pmin(matrix_profile_size, motif_idx + e_zone)
    distance_profile[motif_zone_start:motif_zone_end] <- Inf
    motif_idx <- motif_idxs[[1]][[i]][2]
    motif_zone_start <- pmax(1, motif_idx - e_zone)
    motif_zone_end <- pmin(matrix_profile_size, motif_idx + e_zone)
    distance_profile[motif_zone_start:motif_zone_end] <- Inf
    st <- sort(distance_profile, index.return = TRUE)
    distance_order <- st$x
    distance_idx_order <- st$ix

    motif_neighbor <- vector(mode = "numeric")

    for (j in seq_len(n_neighbors)) {
      if (is.infinite(distance_order[1]) || length(distance_order) < j) {
        break
      }
      motif_neighbor[j] <- distance_idx_order[1]
      distance_order <- distance_order[2:length(distance_order)]
      distance_idx_order <- distance_idx_order[2:length(distance_idx_order)]
      distance_order <- distance_order[!(abs(distance_idx_order - motif_neighbor[j]) < e_zone)]
      distance_idx_order <- distance_idx_order[!(abs(distance_idx_order - motif_neighbor[j]) < e_zone)]
    }

    motif_neighbor <- motif_neighbor[motif_neighbor != 0]
    motif_idxs[[2]][[i]] <- motif_neighbor
    motif_idxs[[3]][[i]] <- window

    remove_idx <- c(motif_idxs[[1]][[i]], motif_idxs[[2]][[i]])

    for (j in seq_len(length(remove_idx))) {
      remove_zone_start <- max(1, remove_idx[j] - e_zone)
      remove_zone_end <- min(matrix_profile_size, remove_idx[j] + e_zone)
      matrix_profile[remove_zone_start:remove_zone_end] <- Inf
    }
  }

  .mp$motif <- list(motif_idx = motif_idxs[[1]], motif_neighbor = motif_idxs[[2]], motif_window = motif_idxs[[3]])
  class(.mp) <- update_class(class(.mp), "Motif")
  return(.mp)
}

#' @param mode a `string`. Guided or Unconstrained search. Allow partial match. (Default is `guided`).
#' @param n_bit an `ìnt`. Bit size for discretization. Ignored on Guided search. (Default is `4`).
#' @param n_dim an `int`. Number of dimensions to use on Guided search instead of embedded value. (Default is `NULL`).
#'
#' @return For class `MultiMatrixProfile`, returns the input `.mp` object with a new name `motif`. It contains: `motif_idx`, a `vector`
#' of motifs founded and `motif_dim` a `list` the dimensions where the motifs were founded.
#'
#' @name find_motif
#' @export
#' @examples
#'
#' # Multidimension data
#' w <- mp_toy_data$sub_len
#' data <- mp_toy_data$data[1:300, ]
#' mp <- tsmp(data, window_size = w, mode = "mstomp", verbose = 0)
#' mp <- find_motif(mp)
find_motif.MultiMatrixProfile <- function(.mp, data, n_motifs = 3, mode = c("guided", "unconstrained"),
                                          n_bit = 4, exclusion_zone = NULL, n_dim = NULL, ...) {
  if (!("MultiMatrixProfile" %in% class(.mp))) {
    stop("Error: First argument must be an object of class `MultiMatrixProfile`.")
  }

  if (missing(data) && !is.null(.mp$data)) {
    data <- .mp$data[[1]]
  }

  algo <- match.arg(mode)

  # transform data list into matrix
  if (is.matrix(data) || is.data.frame(data)) {
    if (is.data.frame(data)) {
      data <- as.matrix(data)
    } # just to be uniform
    if (ncol(data) > nrow(data)) {
      data <- t(data)
    }
    data_len <- nrow(data)
    data_dim <- ncol(data)
  } else if (is.list(data)) {
    data_len <- length(data[[1]])
    data_dim <- length(data)

    for (i in 1:data_dim) {
      len <- length(data[[i]])
      # Fix TS size with NaN
      if (len < data_len) {
        data[[i]] <- c(data[[i]], rep(NA, data_len - len))
      }
    }
    # transform data into matrix (each column is a TS)
    data <- sapply(data, cbind)
  } else if (is.vector(data)) {
    data_len <- length(data)
    data_dim <- 1
    # transform data into 1-col matrix
    data <- as.matrix(data) # just to be uniform
  } else {
    stop("Error: `data` must be `matrix`, `data.frame`, `vector` or `list`.")
  }

  # Guided Search ------------------------------------------------------------------------
  if (algo == "guided") {
    if (is.null(n_dim)) {
      if (.mp$n_dim != data_dim) {
        warning("Warning: `data` dimensions are different from matrix profile.")
      }
      n_dim <- .mp$n_dim
    }

    matrix_profile <- .mp$mp[, n_dim] # keep mp intact
    profile_index <- .mp$pi[, n_dim] # keep pi intact
    motif_idx <- which.min(matrix_profile)
    motif_idx <- sort(c(motif_idx, profile_index[motif_idx]))

    motif_1 <- as.matrix(data[motif_idx[1]:(motif_idx[1] + .mp$w - 1), ]) # as.matrix(): hack for vectors
    motif_2 <- as.matrix(data[motif_idx[2]:(motif_idx[2] + .mp$w - 1), ]) # as.matrix(): hack for vectors

    motif_dim <- sort(apply(abs(motif_1 - motif_2), 2, sum), index.return = TRUE)$ix
    motif_dim <- sort(motif_dim[1:n_dim])
    motif_dim <- list(motif_dim, motif_dim)

    .mp$motif <- list(motif_idx = motif_idx, motif_dim = motif_dim)
    class(.mp) <- update_class(class(.mp), "MultiMotif")
    return(.mp)
  } else {
    # Unguided Search -------------------------------------------------------------------
    if (n_bit < 2) {
      stop("Error: `nbit` must be at least `2`.")
    }

    if (is.null(exclusion_zone)) {
      exclusion_zone <- .mp$ez
    }
    exclusion_zone <- round(exclusion_zone * .mp$w + vars()$eps)
    matrix_profile <- .mp$mp # keep mp intact

    if (.mp$n_dim != data_dim) {
      warning("Warning: `data` dimensions are different from matrix profile.")
    }

    tot_dim <- .mp$n_dim

    if (is.infinite(n_motifs)) {
      n_motifs <- dim(matrix_profile)[1]
    }

    motif_idx <- rep(0, n_motifs)
    motif_dim <- list()

    base_bit <- n_bit * tot_dim * .mp$w * 2
    found <- 0
    for (i in seq_len(n_motifs)) {
      message(sprintf("Searching for motif (%d).", i))

      idx_1 <- apply(matrix_profile, 2, which.min) # sort by column
      val <- matrix_profile[cbind(idx_1, seq_len(ncol(matrix_profile)))]

      if (any(is.infinite(val))) {
        motif_idx <- motif_idx[1:(n_motifs - 1)]
        motif_dim <- motif_dim[1:(n_motifs - 1)]
        break
      }

      bit_sz <- rep(0, tot_dim)
      idx_2 <- rep(0, tot_dim)

      dim <- list()

      for (j in seq_len(tot_dim)) {
        idx_2[j] <- .mp$pi[idx_1[j], j]
        motif_1 <- data[idx_1[j]:(idx_1[j] + .mp$w - 1), ]
        motif_2 <- data[idx_2[j]:(idx_2[j] + .mp$w - 1), ]

        bits <- get_bit_save(motif_1, motif_2, j, n_bit)

        bit_sz[j] <- bits$bit_sz
        dim[[j]] <- bits$dim_id
      }

      min_idx <- which.min(bit_sz)
      best_bit <- bit_sz[min_idx]

      if (best_bit > (base_bit)) {
        if (i == 1) {
          message("No motifs found.")
        }

        motif_idx <- motif_idx[1:(n_motifs - 1)]
        motif_dim <- motif_dim[1:(n_motifs - 1)]
        break
      } else {
        found <- found + 1
      }

      motif_idx[i] <- idx_1[min_idx]
      motif_dim[[i]] <- dim[[min_idx]]

      st_idx <- max(1, motif_idx[i] - exclusion_zone)

      ed_idx <- min((dim(matrix_profile)[1]), motif_idx[i] + exclusion_zone)

      matrix_profile[st_idx:ed_idx, ] <- Inf
    }

    if (i != 1) {
      message(sprintf("Found %d motifs.", found))
    }

    motif_dim <- motif_dim[motif_idx != 0]
    motif_idx <- motif_idx[motif_idx != 0]

    .mp$motif <- list(motif_idx = motif_idx, motif_dim = motif_dim)
    class(.mp) <- update_class(class(.mp), "MultiMotif")
    return(.mp)
  }
}
