test_that("RStan selection honors starts and regenerates refit and prior code", {
    skip_if_not_installed("rstan")
    calls <- list()
    testthat::local_mocked_bindings(stan=function(...) {
        args <- list(...)
        calls[[length(calls)+1L]] <<- args
        stop("selected RStan")
    }, .package="rstan")
    f <- alist(y ~ normal(a,1), a ~ normal(0,1))
    d <- list(y=c(0.1,0.9))
    expect_error(ulam(f,data=d,cmdstan=FALSE,start=list(a=0.2)),"selected RStan")
    expect_identical(calls[[1]]$init(),list(a=0.2))
    previous <- methods::new("ulam",call=quote(ulam()),formula=f,data=d)
    expect_error(ulam(previous,cmdstan=FALSE,sample_prior=TRUE),"selected RStan")
    expect_true("model_code" %in% names(calls[[2]]))
    expect_false("fit" %in% names(calls[[2]]))
    expect_false(grepl("y ~",calls[[2]]$model_code,fixed=TRUE))
    code <- ulam(f,data=d,sample=FALSE)$model
    compiled <- methods::new(methods::getClass("stanmodel",where=asNamespace("rstan")),
                             model_code=trimws(code))
    attr(previous,"stanfit") <- methods::new(methods::getClass("stanfit",where=asNamespace("rstan")),
                                            stanmodel=compiled,mode=2L)
    expect_error(ulam(previous,cmdstan=FALSE),"selected RStan")
    expect_identical(calls[[3]]$fit,attr(previous,"stanfit"))
    expect_false("model_code" %in% names(calls[[3]]))
})


test_that("RStan duration lookup does not require an attached package", {
    skip_if_not_installed("rstan")
    testthat::local_mocked_bindings(get_elapsed_time=function(object) {
        matrix(c(1,2,3,4),nrow=2,dimnames=list(NULL,c("warmup","sample")))
    },.package="rstan")
    fit <- methods::new(methods::getClass("stanfit",where=asNamespace("rstan")),mode=2L)
    expect_equal(unname(stan_sampling_duration(fit)[,3]),c(4,6))
})

test_that("RStan accepts per-chain starts without wrapping them in a function", {
    skip_if_not_installed("rstan")
    seen <- NULL
    testthat::local_mocked_bindings(stan=function(...) {
        seen <<- list(...)
        stop("selected RStan")
    },.package="rstan")
    starts <- list(list(a=.1),list(a=.2))
    expect_error(ulam(alist(y ~ normal(a,1), a ~ normal(0,1)),
        data=list(y=c(.1,.9)),cmdstan=FALSE,chains=2,start=starts),"selected RStan")
    expect_identical(seen$init,starts)
})
