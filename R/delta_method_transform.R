




.acosh_trans_impl <- function(x, alpha){
  1/sqrt(alpha) * acoshp1(2 * alpha * x)
}

.sqrt_trans_impl <- function(x){
  2 * sqrt(x)
}


#' Delta method-based variance stabilizing transformation
#'
#'
#' @inherit transformGamPoi
#' @param pseudo_count instead of specifying the overdispersion, the
#'   `shifted_log_transform` is commonly parameterized with a pseudo-count
#'   (\eqn{pseudo-count = 1/(4 * overdispersion)}). If both the `pseudo-count`
#'   and `overdispersion` is specified, the `overdispersion` is ignored.
#'   Default: `1/(4 * overdispersion)`
#' @param minimum_overdispersion the `acosh_transform` converges against
#'   \eqn{2 * sqrt(x)} for `overdispersion == 0`. However, the `shifted_log_transform`
#'   would just become `0`, thus here we apply the `minimum_overdispersion` to avoid
#'   this behavior.
#'
#' @describeIn  acosh_transform \eqn{1/sqrt(alpha)} acosh(2 * alpha * x + 1)
#'
#' @return a matrix with transformed values
#'
#' @export
acosh_transform <- function(data, overdispersion = 0.05,
                            size_factors = TRUE,
                            on_disk = NULL,
                            verbose = FALSE){

  counts <- .handle_data_parameter(data, on_disk, allow_sparse = TRUE)

  if(inherits(data, "glmGamPoi")){
    size_factors <- data$size_factors
  }else{
    size_factors <- .handle_size_factors(size_factors, counts)
  }

  if(all(isTRUE(overdispersion)) || all(overdispersion == "global")){
    fit <- glmGamPoi::glm_gp(counts, design = ~ 1, size_factors = size_factors,
                             overdispersion = TRUE,
                             overdispersion_shrinkage = FALSE,
                             verbose = verbose)
    overdispersion <- fit$overdispersions
  }else{
    overdispersion <- .handle_overdispersion(overdispersion, counts)
  }

  norm_counts <- DelayedArray::sweep(counts, 2, size_factors, FUN = "/")

  overdispersion_near_zero <- .near(overdispersion, 0)

  result <- if(! any(overdispersion_near_zero)){
    # no overdispersion is zero
    .acosh_trans_impl(norm_counts, overdispersion)
  }else if(all(overdispersion_near_zero)){
    # all overdispersion is zero
    .sqrt_trans_impl(norm_counts)
  }else{
    # overdispersion is a mix of zeros and other values.
    if(is.matrix(overdispersion)){
      norm_counts[overdispersion_near_zero] <- .sqrt_trans_impl(norm_counts[overdispersion_near_zero])
      norm_counts[!overdispersion_near_zero] <- .acosh_trans_impl(norm_counts[!overdispersion_near_zero],
                                                                  overdispersion[! overdispersion_near_zero])
      norm_counts
    }else{
      norm_counts[overdispersion_near_zero, ] <- .sqrt_trans_impl(norm_counts[overdispersion_near_zero, ])
      norm_counts[!overdispersion_near_zero, ] <- .acosh_trans_impl(norm_counts[!overdispersion_near_zero, ],
                                                                    overdispersion[! overdispersion_near_zero])
      norm_counts
    }
  }

  .convert_to_output(result, data)
}



.log_plus_alpha_impl <- function(x, alpha){
  1/sqrt(alpha) * log1p(4 * alpha * x)
}


#' @describeIn acosh_transform \eqn{1/sqrt(alpha) log(4 * alpha * x + 1)}
shifted_log_transform <- function(data, overdispersion = 0.05, pseudo_count = 1/(4 * overdispersion),
                                  size_factors = TRUE, minimum_overdispersion = 0.001, on_disk = NULL, verbose = FALSE){

  counts <- .handle_data_parameter(data, on_disk, allow_sparse = TRUE)

  if(inherits(data, "glmGamPoi")){
    size_factors <- data$size_factors
  }else{
    size_factors <- .handle_size_factors(size_factors, counts)
  }

  if(all(isTRUE(overdispersion)) || all(overdispersion == "global")){
    fit <- glmGamPoi::glm_gp(counts, design = ~ 1, size_factors = size_factors,
                             overdispersion = TRUE,
                             overdispersion_shrinkage = FALSE,
                             verbose = verbose)
    data <- fit
    overdispersion <- fit$overdispersions
  }else{
    overdispersion <- 1/(4 * pseudo_count)
    overdispersion <- .handle_overdispersion(overdispersion, counts)
  }




  norm_counts <- DelayedArray::sweep(counts, 2, size_factors, FUN = "/")

  overdispersion[overdispersion < minimum_overdispersion] <- minimum_overdispersion

  result <- .log_plus_alpha_impl(norm_counts, overdispersion)
  .convert_to_output(result, data)
}




.convert_to_output <- function(result, data){
  if(is.vector(data)){
    as.vector(result)
  }else{
    result
  }
}


.near <- function (x, y, tol = .Machine$double.eps^0.5){
  abs(x - y) < tol
}