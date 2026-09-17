Add `ulam(..., backend="stanli")` using Stanli 0.14.4’s native model interface, with a session default and backend inheritance for refits and prior sampling. Binary installations can skip the C++ toolchain and CmdStan setup.

Includes installation instructions and a [model speedup and numerical comparison report](https://github.com/seantalts/stanli/blob/e27bad198713c99e7c22996b29138b08640fabab/output/pdf/rethinking-report.pdf) covering 61 book call sites.

Validation: 76 assertions pass, covering draw/diagnostic parity, backend selection, and posterior, refit, and prior workflows. One pre-existing formula warning remains.
