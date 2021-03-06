#' Plot arcs between indexes of a Profile Index
#'
#' Sometimes may be useful to see where is the nearest neighbor graphically. This is the reasoning
#' behind, for example, FLUSS which uses the arc count to infer a semantic change, and SiMPle which
#' infer that arcs connect similar segments of a music. See details for a deeper explanation how to
#' use this function.
#'
#' @details
#' You have two options to use this function. First you can provide just the data, and the function
#' will try its best to retrieve the pairs for plotting. Second, you can skip the first parameters
#' and just provide the `pairs`, which is a `matrix` with two columns; the first is the starting
#' index, the second is the end index. Two colors are used to allow you to identify the direction of
#' the arc. If you use the `rpi` or `lpi` as input, you will see that these profile indexes have
#' just one direction.
#'
#' `exclusion_zone` is used to filter out small arcs that may be useless (e.g. you may be interested
#' in similarities that are far away). `edge_limit` is used to filter out spurious arcs that are
#' used connect the beginning and the end of the profile (e.g. silent audio). `threshold` is used to
#' filter indexes that have distant nearest neighbor (e.g. retrieve only the best motifs).
#'
#' @param pairs a `matrix` with 2 columns.
#' @param alpha a `numeric`. (Default is `NULL`, automatic). Alpha value for lines transparency.
#' @param quality an `int`. (Default is `30`). Number of segments to draw the arc. Bigger value,
#'   harder to render.
#' @param lwd an `int`. (Default is `15`). Line width.
#' @param col a `vector` of colors. (Default is `c("blue", "orange")`). Colors for right and left
#'   arc, respectively. Accepts one color.
#' @param main a `string`. (Default is `"Arc Plot"`). Main title.
#' @param ylab a `string`. (Default is `""`). Y label.
#' @param xlab a `string`. (Default is `"Profile Index"`). X label.
#' @param ... further arguments to be passed to [plot()]. See [par()].
#'
#' @return None
#' @keywords hplot
#'
#' @export
#' @examples
#' plot_arcs(pairs = matrix(c(5, 10, 1, 10, 20, 5), ncol = 2, byrow = TRUE))
plot_arcs <- function(pairs, alpha = NULL, quality = 30, lwd = 15, col = c("blue", "orange"),
                      main = "Arc Plot", ylab = "", xlab = "Profile Index", ...) {
  xmin <- min(pairs)
  xmax <- max(pairs)
  max_arc <- max(abs(pairs[, 2] - pairs[, 1]))
  ymax <- (max_arc / 2 + (lwd * lwd) / 8)
  z_seq <- seq(0, base::pi, length.out = quality)
  xlim <- c(xmin, xmax)
  ylim <- c(0, ymax)

  if (is.null(alpha)) {
    alpha <- min(0.5, max(10 / nrow(pairs), 0.03))
  }

  arccolr <- grDevices::adjustcolor(col, alpha.f = alpha)
  if (length(col) > 1) {
    arccoll <- grDevices::adjustcolor(col[2], alpha.f = alpha)
  } else {
    arccoll <- grDevices::adjustcolor(col, alpha.f = alpha)
  }

  # blank plot
  graphics::plot(0.5, 0.5,
    type = "n", main = main, xlab = xlab, ylab = ylab,
    xlim = xlim, ylim = ylim, yaxt = "n", ...
  )

  for (i in seq_len(nrow(pairs))) {
    if (pairs[i, 1] > pairs[i, 2]) {
      arccol <- arccoll
    } else {
      arccol <- arccolr
    }

    x1 <- min(pairs[i, 1], pairs[i, 2])
    x2 <- max(pairs[i, 1], pairs[i, 2])
    center <- (x1 - x2) / 2 + x2
    radius <- (x2 - x1) / 2
    x_seq <- center + radius * cos(z_seq)
    y_seq <- radius * sin(z_seq)
    graphics::lines(x_seq, y_seq,
      col = arccol, lwd = lwd, lty = 1, lend = 1
    )
  }

  graphics::legend(xmin, ymax,
    legend = c("Right", "Left"),
    col = grDevices::adjustcolor(col, alpha.f = 0.5), lty = 1, cex = 0.8, lwd = 5
  )
}

#' Plot a TSMP object
#'
#' @param x a Matrix Profile
#' @param data the data used to build the Matrix Profile, if not embedded to it.
#' @param type "data" or "matrix". Choose what will be plotted.
#' @param exclusion_zone if a `number` will be used instead of Matrix Profile's. (Default is `NULL`).
#' @param edge_limit if a `number` will be used instead of Matrix Profile's exclusion zone. (Default is `NULL`).
#' @param threshold the maximum value to be used to plot.
#' @param main a `string`. Main title.
#' @param xlab a `string`. X label.
#' @param ylab a `string`. Y label.
#' @param ncol an `int`. Number of columns to plot Motifs.
#' @param ... further arguments to be passed to [plot()]. See [par()].
#'
#' @return None
#'
#' @export
#' @keywords hplot
#' @name plot
#'
#' @examples
#'
#' mp <- tsmp(mp_toy_data$data[1:200, 1], window_size = 30, verbose = 0)
#' plot(mp)
plot.ArcCount <- function(x, data, type = c("data", "matrix"), exclusion_zone = NULL, edge_limit = NULL,
                          threshold = stats::quantile(x$cac, 0.1), main = "Arcs Discover", xlab = "index",
                          ylab = "", ...) {
  def_par <- graphics::par(no.readonly = TRUE)

  if (missing(data) && !is.null(x$data)) {
    data <- x$data[[1]]
  } else {
    is.null(data) # check data presence before plotting anything
  }

  type <- match.arg(type)

  if (is.null(exclusion_zone)) {
    if (floor(x$ez * 10) < (length(x$mp) / 3)) {
      exclusion_zone <- floor(x$ez * 10)
    }
  }

  if (is.null(edge_limit)) {
    if (floor(x$ez * 10) < (length(x$mp) / 3)) {
      edge_limit <- floor(x$ez * 10)
    }
  }

  if (type == "data") {
    plot_data <- data
    data_lab <- ylab
    data_main <- "Data"
  } else {
    plot_data <- x$mp
    data_lab <- "distance"
    data_main <- "Matrix Profile"
  }

  cac <- x$cac # keep cac intact

  cac_size <- length(cac)
  pairs <- matrix(0, cac_size, 2)
  pairs[, 1] <- seq_len(cac_size)
  pairs[, 2] <- x$pi

  if (threshold < min(cac)) {
    stop(paste0("Error: `threshold` is too small for this Arc Count. Min: ", round(min(cac), 2), ", Max: ", round(max(cac), 2)))
  }

  # remove excess of arcs
  if (floor(x$w * exclusion_zone) < length(x$mp) / 3) {
    exclusion_zone <- floor(x$w * exclusion_zone)
  }
  if (floor(x$w * edge_limit) < length(x$mp) / 3) {
    edge_limit <- floor(x$w * edge_limit)
  }
  cac[1:edge_limit] <- Inf
  cac[(cac_size - edge_limit + 1):cac_size] <- Inf

  ind <- which(cac <= threshold)
  pairs <- pairs[ind, ]

  pairdiff <- pairs[, 1] - pairs[, 2]
  ind <- which(abs(pairdiff) > exclusion_zone)
  pairs <- pairs[ind, ]

  xmin <- min(pairs)
  xmax <- max(pairs)
  xlim <- c(xmin, xmax)

  graphics::layout(matrix(c(1, 2, 3), ncol = 1, byrow = TRUE))
  graphics::par(oma = c(1, 1, 3, 0), cex.lab = 1.5)
  plot_arcs(pairs, xlab = xlab, ...)
  graphics::mtext(text = main, font = 2, cex = 1.5, outer = TRUE)
  graphics::plot(x$cac, main = "Arc count", type = "l", xlab = xlab, ylab = "normalized count", xlim = xlim, ...)
  graphics::plot(plot_data, main = data_main, type = "l", xlab = xlab, ylab = data_lab, xlim = xlim, ...)

  graphics::par(def_par)
}

#' @export
#' @keywords hplot
#' @name plot
#'
plot.Valmod <- function(x, ylab = "distance", xlab = "index", main = "Valmod Matrix Profile", ...) {
  def_par <- graphics::par(no.readonly = TRUE)
  allmatrix <- FALSE

  if (!is.null(x$lmp) && !all(x$lpi == -1)) {
    allmatrix <- TRUE
  }

  if (allmatrix == TRUE) {
    graphics::layout(matrix(c(1, 2, 3), ncol = 1, byrow = TRUE))
  }
  graphics::par(
    mar = c(4.1, 4.1, 2.1, 2.1),
    oma = c(1, 1, 3, 0), cex.lab = 1.5
  )
  graphics::plot(x$mp, type = "l", main = paste0("Matrix Profile (w = ", min(x$w), "-", max(x$w), "; ez = ", x$ez, ")"), ylab = ylab, xlab = xlab, ...)
  graphics::mtext(text = main, font = 2, cex = 1.5, outer = TRUE)

  if (allmatrix == TRUE) {
    graphics::plot(x$rmp, type = "l", main = "Right Matrix Profile", ylab = ylab, xlab = xlab, ...)
    graphics::plot(x$lmp, type = "l", main = "Left Matrix Profile", ylab = ylab, xlab = xlab, ...)
  }

  graphics::par(def_par)
}

#' @export
#' @keywords hplot
#' @name plot
#'
plot.MatrixProfile <- function(x, ylab = "distance", xlab = "index", main = "Unidimensional Matrix Profile", ...) {
  def_par <- graphics::par(no.readonly = TRUE)
  allmatrix <- FALSE

  if (!is.null(x$lmp) && !all(x$lpi == -1)) {
    allmatrix <- TRUE
  }

  if (allmatrix == TRUE) {
    graphics::layout(matrix(c(1, 2, 3), ncol = 1, byrow = TRUE))
  }
  graphics::par(
    mar = c(4.1, 4.1, 2.1, 2.1),
    oma = c(1, 1, 3, 0), cex.lab = 1.5
  )
  graphics::plot(x$mp, type = "l", main = paste0("Matrix Profile (w = ", x$w, "; ez = ", x$ez, ")"), ylab = ylab, xlab = xlab, ...)
  graphics::mtext(text = main, font = 2, cex = 1.5, outer = TRUE)

  if (allmatrix == TRUE) {
    graphics::plot(x$rmp, type = "l", main = "Right Matrix Profile", ylab = ylab, xlab = xlab, ...)
    graphics::plot(x$lmp, type = "l", main = "Left Matrix Profile", ylab = ylab, xlab = xlab, ...)
  }

  graphics::par(def_par)
}

#' @export
#' @keywords hplot
#' @name plot
#'
plot.MultiMatrixProfile <- function(x, ylab = "distance", xlab = "index", main = "Multidimensional Matrix Profile", ...) {
  def_par <- graphics::par(no.readonly = TRUE)
  allmatrix <- FALSE
  n_dim <- ncol(x$mp)

  if (!is.null(x$lmp) && !all(x$lpi == -1)) {
    allmatrix <- TRUE
  }

  if (allmatrix == TRUE) {
    graphics::layout(matrix(seq_len(3 * n_dim), ncol = 3, byrow = TRUE))
  }
  graphics::par(
    mar = c(4.1, 4.1, 2.1, 2.1),
    oma = c(1, 1, 3, 0), cex.lab = 1.5
  )
  for (i in seq_len(n_dim)) {
    graphics::plot(x$mp[, i], type = "l", main = paste0("Matrix Profile (w = ", x$w, "; ez = ", x$ez, ")"), ylab = ylab, xlab = xlab, ...)
  }
  graphics::mtext(text = main, font = 2, cex = 1.5, outer = TRUE)

  if (allmatrix == TRUE) {
    for (i in seq_len(n_dim)) {
      graphics::plot(x$rmp[, i], type = "l", main = "Right Matrix Profile", ylab = ylab, xlab = xlab, ...)
    }
    for (i in seq_len(n_dim)) {
      graphics::plot(x$lmp[, i], type = "l", main = "Left Matrix Profile", ylab = ylab, xlab = xlab, ...)
    }
  }

  graphics::par(def_par)
}

#' @export
#' @keywords hplot
#' @name plot
#'
plot.SimpleMatrixProfile <- function(x, ylab = "distance", xlab = "index", main = "SiMPle Matrix Profile", ...) {
  def_par <- graphics::par(no.readonly = TRUE)
  allmatrix <- FALSE
  n_dim <- ncol(x$mp)

  if (!is.null(x$lmp) && !all(x$lpi == -1)) {
    allmatrix <- TRUE
  }

  if (allmatrix == TRUE) {
    graphics::layout(matrix(seq_len(3 * n_dim), ncol = 3, byrow = TRUE))
  }
  graphics::par(
    mar = c(4.1, 4.1, 2.1, 2.1),
    oma = c(1, 1, 3, 0), cex.lab = 1.5
  )
  for (i in seq_len(n_dim)) {
    graphics::plot(x$mp[, i], type = "l", main = paste0("Matrix Profile (w = ", x$w, "; ez = ", x$ez, ")"), ylab = ylab, xlab = xlab, ...)
  }
  graphics::mtext(text = main, font = 2, cex = 1.5, outer = TRUE)

  if (allmatrix == TRUE) {
    for (i in seq_len(n_dim)) {
      graphics::plot(x$rmp[, i], type = "l", main = "Right Matrix Profile", ylab = ylab, xlab = xlab, ...)
    }
    for (i in seq_len(n_dim)) {
      graphics::plot(x$lmp[, i], type = "l", main = "Left Matrix Profile", ylab = ylab, xlab = xlab, ...)
    }
  }

  graphics::par(def_par)
}

#' @export
#' @keywords hplot
#' @name plot
#'
plot.Fluss <- function(x, data, type = c("data", "matrix"),
                       main = "Fast Low-cost Unipotent Semantic Segmentation", xlab = "index",
                       ylab = "", ...) {
  def_par <- graphics::par(no.readonly = TRUE)

  if (missing(data) && !is.null(x$data)) {
    data <- x$data[[1]]
  } else {
    is.null(data) # check data presence before plotting anything
  }

  type <- match.arg(type)

  if (type == "data") {
    plot_data <- data
    data_lab <- ylab
    data_main <- "Data"
  } else {
    plot_data <- x$mp
    data_lab <- "distance"
    data_main <- "Matrix Profile"
  }

  fluss_idx <- sort(x$fluss)

  fluss_size <- length(fluss_idx) + 1
  pairs <- matrix(0, fluss_size, 2)

  for (i in seq_len(fluss_size)) {
    if (i == 1) {
      pairs[i, 1] <- 0
    } else {
      pairs[i, 1] <- fluss_idx[i - 1]
    }

    if (i == fluss_size) {
      pairs[i, 2] <- length(x$mp)
    } else {
      pairs[i, 2] <- fluss_idx[i]
    }
  }

  xmin <- min(pairs)
  xmax <- max(pairs)
  xlim <- c(xmin, xmax)

  graphics::layout(matrix(c(1, 2, 3), ncol = 1, byrow = TRUE))
  graphics::par(oma = c(1, 1, 3, 0), cex.lab = 1.5)
  plot_arcs(pairs, xlab = xlab, ...)
  graphics::mtext(text = main, font = 2, cex = 1.5, outer = TRUE)
  graphics::plot(plot_data, main = data_main, type = "l", xlab = xlab, ylab = data_lab, xlim = xlim, ...)
  graphics::plot(x$cac, main = "Arc count", type = "l", xlab = xlab, ylab = "normalized count", xlim = xlim, ...)

  graphics::par(def_par)
}

#' @export
#' @keywords hplot
#' @name plot
#'
plot.Chain <- function(x, data, type = c("data", "matrix"), main = "Chain Discover", xlab = "index", ylab = "", ...) {
  def_par <- graphics::par(no.readonly = TRUE)

  if (missing(data) && !is.null(x$data)) {
    data <- x$data[[1]]
  } else {
    is.null(data) # check data presence before plotting anything
  }

  type <- match.arg(type)

  if (type == "data") {
    plot_data <- data
    plot_subtitle <- "Data"
  } else {
    plot_data <- x$mp
    ylab <- "distance"
    plot_subtitle <- paste0("Matrix Profile (w = ", x$w, "; ez = ", x$ez, ")")
  }

  chain_size <- length(x$chain$best)
  pairs <- matrix(Inf, chain_size - 1, 2)
  matrix_profile_size <- nrow(x$mp)

  for (i in seq_len(chain_size - 1)) {
    pairs[i, 1] <- x$chain$best[i]
    pairs[i, 2] <- x$chain$best[i + 1]
  }

  xmin <- min(pairs)
  xmax <- max(pairs)
  xlim <- c(xmin, xmax)

  # plot matrix profile
  graphics::layout(matrix(c(1, 2, 3), ncol = 1, byrow = TRUE))
  graphics::par(oma = c(1, 1, 3, 0), cex.lab = 1.5)
  plot_arcs(pairs, xlab = xlab, ...)
  graphics::mtext(text = main, font = 2, cex = 1.5, outer = TRUE)
  graphics::plot(plot_data,
    type = "l", main = plot_subtitle,
    xlim = xlim, xlab = xlab, ylab = ylab, ...
  )
  graphics::abline(v = x$chain$best, col = 1:chain_size, lwd = 2)

  # blank plot
  motif <- znorm(data[x$chain$best[1]:min((x$chain$best[1] + x$w - 1), matrix_profile_size)])
  graphics::plot(motif,
    type = "l", main = "Motifs", xlab = "length", ylab = "normalized data",
    xlim = c(0, length(motif)), ylim = c(min(motif) - chain_size / 2, max(motif)), ...
  )

  for (i in 2:chain_size) {
    motif <- znorm(data[x$chain$best[i]:min((x$chain$best[i] + x$w - 1), matrix_profile_size)])

    graphics::lines(motif - i / 2, col = i, ...)
  }

  graphics::par(def_par)
}

#' @export
#' @keywords hplot
#' @name plot
#'
plot.Discord <- function(x, data, type = c("data", "matrix"), ncol = 3, main = "Discord Discover", xlab = "index", ylab = "", ...) {
  def_par <- graphics::par(no.readonly = TRUE)

  if (missing(data) && !is.null(x$data)) {
    data <- x$data[[1]]
  } else {
    is.null(data) # check data presence before plotting anything
  }

  type <- match.arg(type)

  if (type == "data") {
    plot_data <- data
    plot_subtitle <- "Data"
  } else {
    plot_data <- x$mp
    ylab <- "distance"
    plot_subtitle <- paste0("Matrix Profile (w = ", x$w, "; ez = ", x$ez, ")")
  }

  discords <- x$discord$discord_idx
  n_discords <- length(x$discord$discord_idx)
  neighbors <- x$discord$discord_neighbor
  matrix_profile_size <- nrow(x$mp)

  # layout: matrix profile on top, discords below.
  graphics::layout(matrix(
    c(rep(1, ncol), (seq_len(ceiling(n_discords / ncol) * ncol) + 1)),
    ceiling(n_discords / ncol) + 1,
    ncol,
    byrow = TRUE
  ))
  # plot matrix profile
  graphics::par(oma = c(1, 1, 3, 0), cex.lab = 1.5)
  graphics::plot(plot_data, type = "l", main = plot_subtitle, xlab = xlab, ylab = ylab)
  graphics::mtext(text = main, font = 2, cex = 1.5, outer = TRUE)
  graphics::abline(v = discords, col = seq_len(n_discords), lwd = 3)
  graphics::abline(v = unlist(neighbors), col = rep(seq_len(n_discords), sapply(neighbors, length)), lwd = 1, lty = 2)
  # plot discords
  for (i in 1:n_discords) {
    discord1 <- znorm(data[discords[i]:min((discords[i] + x$w - 1), matrix_profile_size)])

    # blank plot
    graphics::plot(0.5, 0.5,
      type = "n", main = paste("Discord", i), xlab = "length", ylab = "normalized data",
      xlim = c(0, length(discord1)), ylim = c(min(discord1), max(discord1))
    )

    for (j in seq_len(length(neighbors[[i]]))) {
      neigh <- znorm(data[neighbors[[i]][j]:min((neighbors[[i]][j] + x$w - 1), matrix_profile_size)])
      graphics::lines(neigh, col = "gray70", lty = 2)
    }

    graphics::lines(discord1, col = i, lwd = 2)
  }

  graphics::par(def_par)
}

#' @export
#' @keywords hplot
#' @name plot
#'
plot.Motif <- function(x, data, type = c("data", "matrix"), ncol = 3, main = "MOTIF Discover", xlab = "index", ylab = "", ...) {
  def_par <- graphics::par(no.readonly = TRUE)

  if ("Valmod" %in% class(x)) {
    valmod <- TRUE

    if (main == "MOTIF Discover") {
      main <- paste("Valmod", main)
    }
  } else {
    valmod <- FALSE
  }

  if (missing(data) && !is.null(x$data)) {
    data <- x$data[[1]]
  } else {
    is.null(data) # check data presence before plotting anything
  }

  type <- match.arg(type)

  if (type == "data") {
    plot_data <- data
    plot_subtitle <- "Data"
  } else {
    plot_data <- x$mp
    ylab <- "distance"
    if (valmod) {
      plot_subtitle <- paste0("Matrix Profile (w = ", min(x$w), "-", max(x$w), "; ez = ", x$ez, ")")
    } else {
      plot_subtitle <- paste0("Matrix Profile (w = ", min(x$w), "; ez = ", x$ez, ")")
    }
  }

  motifs <- x$motif$motif_idx
  n_motifs <- length(x$motif$motif_idx)
  neighbors <- x$motif$motif_neighbor
  windows <- unlist(x$motif$motif_window)
  matrix_profile_size <- nrow(x$mp)

  # layout: matrix profile on top, motifs below.
  graphics::layout(matrix(
    c(rep(1, ncol), (seq_len(ceiling(n_motifs / ncol) * ncol) + 1)),
    ceiling(n_motifs / ncol) + 1,
    ncol,
    byrow = TRUE
  ))
  # plot matrix profile
  graphics::par(oma = c(1, 1, 3, 0), cex.lab = 1.5)
  graphics::plot(plot_data, type = "l", main = plot_subtitle, xlab = xlab, ylab = ylab)
  graphics::mtext(text = main, font = 2, cex = 1.5, outer = TRUE)
  graphics::abline(v = unlist(motifs), col = rep(1:n_motifs, each = 2), lwd = 3)
  graphics::abline(v = unlist(neighbors), col = rep(1:n_motifs, sapply(neighbors, length)), lwd = 1, lty = 2)

  # plot motifs
  if (valmod) {
    for (i in 1:n_motifs) {
      motif1 <- znorm(data[motifs[[i]][1]:min((motifs[[i]][1] + windows[i] - 1), matrix_profile_size)])
      motif2 <- znorm(data[motifs[[i]][2]:min((motifs[[i]][2] + windows[i] - 1), matrix_profile_size)])

      # blank plot
      graphics::plot(0.5, 0.5,
        type = "n", main = paste("Motif", i), sub = paste("w = ", windows[i]), xlab = "length", ylab = "normalized data",
        xlim = c(0, length(motif1)), ylim = c(min(motif1), max(motif1))
      )

      for (j in seq_len(length(neighbors[[i]]))) {
        neigh <- znorm(data[neighbors[[i]][j]:min((neighbors[[i]][j] + windows[i] - 1), matrix_profile_size)])
        graphics::lines(neigh, col = "gray70", lty = 2)
      }

      graphics::lines(motif2, col = "black")
      graphics::lines(motif1, col = i, lwd = 2)
    }
  } else {
    for (i in 1:n_motifs) {
      motif1 <- znorm(data[motifs[[i]][1]:min((motifs[[i]][1] + x$w - 1), matrix_profile_size)])
      motif2 <- znorm(data[motifs[[i]][2]:min((motifs[[i]][2] + x$w - 1), matrix_profile_size)])

      # blank plot
      graphics::plot(0.5, 0.5,
        type = "n", main = paste("Motif", i), xlab = "length", ylab = "normalized data",
        xlim = c(0, length(motif1)), ylim = c(min(motif1), max(motif1))
      )

      for (j in seq_len(length(neighbors[[i]]))) {
        neigh <- znorm(data[neighbors[[i]][j]:min((neighbors[[i]][j] + x$w - 1), matrix_profile_size)])
        graphics::lines(neigh, col = "gray70", lty = 2)
      }

      graphics::lines(motif2, col = "black")
      graphics::lines(motif1, col = i, lwd = 2)
    }
  }

  graphics::par(def_par)
}

#' @export
#' @keywords hplot
#' @name plot
#'
plot.MultiMotif <- function(x, data, type = c("data", "matrix"), ncol = 3, main = "Multidimensional MOTIF Discover", xlab = "index", ylab = "", ...) {
  def_par <- graphics::par(no.readonly = TRUE)

  if (missing(data) && !is.null(x$data)) {
    data <- x$data[[1]]
  } else {
    is.null(data) # check data presence before plotting anything
  }

  type <- match.arg(type)

  if (type == "data") {
    plot_data <- data
    plot_subtitle <- "Data"
  } else {
    plot_data <- x$mp
    ylab <- "distance"
    plot_subtitle <- paste0("Matrix Profile ", i, " (w = ", x$w, "; ez = ", x$ez, ")")
  }

  n_dim <- x$n_dim
  motifs <- x$motif$motif_idx
  motifs_dim <- x$motif$motif_dim
  n_motifs <- length(x$motif$motif_idx)
  matrix_profile_size <- nrow(x$mp)

  dim_idx <- list()
  for (i in seq_len(n_dim)) {
    mot <- vector(mode = "numeric")
    for (j in seq_len(n_motifs)) {
      if (i %in% motifs_dim[[j]]) {
        mot <- c(mot, j)
        dim_idx[[i]] <- mot
      }
    }
  }

  # layout: matrix profile on top, motifs below.
  graphics::layout(matrix(
    c(rep(seq_len(n_dim), each = ncol), (seq_len(ceiling(n_motifs / ncol) * ncol) + n_dim)),
    # ceiling(n_motifs / ncol) + 1,
    ncol = ncol,
    byrow = TRUE
  ))
  # plot matrix profile
  graphics::par(
    mar = c(4.1, 4.1, 2.1, 2.1),
    oma = c(1, 1, 3, 0), cex.lab = 1.5
  )
  for (i in seq_len(length(dim_idx))) {
    graphics::plot(plot_data[, i],
      type = "l",
      main = plot_subtitle,
      xlab = xlab, ylab = ylab
    )

    midx <- dim_idx[[i]]
    if (!is.null(midx)) {
      graphics::abline(v = motifs[midx], col = midx, lwd = 2)
    }
  }

  graphics::mtext(text = main, font = 2, cex = 1.5, outer = TRUE)

  # plot motifs
  for (i in 1:n_motifs) {
    motif_data <- list()
    dim_len <- length(motifs_dim[[i]])
    for (j in seq_len(dim_len)) {
      motif_data[[j]] <- znorm(data[motifs[i]:min((motifs[i] + x$w - 1), matrix_profile_size), motifs_dim[[i]][j]])
    }

    # blank plot
    graphics::plot(0.5, 0.5,
      type = "n", main = paste("Motif", i), xlab = "length", ylab = "normalized data",
      xlim = c(0, length(motif_data[[1]])), ylim = c(min(unlist(motif_data)), max(unlist(motif_data)))
    )

    if (length(motif_data) > 1) {
      for (j in (seq_len(dim_len - 1) + 1)) {
        graphics::lines(motif_data[[j]], col = "gray30", lwd = 1)
      }
    }

    graphics::lines(motif_data[[1]], col = i, lwd = 2)
  }

  graphics::par(def_par)
}

#' @export
#' @keywords hplot
#' @name plot
#'

plot.Salient <- function(x, data, main = "Salient Subsections", xlab = "index", ylab = "", ...) {
  def_par <- graphics::par(no.readonly = TRUE)

  if (missing(data) && !is.null(x$data)) {
    data <- x$data[[1]]
  } else {
    is.null(data) # check data presence before plotting anything
  }

  plot_data <- data
  plot_subtitle <- "Data"
  y_min <- min(data)
  y_max <- max(data)

  mds <- salient_mds(x, data)
  idxs <- sort(x$salient$indexes[, 1])

  # layout: matrix profile on top, motifs below.
  graphics::layout(matrix(c(1, 1, 1, 0, 2, 0), ncol = 3, byrow = TRUE))
  # plot matrix profile
  graphics::par(oma = c(1, 1, 3, 0), cex.lab = 1.5)
  graphics::plot(plot_data, type = "l", main = plot_subtitle, xlab = xlab, ylab = ylab)
  graphics::mtext(text = main, font = 2, cex = 1.5, outer = TRUE)

  graphics::rect(idxs, y_min,
    xright = idxs + x$w, y_max, border = NA,
    col = grDevices::adjustcolor("blue", alpha.f = 0.1)
  )

  graphics::plot(mds, main = "MDS")

  graphics::par(def_par)
}
