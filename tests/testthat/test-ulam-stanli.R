# Runtime tests require Stanli's native CmdStanR-style API and its runtime.
stanli_ready <- function() {
    skip_if_not_installed("stanli", "0.14.4")
    skip_if_not(stanli::stanli_available(), "Stanli runtime is not installed")
}
normal_formula <- alist(y ~ normal(mu, 1), mu <- a + b*x, c(a,b) ~ normal(0,1))
normal_data <- list(y=c(-1.2, 0.1, 0.8, 1.9), x=c(-1, 0, 1, 2))
normal_fit <- function(...) ulam(normal_formula, data=normal_data, backend="stanli",
    chains=2, cores=2, iter=400, warmup=200, seed=71, refresh=0, ...)

test_that("code generation and backend selection do not need a sampler", {
    x <- ulam(normal_formula, data=normal_data, sample=FALSE)
    y <- ulam(normal_formula, data=normal_data, sample=FALSE, backend="stanli")
    expect_identical(x$model, y$model)
    expect_identical(x$data, y$data)
    expect_error(ulam(normal_formula, data=normal_data, backend="invalid"), "arg")
    expect_error(ulam(normal_formula, data=normal_data, backend="stanli", threads=2), "threads=1")
    expect_error(ulam(normal_formula, data=normal_data, backend="stanli", rstanout=TRUE), "rstanout")
    expect_error(ulam(normal_formula, data=normal_data, backend="stanli", cpp_fast=TRUE), "C\\+\\+")
})

test_that("the adapter preserves draws, tuning, warmup and posterior calculations", {
    stanli_ready()
    fit <- normal_fit(log_lik=TRUE, thin=3,
                      control=list(adapt_delta=0.9))
    native <- attr(fit,"cstanfit")$stanli_fit()
    model <- stanli::stanli_model(code=fit@model, data=fit@data, seed=71)
    direct <- stanli::sample_model(model, chains=2, parallel_chains=2,
        samples=200, warmup=200, seed=71, thin=3, delta=0.9, max_depth=10,
        save_warmup=TRUE, refresh=0)
    expect_identical(native$draws, direct$draws)
    expect_identical(native$sampler, direct$sampler)
    expect_equal(native$warmup_draws, 67)
    post <- extract.samples(fit)
    expect_true(all(c("a","b") %in% names(post)))
    expect_equal(dim(post$a), c(134,1))
    expect_equal(sort(as.numeric(post$a)), sort(as.numeric(direct$draws[-seq_len(67),,"a"])))
    expect_equal(unname(coef(fit)["a"]), mean(post$a))
    expect_equal(unname(vcov(fit)["a","a"]), stats::var(as.numeric(post$a)))
    expect_equal(dim(link(fit)), c(134,4))
    # Upstream sim() defaults to 1000 draws and ignores n; that separate bug
    # is not a prerequisite for backend support.
    simulation_fit <- ulam(normal_formula,data=normal_data,backend="stanli",
        chains=2,iter=1000,seed=71,refresh=0)
    expect_equal(dim(sim(simulation_fit)),c(1000,4))
    expect_equal(nrow(precis(fit,pars="a")), 1)
    expect_true(all(is.finite(unlist(WAIC(fit)))))
    expect_equal(nrow(PSIS(fit,pointwise=TRUE,warn=FALSE)), 4)
    expect_equal(divergent(fit), sum(direct$sampler[-seq_len(67),,"divergent__"]))
    expect_equal(dim(dashboard(fit,plot=FALSE)), c(67,2,6))
})

test_that("vector and matrix dimensions, selection, and generated quantities survive", {
    stanli_ready()
    fit <- ulam(alist(y ~ normal(a[g],1), gq> difference <- a[1]-a[2],
                      a[g] ~ normal(0,1), matrix[2,2]: z ~ normal(0,1)),
                data=list(y=c(0.1,1.1,0.2,0.9), g=c(1L,2L,1L,2L)),
                backend="stanli", chains=2, iter=200, seed=22, refresh=0)
    post <- extract.samples(fit)
    expect_equal(dim(post$a), c(200,2))
    expect_equal(dim(post$z), c(200,2,2))
    expect_equal(as.numeric(post$difference), post$a[,1]-post$a[,2])
})

test_that("starts, refits, options, and serialized fits work", {
    stanli_ready()
    fit <- normal_fit(start=list(a=0.2,b=0.3))
    f2 <- normal_fit(start=function(chain_id) list(a=0.2,b=0.3))
    expect_identical(attr(fit,"cstanfit")$stanli_fit()$draws, attr(f2,"cstanfit")$stanli_fit()$draws)
    path <- tempfile()
    on.exit(unlink(paste0(path,".rds")))
    saveRDS(fit,paste0(path,".rds"))
    cached <- ulam(file=path)
    expect_equal(extract.samples(cached),extract.samples(fit))
    expect_equal(precis(cached),precis(fit))
    refit <- ulam(cached, data=normal_data, chains=2, iter=100, seed=71, refresh=0)
    expect_identical(attr(refit,"backend"), "stanli")
    old <- options(rethinking.backend="stanli")
    on.exit(options(old),add=TRUE)
    expect_identical(attr(ulam(normal_formula,data=normal_data,iter=100,refresh=0),"backend"), "stanli")
    # Prior extraction must inherit the fit's backend even without an option.
    options(rethinking.backend=NULL)
    expect_setequal(names(extract.prior(fit,n=20,refresh=0)),c("a","b"))
    set.seed(42)
    seeded <- ulam(normal_formula,data=normal_data,backend="stanli",iter=100,refresh=0)
    set.seed(42)
    repeated <- ulam(normal_formula,data=normal_data,backend="stanli",iter=100,refresh=0)
    expect_identical(attr(seeded,"cstanfit")$stanli_fit()$draws,attr(repeated,"cstanfit")$stanli_fit()$draws)
})

test_that("unsupported options and invalid iteration budgets fail explicitly", {
    stanli_ready()
    expect_error(normal_fit(init=0), "complete constrained")
    expect_error(normal_fit(thin=0), "thin must")
    expect_error(normal_fit(start=list(a=0)), "b|parameter")
    expect_error(normal_fit(start=list(a=0,b=0),pathfinder_init=list()), "cannot be combined")
    expect_error(ulam(normal_formula,data=normal_data,backend="stanli",iter=10,warmup=10), "iter_sampling must")
})

test_that("trace, rank, and dashboard plots use native arrays", {
    stanli_ready()
    fit <- normal_fit()
    path <- tempfile(fileext=".pdf")
    grDevices::pdf(path)
    on.exit({grDevices::dev.off(); unlink(path)})
    expect_error(traceplot(fit,pars="a",ask=FALSE,trim=1), NA)
    expect_error(trankplot(fit,pars="a",ask=FALSE), NA)
    expect_error(dashboard(fit,plot=TRUE), NA)
})
