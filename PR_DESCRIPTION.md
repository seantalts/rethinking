# Add an optional Stanli backend to ulam

Allow `ulam(..., backend="stanli")` to run generated Stan code through Stanli's prebuilt runtime. On systems with binary R packages, this skips CmdStan and the C++ toolchain setup. Existing backend selection remains the default; `options(rethinking.backend="stanli")` opts in for a session.

Stanli owns the compatibility interface. `stanli::cstan_model()` supplies the `$sample()` interface ulam already uses, delegates to `sample_cstan()`, and returns a native fit with draw, summary, diagnostic, and LOO methods. These adapters are included in Stanli and require no RStan. Rethinking's existing cmdstanr R-package dependency is unchanged; installing that R package alone does not install CmdStan.

The production R delta is three files, 35 lines added and 27 removed:

- `ulam-function.R` selects the model constructor at the three existing construction sites, shares the existing sampling calls, checks Stanli availability and unsupported options early, and records the backend.
- `ulam-class.R` calls the existing CmdStan-style precis helper directly. This avoids pretending Stanli has a CmdStanR class; depth continues to pass through unchanged.
- `z_extract_prior.r` preserves formula-based prior generation and forwards the inherited backend unless the caller overrides it. This avoids activating upstream's RStan refit path.

Requires [Stanli 0.14.4](https://github.com/seantalts/stanli/releases/tag/v0.14.4). The README documents binary installation and a version check because R-universe binaries can lag a release. Within-chain threading, C++ flags, custom stanc options, and `rstanout` are explicitly unsupported; `cores` still controls parallel chains.

The [benchmark and numerical comparison report](https://github.com/seantalts/stanli/blob/e27bad198713c99e7c22996b29138b08640fabab/output/pdf/rethinking-report.pdf) covers model speedups and numerical results across 61 book call sites. Timing results describe that benchmark's fixed-iteration workload, not a universal speedup or effective-sample-size guarantee.

Validation: 76 assertions pass on this branch independently of the general fixes, including exact seeded native draw/diagnostic parity, identical sampler arguments for CmdStanR and Stanli at all three constructor sites, vector/matrix/generated quantities, summaries, extraction, link, simulation, WAIC/PSIS, plots, starts, refits, prior inheritance, session options, and saved fits. One formula-dimension warning reproduces on upstream. No CmdStan model compiler is used by these tests. The isolated branch retains upstream's legacy RStan routing: use `set_ulam_cmdstan(FALSE)` to select RStan; the separate fixes PR corrects that behavior.

This branch starts directly from upstream master and does not include or require the [separate general fixes proposal](https://github.com/seantalts/rethinking/pull/1). Those fixes address existing sampling-argument and posterior-method bugs for both engines. Applying both proposals passes the 146-assertion combined suite plus 57 retained and extended Stanli assertions, including tree depth, empty controls, unsaved warmup, per-chain starts, and repaired posterior behavior. Their known upstream formula warnings remain. The backend alone preserves upstream limitations in those shared methods.

To install this fork for review, use `remotes::install_github("seantalts/rethinking@feat/ulam-stanli-backend", dependencies=NA)` in place of the upstream installation command in the README. The README is written for the proposed upstream package.

This is a review branch on seantalts/rethinking. No PR has been submitted to rmcelreath/rethinking.
