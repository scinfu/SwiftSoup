# Benchmarking & profiling protocol (SwiftSoup)

This repo’s current performance harness is the `BenchmarkProfileTest/testParseBenchmarkProfile` test. It is driven by
environment variables and runs in a release test build.

## A/B comparison rules
- Always compare release builds on the same machine.
- If an optimization has a flag: run OFF vs ON.
- If no flag: compare HEAD to a baseline commit in a worktree.
- Test each optimization in isolation before any combined run.
- Record commit SHAs, flags, iterations, and the exact command lines used.

## Common benchmark knobs (env vars)
- `SWIFTSOUP_BENCHMARK=1` (enable the benchmark test)
- `SWIFTSOUP_BENCHMARK_SET=...` (comma-separated workload sets)
- `SWIFTSOUP_BENCHMARK_WARMUP=2`
- `SWIFTSOUP_BENCHMARK_ITERATIONS=500`
- `SWIFTSOUP_BENCHMARK_ITERATIONS_MULTIPLIER=1`
- `SWIFTSOUP_BENCHMARK_REPEAT=200` (base set)
- `SWIFTSOUP_BENCHMARK_LARGE_REPEAT=60` (large set)
- `SWIFTSOUP_BENCHMARK_SELECTOR_REPEAT=1`
- `SWIFTSOUP_BENCHMARK_SELECTOR_STRESS_REPEAT=1`
- `SWIFTSOUP_BENCHMARK_ATTRIBUTE_SELECTOR_STRESS_REPEAT=1`

## Regression suite (broad coverage)
Run in both baseline and current (exact command line):
```
SWIFTSOUP_BENCHMARK=1 \
SWIFTSOUP_BENCHMARK_SET=base,large \
SWIFTSOUP_BENCHMARK_REPEAT=200 \
SWIFTSOUP_BENCHMARK_LARGE_REPEAT=60 \
SWIFTSOUP_BENCHMARK_WARMUP=2 \
SWIFTSOUP_BENCHMARK_ITERATIONS=500 \
SWIFTSOUP_BENCHMARK_ITERATIONS_MULTIPLIER=1 \
SWIFTSOUP_BENCHMARK_SELECTOR_REPEAT=1 \
SWIFTSOUP_BENCHMARK_SELECTOR_STRESS_REPEAT=1 \
SWIFTSOUP_BENCHMARK_ATTRIBUTE_SELECTOR_STRESS_REPEAT=1 \
swift test -c release --filter BenchmarkProfileTest/testParseBenchmarkProfile
```

## Targeted suite (optimization-specific)
Pick the workload set that stresses the change and run with the same flags:
```
SWIFTSOUP_BENCHMARK=1 \
SWIFTSOUP_BENCHMARK_SET=attribute-heavy,attribute-mega,attribute-storm,data-heavy,data-storm,tag-heavy,custom-tag,dense-text,querystring \
SWIFTSOUP_BENCHMARK_WARMUP=2 \
SWIFTSOUP_BENCHMARK_ITERATIONS=500 \
SWIFTSOUP_BENCHMARK_ITERATIONS_MULTIPLIER=1 \
SWIFTSOUP_BENCHMARK_SELECTOR_REPEAT=1 \
SWIFTSOUP_BENCHMARK_SELECTOR_STRESS_REPEAT=1 \
SWIFTSOUP_BENCHMARK_ATTRIBUTE_SELECTOR_STRESS_REPEAT=1 \
swift test -c release --filter BenchmarkProfileTest/testParseBenchmarkProfile
```

## Baseline worktree helper
- `git worktree add ../SwiftSoup-bench-base <baseline-commit>`
- Run the same commands in both trees; compare the “Benchmark elapsed: … ms over N iterations” line.
- Use `git rev-parse HEAD` to log the commit for each side.

## Profiling
- Use Instruments (Time Profiler) on the `SwiftSoupPackageTests.xctest` process while running the same benchmark test
  filter and env vars.
- Always profile release builds and keep the workload set identical to the benchmark run you are comparing against.
