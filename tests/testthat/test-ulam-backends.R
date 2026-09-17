test_that("constructor selection preserves the existing sampling calls", {
    skip_if_not_installed("stanli","0.14.4")
    calls <- list()
    make_model <- function(engine) list(sample=function(...) {
        args <- list(...)
        if (is.function(args$init)) args$init <- args$init()
        calls[[engine]] <<- args
        stop(paste("selected",engine))
    })
    testthat::local_mocked_bindings(cmdstan_model=function(...) make_model("cmdstanr"),
                                    .package="cmdstanr")
    testthat::local_mocked_bindings(cstan_model=function(...) make_model("stanli"),
                                    .package="stanli")
    f <- alist(y ~ normal(a,1), a ~ normal(0,1))
    d <- list(y=c(.1,.9))
    previous <- methods::new("ulam",call=quote(ulam()),formula=f,data=d)
    # All three model construction sites: fresh, refit, explicit starts.
    for (case in list(list(flist=f,data=d),list(flist=previous),
                      list(flist=f,data=d,start=list(a=.2)))) {
        for (engine in c("cmdstanr","stanli"))
            expect_error(do.call(ulam,c(case,list(backend=engine,iter=101,chains=2,
                cores=2,seed=11,thin=3))),paste("selected",engine))
        expect_identical(calls$stanli,calls$cmdstanr)
        expect_equal(calls$stanli$iter_warmup,50)
        expect_equal(calls$stanli$iter_sampling,51)
    }
    old <- options(rethinking.backend="stanli")
    on.exit(options(old),add=TRUE)
    expect_error(ulam(f,data=d,cmdstan=TRUE),"selected cmdstanr")
    expect_error(ulam(f,data=d,backend="cmdstanr"),"selected cmdstanr")
    expect_error(ulam(f,data=d),"selected stanli")
})
