########################
## Method of moments estimators
########################

#' Simple LD Estimators
#'
#' Provides quick and simple estimates of LD and their corresponding
#' standard errors. These estimates are just based on the sample
#' moments of the genotypes or the posterior mean genotypes.
#'
#' For large sequencing depth and large n, these estimates perform as well
#' as the MLE's but are much faster to calculate. For small n and, in
#' particular, small sequencing depth, these estimates tend to be very
#' biased.
#'
#' Dprimeg is estimated using sample genotype frequencies after rounding
#' the provided genotypes to the nearest whole number. This can
#' create signifant deviations from the moment-based estimates when
#' there are a lot of fractional genotypes. Note that even when
#' all genotypes are whole numbers, Dprimeg will be slightly larger
#' (n / (n-1) times larger)
#' than it would be if it were directly estimated from Dprime. This
#' is because it is the MLE, rather than being based on the
#' UMVUE.
#'
#' @param ga Either the genotype at locus 1 or the posterior mean genotype at
#'     locus 1.
#' @param gb Either the genotype at locus 2 or the posterior mean genotype at
#'     locus 2.
#' @param K The ploidy of the species. Assumed to be the same for all
#'     individuals.
#'
#' @inherit ldest return
#'
#' @author David Gerard
#'
#' @noRd
#'
ldsimp <- function(ga, gb, K) {

  TOL <- sqrt(.Machine$double.eps)
  ## Check for monoallelic SNPs
  if ((stats::sd(ga, na.rm = TRUE) < TOL) || (stats::sd(gb, na.rm = TRUE) < TOL)) {
    retvec <- nullvec_comp(K, model = "flex") ## stupid hack. "flex" because otherwise slots for sigma and mu
    return(retvec)
  }

  n     <- length(ga)
  pA    <- mean(ga) / K
  pB    <- mean(gb) / K
  D     <- stats::cov(ga, gb) / K
  vara  <- stats::var(ga)
  varb  <- stats::var(gb)
  D_se  <- sqrt(vara * varb / K ^ 2 + D ^ 2) / sqrt(n)
  if (D < 0) {
    Dmax <- min(pA * pB, (1 - pA) * (1 - pB))
  } else {
    Dmax <- min(pA * (1 - pB), pA * (1 - pB))
  }
  Dprime <- D / Dmax
  Dprime_se <- D_se / Dmax
  r     <- stats::cor(ga, gb)
  r_se  <- (1 - r ^ 2) / sqrt(n)
  z     <- atanh(r)
  z_se  <- 1 / sqrt(n - 3)
  r2    <- r ^ 2
  r2_se <- 2 * abs(r) * (1 - r ^ 2) / sqrt(n)

  qmat <-     as.matrix(
    prop.table(
      table(factor(round(ga), levels = 0:K),
            factor(round(gb), levels = 0:K))
    )
  )

  estofdeprimeg <- Dprime(qmat = qmat, type = "geno")
  Dprimeg <- estofdeprimeg[["Dprime"]]
  Dprimeg_se <- D_se / abs(estofdeprimeg[["Dmax"]])

  qvec <- c(qmat)
  inddf <- expand.grid(i = 0:K, j = 0:K)
  names(qvec) <- paste0("q", inddf$i, inddf$j)

  retvec <- c(D          = D,
              D_se       = D_se,
              r2         = r2,
              r2_se      = r2_se,
              r          = r,
              r_se       = r_se,
              Dprime     = Dprime,
              Dprime_se  = Dprime_se,
              Dprimeg    = Dprimeg,
              Dprimeg_se = Dprimeg_se,
              z          = z,
              z_se       = z_se)
  retvec <- c(retvec, qvec, n = n)

  return(retvec)
}

#' The null return value when estimating composite LD
#'
#' @param K the ploidy of the species
#'
#' @author David Gerard
#'
#' @noRd
nullvec_comp <- function(K, model = c("norm", "flex")) {
  model <- match.arg(model)
  retvec <- c(D          = NA_real_,
              D_se       = NA_real_,
              r2         = NA_real_,
              r2_se      = NA_real_,
              r          = NA_real_,
              r_se       = NA_real_,
              Dprime     = NA_real_,
              Dprime_se  = NA_real_,
              Dprimeg    = NA_real_,
              Dprimeg_se = NA_real_,
              z          = NA_real_,
              z_se       = NA_real_)
  if (model == "norm") {
    retvec <- c(retvec,
                muA     = NA_real_,
                muB     = NA_real_,
                sigmaAA = NA_real_,
                sigmaAB = NA_real_,
                sigmaBB = NA_real_)
  }
  inddf <- expand.grid(i = 0:K, j = 0:K)
  qvec <- rep(NA_real_, length = nrow(inddf))
  names(qvec) <- paste0("q", inddf$i, inddf$j)
  retvec <- c(retvec, qvec)
  retvec <- c(retvec, n = NA_real_)
  return(retvec)
}


#' LD estimates from distribution of genotypes
#'
#'
#' @param gmat Element (i,j) is the probability of genotype i-1 at locus 1
#'     and genotype j-1 at locus 2.
#'
#' @author David Gerard
#'
#' @noRd
ld_from_gmat <- function(gmat) {
  stopifnot(ncol(gmat) == nrow(gmat))
  K <- ncol(gmat) - 1
  D <- Dfromg(gmat = gmat)
  r2 <- r2fromg(gmat = gmat)
  r <- sqrt(r2) * sign(D)
  z <- atanh(r)

  estofdprime_a <- Dprime(qmat = gmat, type = "allele", constrain = FALSE)
  Dprime <- estofdprime_a[["Dprime"]]
  Dmax <- estofdprime_a[["Dmax"]]

  estofdprime_g <- Dprime(qmat = gmat, type = "geno")
  Dprimeg <- estofdprime_g[["Dprime"]]
  Dmaxg <- estofdprime_g[["Dmax"]]

  return(c(D = D,
           r2 = r2,
           r = r,
           z = z,
           Dprime = Dprime,
           Dmax = Dmax,
           Dprimeg = Dprimeg,
           Dmaxg = Dmaxg))
}

#' LD estimates from parameterization of pbnorm
#'
#'
#' @param par A vector of length 5. The first two elements are \code{mu}. The
#'     last three elements are c(l11, l12, l22), the lower three elements of
#'     the cholesky decomposition of sigma.
#' @param K The ploidy of the species.
#'
#' @author David Gerard
#'
#' @noRd
ld_from_pbnorm <- function(par, K) {
  mu <- par[1:2]
  L <- matrix(data = c(par[3], par[4], 0, par[5]),
              nrow = 2,
              ncol = 2,
              byrow = FALSE)
  sigma <- L %*% t(L)
  distmat <- pbnorm_dist(mu = mu, sigma = sigma, K = K, log = FALSE)
  return(ld_from_gmat(gmat = distmat))
}

#' Estimates of composite pairwise LD based either on genotype estimates or
#' genotype likelihoods.
#'
#' This function will estimate the composite LD between two loci, either
#' using genotype estimates or using genotype likelihoods. The resulting
#' measures of LD are generalizations of Burrow's "composite" LD measure.
#'
#' @inheritParams ldest
#' @param useboot Should we use bootstrap standard errors \code{TRUE} or not
#'     \code{FALSE}? Only applicable if using genotype likelihoods and
#'     \code{model = "flex"}
#' @param nboot The number of bootstrap iterations to use is
#'     \code{boot = TRUE}. Only applicable if using genotype likelihoods and
#'     \code{model = "flex"}.
#' @param model Should we assume the class of joint genotype distributions
#'     is from the proportional bivariate normal (\code{model = "norm"})
#'     or from the general categorical distribution (\code{model = "flex"}).
#'     Only applicable if using genotype likelihoods.
#'
#' @inherit ldest return
#'
#' @author David Gerard
#'
#' @examples
#' set.seed(1)
#' n <- 100 # sample size
#' K <- 6 # ploidy
#'
#' ## generate some fake genotypes when LD = 0.
#' ga <- stats::rbinom(n = n, size = K, prob = 0.5)
#' gb <- stats::rbinom(n = n, size = K, prob = 0.5)
#' head(ga)
#' head(gb)
#'
#' ## generate some fake genotype likelihoods when LD = 0.
#' gamat <- t(sapply(ga, stats::dnorm, x = 0:K, sd = 1, log = TRUE))
#' gbmat <- t(sapply(gb, stats::dnorm, x = 0:K, sd = 1, log = TRUE))
#' head(gamat)
#' head(gbmat)
#'
#' ## Composite LD with genotypes
#' ldout1 <- ldest_comp(ga = ga,
#'                      gb = gb,
#'                      K = K)
#' head(ldout1)
#'
#' ## Composite LD with genotype likelihoods
#' ldout2 <- ldest_comp(ga = gamat,
#'                      gb = gbmat,
#'                      K = K,
#'                      se = FALSE,
#'                      model = "flex")
#' head(ldout2)
#'
#' ## Composite LD with genotype likelihoods and proportional bivariate normal
#' ldout3 <- ldest_comp(ga = gamat,
#'                      gb = gbmat,
#'                      K = K,
#'                      model = "norm")
#' head(ldout3)
#'
#' @export
ldest_comp <- function(ga,
                       gb,
                       K,
                       pen = 1,
                       useboot = TRUE,
                       nboot = 50,
                       se = TRUE,
                       model = c("norm", "flex")) {
  TOL <- sqrt(.Machine$double.eps)
  model <- match.arg(model)
  stopifnot(pen >= 1)
  stopifnot(is.logical(useboot))
  stopifnot(is.logical(se))
  if (is.vector(ga) & is.vector(gb)) {
    which_bad <- is.na(ga) | is.na(gb)
    ga <- ga[!which_bad]
    gb <- gb[!which_bad]
    stopifnot(length(ga) == length(gb))
    stopifnot(ga >= -TOL, ga <= K + TOL)
    stopifnot(gb >= -TOL, gb <= K + TOL)
    using <- "genotypes"
  } else if (is.matrix(ga) & is.matrix(gb)) {
    which_bad <- apply(ga, 1, function(x) any(is.na(x))) | apply(gb, 1, function(x) any(is.na(x)))
    ga <- ga[!which_bad, , drop = FALSE]
    gb <- gb[!which_bad, , drop = FALSE]
    stopifnot(dim(ga) == dim(gb))
    stopifnot(K + 1 == ncol(ga))
    using <- "likelihoods"
  } else {
    stop("ldest: ga and gb must either both be vectors or both be matrices.")
  }

  if (using == "genotypes") {
    retvec <- ldsimp(ga = ga, gb = gb, K = K)
  } else if (model == "flex") {
    alphamat <- matrix(data = pen, nrow = K + 1, ncol = K + 1)
    pma <- factor(apply(X = ga, MARGIN = 1, FUN = which.max) - 1, levels = 0:K)
    pmb <- factor(apply(X = gb, MARGIN = 1, FUN = which.max) - 1, levels = 0:K)
    pinit <- as.matrix(prop.table(table(pma, pmb) + 1))
    gout <- em_jointgeno(p = pinit,
                         pgA = ga,
                         pgB = gb,
                         alpha = alphamat)
    ld_current <- ld_from_gmat(gmat = gout)
    D <- ld_current[["D"]]
    r2 <- ld_current[["r2"]]
    r <- ld_current[["r"]]
    z <- ld_current[["z"]]
    Dprime <- ld_current[["Dprime"]]
    Dmax <- ld_current[["Dmax"]]
    Dprimeg <- ld_current[["Dprimeg"]]
    Dmaxg <- ld_current[["Dmaxg"]]

    ## get asymptotic covariance ----
    if ((useboot | any(gout < TOL)) & se) {
      rboot <- rep(NA_real_, nboot)
      dboot <- rep(NA_real_, nboot)
      r2boot <- rep(NA_real_, nboot)
      zboot <- rep(NA_real_, nboot)
      Dprimeboot <- rep(NA_real_, nboot)
      Dprimegboot <- rep(NA_real_, nboot)

      for (bindex in seq_len(nboot)) {
        ga_boot <- ga[sample(seq_len(nrow(ga)), size = nrow(ga), replace = TRUE), ]
        gb_boot <- gb[sample(seq_len(nrow(ga)), size = nrow(ga), replace = TRUE), ]
        gout_boot <- em_jointgeno(p = gout,
                                  pgA = ga_boot,
                                  pgB = gb_boot,
                                  alpha = alphamat)
        ld_current <- ld_from_gmat(gmat = gout_boot)
        dboot[[bindex]] <- ld_current[["D"]]
        r2boot[[bindex]] <- ld_current[["r2"]]
        rboot[[bindex]] <- ld_current[["r"]]
        zboot[[bindex]] <- ld_current[["z"]]
        Dprimeboot[[bindex]] <- ld_current[["Dprime"]]
        Dprimegboot[[bindex]] <- ld_current[["Dprimeg"]]
      }
      D_se <- stats::sd(dboot)
      r2_se <- stats::sd(r2boot)
      Dprime_se <- stats::sd(Dprimeboot)
      Dprimeg_se <- stats::sd(Dprimegboot)
      r_se <- stats::sd(rboot)
      z_se <- stats::sd(zboot)

    } else if (se) {
      ## MLE SE's
      Hmat <- hessian_jointgeno(p = gout, pgA = ga, pgB = gb, alpha = alphamat)
      finfo <- -solve(
        Hmat
      )
      ## Standard errors ----
      grad_dq <- dD_dqlm(p = gout)
      grad_r2q <- dr2_dqlm(p = gout, dgrad = grad_dq, D = D)
      grad_dprimeq <- ddprime_dqlm(p = gout, dgrad = grad_dq, D = D, Dm = Dmax)
      ## Delta method ----
      D_se <- sqrt(c(t(grad_dq) %*% finfo %*% grad_dq))
      r2_se <- sqrt(c(t(grad_r2q) %*% finfo %*% grad_r2q))
      Dprime_se <- sqrt(c(t(grad_dprimeq) %*% finfo %*% grad_dprimeq))
      Dprimeg_se <- D_se / Dmaxg
      r_se <- r2_se / sqrt(4 * r2)
      z_se <- r_se / (1 - r2)
    } else {
      D_se <- NA_real_
      r2_se <- NA_real_
      r_se <- NA_real_
      Dprime_se <- NA_real_
      Dprimeg_se <- NA_real_
      z_se <- NA_real_
    }

    ## set up retvec ----
    retvec <- c(D          = D,
                D_se       = D_se,
                r2         = r2,
                r2_se      = r2_se,
                r          = r,
                r_se       = r_se,
                Dprime     = Dprime,
                Dprime_se  = Dprime_se,
                Dprimeg    = Dprimeg,
                Dprimeg_se = Dprimeg_se,
                z          = z,
                z_se       = z_se)

    qvec <- c(gout)
    inddf <- expand.grid(i = 0:K, j = 0:K)
    names(qvec) <- paste0("q", inddf$i, inddf$j)
    retvec <- c(retvec, qvec)
  } else {
    postA <- exp(ga)
    postA <- postA / rowSums(postA)
    postB <- exp(gb)
    postB <- postB / rowSums(postB)
    ega <- rowSums(sweep(x = postA, MARGIN = 2, STATS = 0:K, FUN = `*`))
    egb <- rowSums(sweep(x = postB, MARGIN = 2, STATS = 0:K, FUN = `*`))
    mu_init <- c(mean(ega), mean(egb))
    sigma_init <- stats::cov(cbind(ega, egb))
    L <- t(chol(x = sigma_init))
    par <- c(mu_init, L[lower.tri(L, diag = TRUE)])

    oout <- stats::optim(par = par,
                         fn = obj_pbnorm_genolike,
                         method = "L-BFGS-B",
                         lower = c(-Inf, -Inf, 0.01, -Inf, 0.01),
                         upper = rep(Inf, 5),
                         control = list(fnscale = -1),
                         hessian = TRUE,
                         pgA = ga,
                         pgB = gb)

    mu <- oout$par[1:2]
    L[1, 1] <- oout$par[3]
    L[2, 1] <- oout$par[4]
    L[2, 2] <- oout$par[5]
    L[1, 2] <- 0
    sigma <- L %*% t(L)

    distmat <- pbnorm_dist(mu = mu, sigma = sigma, K = K, log = FALSE)

    ld_current <- ld_from_pbnorm(par = oout$par, K = K)

    D <- ld_current[["D"]]
    r2 <- ld_current[["r2"]]
    r <- ld_current[["r"]]
    z <- ld_current[["z"]]
    Dprime <- ld_current[["Dprime"]]
    Dprimeg <- ld_current[["Dprimeg"]]

    ## standard errors via numerical gradients --------------------------------
    if (se & is.finite(z)) {
      myenv <- new.env()
      assign(x = "par", value = oout$par, envir = myenv)
      assign(x = "K", value = K, envir = myenv)
      nout <- stats::numericDeriv(expr = quote(ld_from_pbnorm(par = par, K = K)),
                                  theta = "par",
                                  rho = myenv)
      gradval <- attr(nout, which = "gradient")
      rownames(gradval) <- names(ld_current)

      sevec <- sqrt(diag(gradval %*% -solve(oout$hessian) %*% t(gradval)))

      D_se <- sevec[["D"]]
      r2_se <- sevec[["r2"]]
      r_se <- sevec[["r"]]
      z_se <- sevec[["z"]]
      Dprime_se <- sevec[["Dprime"]]
      Dprimeg_se <- sevec[["Dprimeg"]]
    } else {
      D_se <- NA_real_
      r2_se <- NA_real_
      r_se <- NA_real_
      Dprime_se <- NA_real_
      Dprimeg_se <- NA_real_
      z_se <- NA_real_
    }

    ## set up retvec ----------------------------------------------------------
    retvec <- c(D          = D,
                D_se       = D_se,
                r2         = r2,
                r2_se      = r2_se,
                r          = r,
                r_se       = r_se,
                Dprime     = Dprime,
                Dprime_se  = Dprime_se,
                Dprimeg    = Dprimeg,
                Dprimeg_se = Dprimeg_se,
                z          = z,
                z_se       = z_se,
                muA        = mu[1],
                muB        = mu[2],
                sigmaAA    = sigma[1, 1],
                sigmaAB    = sigma[2, 1],
                sigmaBB    = sigma[2, 2])

    qvec <- c(distmat)
    inddf <- expand.grid(i = 0:K, j = 0:K)
    names(qvec) <- paste0("q", inddf$i, inddf$j)
    retvec <- c(retvec, qvec)
  }

  if (using == "likelihoods") { ## ldsimp() already returns n, so no need when using == "genotypes"
    retvec <- c(retvec, n = nrow(ga))
  }

  return(retvec)
}


#' Obtain D measure of LD from joint genotype frequencies.
#'
#' @param gmat Element (i, j) is the probability of gentoype i on locus 1
#'     and genotype j on locus 2.
#'
#' @author David Gerard
#'
#' @noRd
Dfromg <- function(gmat) {
  TOL <- sqrt(.Machine$double.eps)
  stopifnot(nrow(gmat) == ncol(gmat))
  stopifnot(abs(sum(gmat) - 1) < TOL)
  K <- ncol(gmat) - 1
  sum(gmat * tcrossprod(0:K)) / K -
    sum(0:K * rowSums(gmat)) * sum(0:K * colSums(gmat)) / K
}



#' Obtain r^2 measure of LD from joint genotype frequencies.
#'
#' @param gmat Element (i, j) is the probability of gentoype i on locus 1
#'     and genotype j on locus 2.
#'
#' @author David Gerard
#'
#' @noRd
r2fromg <- function(gmat) {
  stopifnot(ncol(gmat) == nrow(gmat))
  K <- ncol(gmat) - 1
  D <- Dfromg(gmat)

  distA <- rowSums(gmat)
  distB <- colSums(gmat)

  egA <- sum((0:K) * distA)
  egB <- sum((0:K) * distB)
  egA2 <- sum((0:K)^2 * distA)
  egB2 <- sum((0:K)^2 * distB)

  vargA <- egA2 - egA^2
  vargB <- egB2 - egB^2

  return(K^2 * D^2 / (vargA * vargB))
}


#' Wrapper for llike_jointgeno so that takes vector of arguments
#'
#' @param par A vector of proportions. \code{matrix(par, K+1, K+1)}
#'     should recover the probability matrix in \code{\link{em_jointgeno}()}.
#' @inheritParams em_jointgeno
#'
#' @author David Gerard
#'
#' @noRd
llike_jointgeno_vec <- function(par, pgA, pgB, alpha) {
  stopifnot(dim(pgA) == dim(pgB))
  stopifnot(length(par) == ncol(pgA)^2)
  stopifnot(dim(alpha) == rep(ncol(pgA), 2))
  pmat <- matrix(par, nrow = ncol(pgA), ncol = ncol(pgB))
  llike_jointgeno(p = pmat, pgA = pgA, pgB = pgB, alpha = alpha)
}
