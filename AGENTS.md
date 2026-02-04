# Benchmarking protocol (SwiftSoup)

This repo uses the `SwiftSoupProfile` executable for performance checks.

## A/B comparison rules
- Always compare release builds on the same machine.
- If an optimization has a runtime flag: run with flag OFF and ON.
- If there is no flag: compare HEAD to a baseline commit in a worktree.
- Run targeted workloads 3x and report the average to reduce noise.

## Regression suite (broad coverage)
Run these in both baseline and current:
- `swift run -c release SwiftSoupProfile --workload fixtures`
- `swift run -c release SwiftSoupProfile --workload fixturesOuterHtmlNoPrettyNoSourceRanges`
- `swift run -c release SwiftSoupProfile --workload fixturesText`
- `swift run -c release SwiftSoupProfile --workload fixturesSelect`

## Targeted suite (optimization-specific)
Pick the workload most likely to stress the change and run 3x:
- Example for selector cache changes:
  - `swift run -c release SwiftSoupProfile --workload selectorCacheHeavy --iterations 1000000`

## Baseline worktree helper
- `git worktree add ../SwiftSoup-bench-base <baseline-commit>`
- Run the same commands in both trees, then compare deltas.
