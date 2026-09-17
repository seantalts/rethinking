# Add an optional Stanli backend to ulam

Add `ulam(..., backend="stanli")` and a session default through `options(rethinking.backend="stanli")`. Stanli runs generated Stan code through a prebuilt runtime, allowing users with binary R packages to skip the C++ toolchain and CmdStan installation. Requires [Stanli 0.14.4](https://github.com/seantalts/stanli/releases/tag/v0.14.4).

The production R diff touches three files: **36 lines added, 3 removed**. It selects `stanli::cstan_model()` at the existing model construction sites, calls the existing precis helper for the native fit, and preserves backend selection for refits and prior sampling. Existing CmdStan constructors, sampling calls, and package dependencies stay in place. Within-chain threading, compiler flags, and `rstanout` are rejected for Stanli; parallel chains use `cores`.

The README adds binary setup instructions and links the [benchmark and numerical comparison report](https://github.com/seantalts/stanli/blob/e27bad198713c99e7c22996b29138b08640fabab/output/pdf/rethinking-report.pdf), covering 61 book call sites. Platform availability is documented in Stanli's installation guide.

Validation: **76 assertions pass**, including identical sampler arguments across both backends at all three construction sites, exact seeded native draw/diagnostic parity, posterior methods, starts, refits, prior inheritance and overrides, and saved fits. One existing formula-dimension warning reproduces on upstream.

This branch starts directly from upstream master. [General sampling and posterior fixes](https://github.com/seantalts/rethinking/pull/1) are separate and are not required for Stanli support. Existing shared limitations remain, including legacy RStan selection through `set_ulam_cmdstan(FALSE)`.

For fork review, replace the upstream installation with `remotes::install_github("seantalts/rethinking@feat/ulam-stanli-backend", dependencies=NA)`. No PR has been submitted to upstream rethinking.
