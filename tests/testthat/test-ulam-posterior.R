# A real CmdStanR fit read from deterministic CSVs; no model compiler required.
cmdstan_fixture <- function(thin=3L, save_warmup=TRUE) {
    set.seed(314)
    samples <- 180L
    warmup <- 30L
    n <- ceiling(samples/thin) + if (save_warmup) ceiling(warmup/thin) else 0L
    files <- vapply(1:2, function(chain) {
        a <- rnorm(n) + chain/10
        values <- cbind(lp__=-a^2, accept_stat__=0.9, stepsize__=0.1,
            treedepth__=3, n_leapfrog__=7, divergent__=as.numeric(seq_len(n)==n),
            energy__=a^2+10, a=a, b=2*a+1,
            z.1.1=a, z.2.1=a+1, z.1.2=a+2, z.2.2=a+3,
            mu=a+2, log_lik.1=dnorm(0,a,1,log=TRUE),
            log_lik.2=dnorm(1,a,1,log=TRUE),
            other_ll.1=dnorm(0,a,2,log=TRUE), other_ll.2=dnorm(1,a,2,log=TRUE))
        file <- tempfile(fileext=".csv")
        writeLines(c("# stan_version_major = 2", "# stan_version_minor = 38",
            "# stan_version_patch = 0", "# model = fixture", "# method = sample",
            paste("# num_samples =",samples), paste("# num_warmup =",warmup),
            paste("# thin =",thin), paste("# save_warmup =",as.integer(save_warmup)),
            paste("# id =",chain), "# algorithm = hmc", "# engine = nuts",
            "# max_depth = 10", "# metric = diag_e"), file)
        cat(paste(colnames(values),collapse=","),"\n",file=file,append=TRUE,sep="")
        write.table(values,file,append=TRUE,sep=",",row.names=FALSE,col.names=FALSE,quote=FALSE)
        cat("# Elapsed Time: 1 seconds (Warm-up)\n# 2 seconds (Sampling)\n",file=file,append=TRUE)
        file
    },character(1))
    on.exit(unlink(files))
    fit <- cmdstanr::as_cmdstan_fit(files,check_diagnostics=FALSE)
    fit$draws(inc_warmup=save_warmup)
    fit$sampler_diagnostics(inc_warmup=save_warmup)
    fit
}

ulam_fixture <- function(native=cmdstan_fixture(), ...) {
    testthat::local_mocked_bindings(cmdstan_model=function(...) {
        list(sample=function(...) native)
    }, .package="cmdstanr")
    ulam(alist(y ~ normal(mu,1), mu <- a+b*x, c(a,b) ~ normal(0,1)),
         data=list(y=c(0,1),x=c(0,1)), cmdstan=TRUE, ...)
}

test_that("extraction selects parameters and limits joint draws across chains", {
    fit <- ulam_fixture()
    post <- extract.samples(fit,n=5)
    expect_setequal(names(post),c("a","b"))
    expect_equal(dim(post$a),c(5,1))
    expect_equal(as.numeric(post$b),2*as.numeric(post$a)+1)
    draws <- attr(fit,"cstanfit")$draws("a")
    expect_equal(as.numeric(post$a),as.vector(t(matrix(draws,ncol=2)))[1:5])
    expect_identical(names(extract.samples(fit,pars="b")),"b")
    expect_true("mu" %in% names(extract.samples(fit,clean=FALSE)))
    expect_equal(dim(extract.samples(fit,n=3,pars="z")$z),c(3,2,2))
    expect_equal(dim(extract.samples(fit,n=1000)$a),c(120,1))
    expect_error(extract.samples(fit,n=0),"positive integer")
    expect_error(extract.samples(fit,n=1.5),"positive integer")
    expect_length(extract.samples(fit,pars=character()),0)
})

test_that("parameter omission uses names and handles empty selections", {
    fit <- ulam_fixture(pars=c("a","b"),pars_omit="b")
    expect_identical(fit@pars,"a")
    expect_identical(names(extract.samples(fit)),"a")
    empty <- ulam_fixture(pars=c("a","b"),pars_omit=c("a","b"))
    expect_identical(empty@pars,character())
    expect_length(extract.samples(empty),0)
})

test_that("summaries apply display options and store actual parameter statistics", {
    fit <- ulam_fixture()
    stats <- attr(fit,"cstanfit")$summary(c("a","b"),"mean","sd")
    expect_equal(unname(fit@coef[stats$variable]),stats$mean)
    expect_equal(unname(fit@vcov[stats$variable,1]),stats$sd^2)
    expect_identical(rownames(precis(fit,omit="a")),"b")
    result <- precis(fit,sort="mean",decreasing=TRUE,digits=4)
    expect_identical(rownames(result),c("b","a"))
    expect_equal(result@digits,4)
})

test_that("predictions honor n and stop at available posterior draws", {
    fit <- ulam_fixture()
    expect_equal(dim(sim(fit,n=7)),c(7,2))
    expect_equal(dim(sim(fit)),c(120,2))
    expect_equal(dim(link(fit)),c(120,2))
})

test_that("counts, plots, and diagnostic names work with thinning and unsaved warmup", {
    fit <- ulam_fixture()
    expect_output(show(fit),"120 samples from 2 chains")
    # CSV column 2 is accept_stat__, so numeric-position lookup would be wrong.
    expect_equal(divergent(fit),2)
    expect_equal(dim(dashboard(fit,plot=FALSE)),c(60,2,6))
    path <- tempfile(fileext=".pdf")
    grDevices::pdf(path)
    on.exit({grDevices::dev.off();unlink(path)})
    expect_error(dashboard(fit),NA)
    expect_error(traceplot(fit,pars="a",ask=FALSE,trim=1),NA)
    unsaved <- ulam_fixture(cmdstan_fixture(save_warmup=FALSE))
    expect_error(traceplot(unsaved,pars="a",ask=FALSE,trim=1),NA)
    expect_output(show(unsaved),"120 samples from 2 chains")
})

test_that("PSIS forwards custom likelihood variables and LOO options", {
    fit <- ulam_fixture()
    expected <- attr(fit,"cstanfit")$loo(variables="other_ll",r_eff=FALSE)
    result <- PSIS(fit,log_lik="other_ll",r_eff=FALSE,pointwise=TRUE,warn=FALSE)
    expect_equal(result$PSIS,as.vector(expected$pointwise[,"looic"]))
    expect_equal(result$lppd,as.vector(expected$pointwise[,"elpd_loo"]))
})
