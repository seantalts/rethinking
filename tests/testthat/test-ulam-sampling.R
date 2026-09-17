test_that("shared CmdStan sampling options preserve tuning, warmup and starts", {
    calls <- list()
    testthat::local_mocked_bindings(cmdstan_model=function(...) {
        list(sample=function(...) {
            calls[[length(calls)+1L]] <<- list(...)
            stop("sample called")
        })
    }, .package="cmdstanr")
    f <- alist(y ~ normal(a,1), a ~ normal(0,1))
    d <- list(y=c(.1,.9))
    run <- function(...) ulam(f,data=d,cmdstan=TRUE,...)
    expect_error(run(iter=101,cores=2,control=list(adapt_delta=.9,max_treedepth=8),
        thin=3,save_warmup=FALSE,seed=11),"sample called")
    args <- calls[[1]]
    expect_equal(args[c("iter_warmup","iter_sampling","parallel_chains","adapt_delta",
                        "max_treedepth","thin","save_warmup","seed")],
        list(iter_warmup=50,iter_sampling=51,parallel_chains=2,adapt_delta=.9,
             max_treedepth=8,thin=3,save_warmup=FALSE,seed=11))
    for (control in list(NULL,list(),list(adapt_delta=NULL))) {
        expect_error(run(control=control),"sample called")
        expect_equal(tail(calls,1)[[1]]$adapt_delta,.95)
    }
    starts <- list(list(a=.1),list(a=.2))
    expect_error(run(chains=2,start=starts),"sample called")
    expect_identical(tail(calls,1)[[1]]$init,starts)
    expect_error(run(control=list(max_treedepth=8),max_treedepth=9),"Conflicting")
    expect_error(run(start=list(a=0),init=list(a=1)),"Conflicting")
    expect_error(run(seed=1,seed=2),"uniquely named")
    expect_error(run(control=list(.9)),"uniquely named")
})

test_that("translated sampling arguments cannot be overridden accidentally", {
    f <- alist(y ~ normal(a,1), a ~ normal(0,1))
    d <- list(y=c(.1,.9))
    expect_error(ulam(f,data=d,cmdstan=TRUE,parallel_chains=3),"Conflicting sampling")
    expect_error(ulam(f,data=d,cmdstan=TRUE,control=list(iter_sampling=5)),"Conflicting sampling")
})
