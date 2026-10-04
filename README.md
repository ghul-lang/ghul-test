# ghūl compiler integration test runner

[![CI/CD](https://img.shields.io/github/actions/workflow/status/ghul-lang/ghul-test/cicd.yml?branch=main)](https://github.com/ghul-lang/ghul-test/actions?query=workflow%3ACICD+branch%3Amain)
[![NuGet version (ghul.test)](https://img.shields.io/nuget/v/ghul.test.svg)](https://www.nuget.org/packages/ghul.test/)
[![Release](https://img.shields.io/github/v/release/ghul-lang/ghul-test?label=release)](https://github.com/ghul-lang/ghul-test/releases)
[![Release Date](https://img.shields.io/github/release-date/ghul-lang/ghul-test)](https://github.com/ghul-lang/ghul-test/releases)
[![Issues](https://img.shields.io/github/issues-search/ghul-lang/ghul?query=is%3Aopen%20is%3Aissue%20label%3Aghul-test&label=issues)](https://github.com/ghul-lang/ghul/issues?q=is%3Aopen+is%3Aissue+label%3Aghul-test) 
[![License](https://img.shields.io/github/license/ghul-lang/ghul-test)](https://github.com/ghul-lang/ghul-test/blob/main/LICENSE)
[![ghūl](https://img.shields.io/badge/gh%C5%ABl-100%25!-information)](https://ghul.dev)

This is a very simple snapshot based test runner which is used by the [ghūl programming language](https://ghul.dev) [compiler](https://github.com/degory/ghul) [integration tests](https://github.com/degory/ghul/tree/master/integration-tests). It compares test expectations, in the form of snapshot text files, against the actual outputs of the compiler and test executables and flags any differences.

## Test Folder Structure

A test directory must contain at least two things:

- **One or more `.ghul` source files** – the sources to compile.
- A `ghulflags` file – flags passed directly to the compiler when building the test.

Any directory containing a `ghulflags` file is treated as a test. A directory without one is not run, so one that looks like a test anyway - it holds a `test.ghul`, or an `*.expected` snapshot - is named at the end of the run and fails it, rather than passing unnoticed. Other directories without a `ghulflags` file, such as a library a test builds against, are ignored.

Optional expectation and configuration files may also be present:

| File | Purpose |
| --- | --- |
| `fail.expected` | If present, the build is expected to fail. Its mere presence enables this behaviour; the file contents are ignored. |
| `err.expected` | Expected compiler error output. Actual errors are extracted from `compiler.out`, sorted, and diffed against this file. |
| `warn.expected` | Expected compiler warning output. Warnings undergo the same grep and sort process as errors. |
| `run.expected` | Expected stdout from running the compiled binary. |
| `run.in` | Written to the program's standard input, which is closed once it has been sent. Without it the program inherits the runner's own standard input. A program that reads to end of input needs the close, so a test driving an interactive program supplies the whole session here and snapshots the transcript in `run.expected`. Sent to the formatted binary too, where a `format.expected` makes one. |
| `run.args` | The command line the program is run with, one argument a line, so an argument containing spaces is still one argument. Without it the program runs with no arguments. Passed to the formatted binary too, where a `format.expected` makes one. |
| `run.exit.expected` | The exit status the program is expected to end with, for a test whose subject is failing. Without it any non-zero status fails the test. The status an unhandled exception produces is the runtime's rather than the program's, so a test that asserts one is asserting what this platform's runtime does with it. |
| `run.err.expected` | Expected standard error from running the compiled binary. The stream is captured either way, and shown when a run fails; a test asserts it by carrying this file. Distinct from `err.expected`, which is the compiler's diagnostics rather than the program's. |
| `run.session` | Drives a program that prompts, the way a person at a terminal does. Each line is sent when the output so far ends part way through a line - the program sitting at a prompt with nothing more to say until it is answered - and is written into `run.out` at that point, where the terminal would have echoed it. So `run.expected` holds the session as it would have been seen, answers included, rather than the prompts with the answers missing. A program that reads without prompting first is not driven this way, because nothing marks the point to answer at; use `run.in` for those. A test carrying both files fails. |
| `run.check` | An executable that judges the run's output, for a program whose output is not the same twice. It is run from the test directory with `run.out` as its only argument, and passes the test by exiting zero. Its own output is what the failure report shows, since an exit status alone says nothing about which part of the output was wrong. Any interpreter its `#!` line names will do, `#!/usr/bin/env ghul` included. A `run.expected` alongside it is not compared - a program whose output varies has no snapshot to hold it to - but is still what `scripts/capture.sh` writes and what a consumer of the test can read as a sample of what the program prints. |
| `<name>.png.expected` | An image the test wrote, asserted against this one. The bytes are compared first, and only when they differ is either file decoded and the pixels compared - what a PNG compresses to is fixed by nothing, so an image that is right does not fail because the compressor changed. Depth 8, colour types grey, truecolour, and either with alpha; indexed and interlaced images are reported rather than compared. `scripts/capture.sh` writes one for every `.png` a test produced. |
| `il.expected` | Expected IL. When present, the assembly the compiler emitted is disassembled into `il.out` and diffed against this file. A test that expects IL but emits none compares against an empty file, so it fails rather than being skipped. |
| `il.item` | Optional, and only meaningful alongside `il.expected`: the one type or member to disassemble, as `Namespace.TYPE` or `Namespace.TYPE::member`. Without it the whole assembly is dumped, which is what a test asserting assembly-level shape wants. Naming something the assembly does not contain fails the test, because the disassembler reports no such thing itself. |
| `format.expected` | Expected result of formatting the test's sources. Its presence also makes the runner build the formatted sources and run what it built, comparing the output against the same `run.expected` as the original. Not supported under `--use-dotnet-build`, where the sources come from the project rather than from the runner. |
| `ghulflags` | Mandatory file containing additional command line flags for the compiler. |
| `disabled*` | Any file beginning with `disabled` causes the test to be skipped. |
| `tags` | Zero or more whitespace-separated tag names (spaces or newlines), used to select a subset of tests with `--tag`. A test with no `tags` file has no tags. |

A basic “hello world” example can be found in the `integration-tests` folder of this repository.

## Expectation Comparison Workflow

1. The runner invokes the compiler using the arguments from `ghulflags` and the test’s `.ghul` sources. Compiler stdout/stderr is written to `compiler.out`.
2. `grep` extracts error and warning lines from `compiler.out` into `err.grep` and `warn.grep` respectively. It also looks for the `exception:` lines the compiler writes when one of its passes throws, and a test whose compiler output holds one fails on that alone: a pass that throws is a compiler defect whatever the test says about its source, and it is reported as neither an error nor a warning, so nothing a test asserts would otherwise notice it.
3. These files are sorted with `sort` (with `LC_COLLATE` set to `C` for stable output) into `err.sort` and `warn.sort`.
4. `diff` compares `err.sort` to `err.expected` and `warn.sort` to `warn.expected`. Whitespace differences are ignored and carriage returns are stripped.
5. If compilation succeeded, `ghul-runtime.dll` is symlinked into the test directory and the binary is executed via `dotnet`, with the arguments a `run.args` holds. A test built for the wasm target - its `ghulflags` include `--target wasm`, or, under `--use-dotnet-build`, its project's `GhulOptions` do - builds a WebAssembly module and the JavaScript loader the compiler writes beside it, and is run instead with `node` on the loader, so the comparisons below apply to it unchanged; nothing is symlinked for it, and the test fails with a message saying so where Node cannot be started. A `run.in` is written to its standard input and the stream closed; a `run.session` is sent a line at a time as the program prompts for it, and echoed into the captured output. Input and both output streams are carried concurrently, so a program that fills one pipe while still reading another is not deadlocked by the runner. A program that has not exited within five minutes is killed and its test fails. Output is captured in `run.out` and compared to `run.expected`, or handed to `run.check` where the test carries one.
6. The exit status is compared against `run.exit.expected` where the test carries one, and otherwise any non-zero status fails the test. If a `run.err.expected` file exists, what the program wrote to standard error is compared against it, after the same path and stack-trace normalisation `run.out` gets: each `   at …` frame loses its ` in <path>:line <N>` suffix, so a stack trace is portable. Where a trace still carries something local, a test can assert the exit status alone and leave the stream unasserted.
7. Every `<name>.png.expected` in the test directory is compared against the `<name>.png` the run wrote, by bytes and then, if those differ, by decoded pixels.
8. If an `il.expected` file exists, `diff` compares it against `il.out`. A compiler that wrote `il.out` itself has already answered; when it wrote nothing and the build succeeded, the emitted assembly is disassembled with `ildasm` to produce it instead. A test therefore moves from one to the other by dropping whatever made its compiler write the file. Lines that describe the run rather than the assembly are removed first: the disassembler's version banner, the MVID, the partial-disassembly warning, and the image base, which is where the file happened to be mapped and so differs on every run.
9. If a `format.expected` file exists, the sources are copied into a `formatted` subdirectory and formatted in place. The results are joined into `format.out` - each under a `// === <name> ===` header when there is more than one - and compared to `format.expected`, without ignoring whitespace, since whitespace is what the snapshot is about. The formatted sources are then built into their own binary and, for a test that is not a library, run - with the output compared to the same `run.expected` the original was. A snapshot on its own would say only that the formatter's output is what it was last time; building and running it is what says the output is still a program that does the same thing.

Any mismatches cause a failure report containing a unified diff of the actual versus expected output.

### Disassembler

The IL comparison uses Microsoft's `ildasm`, which ships with this tool for
`linux-x64` and `win-x64` and is found beside it. Override with `--ildasm
<path>` or the `GHUL_TEST_ILDASM` environment variable, either of which must
name an existing file; on any other platform
one of those is required, and a test wanting IL reports that none was found
rather than passing quietly.

## Command Line Usage

```text
ghul-test [--use-dotnet-build] [--compiler <command>] [--runtime-dll <path>] [--ildasm <path>] [--tag <name>]... [--not-tag <name>]... [--shard <index>/<count>] <test-folder> [...]
```

- `--use-dotnet-build` – expects each test folder to be an MSBuild project. For ghūl projects the file should end with `.ghulproj`. The runner builds the project with `dotnet build` instead of invoking the compiler directly.
- `--compiler <command>` – the command each test project is built with, supplied to MSBuild as the `GhulCompiler` property. A command containing no spaces must name an existing file; anything with arguments in it, such as `dotnet /path/to/ghul.dll`, is passed through as written. Takes precedence over the `GHUL_TEST_COMPILER` environment variable and over the publish directory described below. Only meaningful under `--use-dotnet-build` — the other modes invoke the compiler directly and resolve it themselves — so supplying it elsewhere is an error.
- `--runtime-dll <path>` – use the supplied `ghul-runtime.dll` for compiled test binaries instead of the version that ships with `ghul-test`. The path must point to an existing file. Takes precedence over the `GHUL_RUNTIME_DLL` environment variable. Has no effect under `--use-dotnet-build`, which resolves the runtime via the test project's own `PackageReference`.
- `--ildasm <path>` – the disassembler used to produce `il.out` for tests carrying an `il.expected`. The path must point to an existing file. Takes precedence over the `GHUL_TEST_ILDASM` environment variable and over the copy that ships beside `ghul-test`.
- `--tag <name>` – restrict discovery to tests whose `tags` file contains at least one of the given names. Repeatable; the requested tags are matched as a union (a test runs if it carries *any* of them), not an intersection. A test with no `tags` file is excluded whenever any `--tag` is given. Omit entirely to run every discovered test regardless of tags, which is unchanged from before this flag existed.
- `--not-tag <name>` - exclude tests whose `tags` file contains any of the given names. Repeatable, and matched as a union like `--tag`. A test with no `tags` file is never excluded. Exclusion wins over inclusion, so `--tag generics --not-tag async` runs the generics tests that are not also async ones.
- `--shard <index>/<count>` - run only one part of the suite, so several processes can divide it between them. `--shard 2/6` runs the second of six parts. Tests are striped by discovery order rather than cut into contiguous blocks, since discovery walks the tree in sorted order and a block would put a whole directory into one shard. Every discovered test belongs to exactly one shard, so running all `<count>` of them runs the suite exactly once. The run reports how many of the discovered tests it took, and summing that across the shards shows none was dropped. Applies after `--tag`, so the two compose.
- `<test-folder>` – one or more directories containing tests. Each is recursively searched for subdirectories with a `ghulflags` file if not using `--use-dotnet-build`.

Environment variables influence behaviour:

- `HOST` and `TARGET` – specify the CLI used to run the compiler and the compiled binary (default `dotnet`).
- `CI` – when set to `1` or `true`, enables CI mode. In this mode `ghul-runtime.dll` is taken from the test runner's own location unless overridden by `--runtime-dll` / `GHUL_RUNTIME_DLL`.
- `GHUL_RUNTIME_DLL` – path to a `ghul-runtime.dll` to use for compiled test binaries, overriding the version that ships with `ghul-test`. Equivalent to passing `--runtime-dll`; the CLI flag wins if both are set.
- `GHUL_TEST_COMPILER` – command each test project is built with under `--use-dotnet-build`. Equivalent to passing `--compiler`; the CLI flag wins if both are set.
- `TEST_PROCESSES` – number of worker processes to use. If unset, a value derived from CPU count is used.
- `GHUL_TEST_KEEP_ARTIFACTS` – when set, keep every test's build and run artifacts instead of deleting them on success. A passing test normally cleans up after itself, so a green run leaves only the failures behind; set this to inspect what was actually built — to audit every emitted assembly, or to look at a test that passes but is suspected of passing for the wrong reason.

The runner prints progress for each test and a final summary indicating total, enabled, passed and failed counts.

## Runtime Library Handling

When the compiler is invoked directly (the default and CI modes), the produced executable expects to find `ghul-runtime.dll` beside it. The runner therefore creates a symbolic link in the test directory pointing to the runtime library. This link is not needed when `--use-dotnet-build` is used. After the test completes successfully, the link is deleted during cleanup.

By default the runtime DLL is sourced from the published compiler's directory (LOCAL mode) or the test runner's own install directory (CI mode). When the integration tests need to run against a runtime version other than the one `ghul-test` itself was packaged with — for example, when CI builds a compiler that depends on a newer `ghul.runtime` than the pinned `ghul.test` ships with — pass `--runtime-dll <path>` or set `GHUL_RUNTIME_DLL` to override the discovered location with an explicit DLL path.

## Compiler Selection Under `--use-dotnet-build`

Invoked directly, the runner knows exactly which compiler it is testing — the published one it found or was given. A `dotnet build` run does not: the project decides, and a project that leaves the decision to the .NET local tool manifest will build just as quietly against a published compiler as against the one being tested. A suite meant to exercise a compiler change can therefore pass without ever running it.

So the runner chooses, in this order:

1. `--compiler` / `GHUL_TEST_COMPILER`, if supplied.
2. The compiler in the nearest `publish` directory at or above the working directory, if there is one. This is where a compiler being tested is normally published to, so it is preferred over the tool manifest.
3. Otherwise nothing: the property is left alone and each project resolves the compiler for itself.

Whichever applies is reported before the run starts. The choice is passed to MSBuild as the `GhulCompiler` property, through the environment, so a project that assigns `GhulCompiler` unconditionally in its own `PropertyGroup` overrides it — the `.ghulproj` files of a suite intended to test a compiler should leave the property unset.

## MSBuild Projects

This runner does **not** execute arbitrary MSBuild projects. It either drives the compiler directly on `.ghul` source files or, when `--use-dotnet-build` is supplied, assumes the folder already contains a valid MSBuild project (for ghūl projects this means a `*.ghulproj` file). Only a small set of standard .NET assemblies is referenced so complex projects are out of scope.

## Dependencies

The runner relies on several standard Unix utilities being available in the environment: `grep`, `sort`, `diff` and `ln`. A .NET 10 SDK installation is required; mono is not supported.

## Writing New Tests

This repository includes helper scripts under `./scripts`:

- `create.sh` – create a new test directory from the built-in template.
- `capture.sh` – update expectation files after running a test.

1. Run `./scripts/create.sh` and provide the new test name.
2. Edit the generated `.ghul` sources and `ghulflags` as required.
3. Execute `ghul-test <path-to-test>` (expect it to fail initially). The runner produces `.out` files with the actual output.
4. Run `./scripts/capture.sh <path-to-test>` to copy the `.out` files over the corresponding `*.expected` files.
5. Re-run `ghul-test` and verify the test now passes.
6. Commit the test directory along with the expectations.

Refer to the [ghūl compiler integration tests](https://github.com/degory/ghul/tree/main/integration-tests) for many real‑world examples of this structure.


## Issues

[View open issues](https://github.com/ghul-lang/ghul/issues?q=is%3Aopen+is%3Aissue+label%3Aghul-test) or [raise a new one](https://github.com/ghul-lang/ghul/issues/new?labels=ghul-test).
