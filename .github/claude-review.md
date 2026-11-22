# Cloud code review brief

What this repository is, and what to watch for in it. Everything else — what PR
context is available, how to post a review, what makes a finding worth raising,
comment hygiene, PR-description shape, the versioning mechanism — comes from the
review workflow's runtime notes. Don't restate it here: this file is read first,
so a stale copy would silently override the current text.

Not loaded by local Claude Code; only the cloud reviewer reads this.

## What this repo is

`ghul-test` is the snapshot-based integration test runner the compiler's own suite
runs on, published as the `ghul.test` NuGet package and invoked as `dotnet
ghul-test`. It walks a directory tree, treats any directory holding a `test.json`
file as a test, compiles and runs it, and diffs actual output against `*.expected`
snapshots. Written in ghūl.

Blast radius is the compiler's entire test signal: a runner bug that swallows a
mismatch turns every downstream suite green when it should not be.

## What to watch for here

- **Wrong verdicts**, especially false passes. A swallowed exception, a comparison
  returning early, a missing snapshot treated as a match. A false pass is far worse
  than a false failure, because nothing downstream will catch it.
- **Test discovery.** Changes to how directories are recognised as tests, or how
  subdirectories are walked, can silently shrink the suite - a test that stops
  being found reports nothing at all.
- **Exit codes and reporting.** CI keys off the process exit code. Progress
  reporting writes to `$XDG_RUNTIME_DIR/ghul-test/<pid>.json`, and a reporter
  failure must stay suppressed rather than failing the run.
- **Parallelism.** Tests run concurrently: flag shared mutable state, and any file
  written to a path not keyed by process or test.

## Versioning

`ghul.test` is consumed by the compiler's CI, so a change to its command line,
exit codes or snapshot semantics is breaking. Major means a changed CLI contract
or snapshot format; minor means new flags or new expectation file kinds.
