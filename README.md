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
| `ignore-space` | If present, the program's output - `run.out`, the formatted build's output and `run.err` - is compared ignoring changes in the amount of whitespace, as `diff -b` does, for a program whose spacing genuinely varies. Without it the comparison is exact, so a padding or alignment change fails the test. Carriage returns are stripped either way. |
| `cultures` | If present, the compiler and the program run with the host's culture. Without it, every process the test runs has `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1`, as the wasm and llvm targets behave, so string order, casing and number and date formats are the invariant ones whatever the machine. |
| `run.check` | An executable that judges the run's output, for a program whose output is not the same twice. It is run from the test directory with `run.out` as its only argument, and passes the test by exiting zero. Its own output is what the failure report shows, since an exit status alone says nothing about which part of the output was wrong. Any interpreter its `#!` line names will do, `#!/usr/bin/env ghul` included. A `run.expected` alongside it is not compared - a program whose output varies has no snapshot to hold it to - but is still what `scripts/capture.sh` writes and what a consumer of the test can read as a sample of what the program prints. |
| `<name>.png.expected` | An image the test wrote, asserted against this one. The bytes are compared first, and only when they differ is either file decoded and the pixels compared - what a PNG compresses to is fixed by nothing, so an image that is right does not fail because the compressor changed. Depth 8, colour types grey, truecolour, and either with alpha; indexed and interlaced images are reported rather than compared. `scripts/capture.sh` writes one for every `.png` a test produced. |
| `il.expected` | Expected IL. When present, the assembly the compiler emitted is disassembled into `il.out` and diffed against this file. A test that expects IL but emits none compares against an empty file, so it fails rather than being skipped. |
| `il.item` | Optional, and only meaningful alongside `il.expected`: the one type or member to disassemble, as `Namespace.TYPE` or `Namespace.TYPE::member`. Without it the whole assembly is dumped, which is what a test asserting assembly-level shape wants. Naming something the assembly does not contain fails the test, because the disassembler reports no such thing itself. |
| `format.expected` | Expected result of formatting the test's sources. Its presence also makes the runner build the formatted sources and run what it built, comparing the output against the same `run.expected` as the original. Not supported in a project build, where the sources come from the project rather than from the runner. |
| `ghulflags` | Mandatory file containing additional command line flags for the compiler. |
| `disabled*` | Any file beginning with `disabled` causes the test to be skipped. |
| `tags` | Zero or more whitespace-separated tag names (spaces or newlines), used to select a subset of tests with `--tag`. A test with no `tags` file has no tags. |
| `targets` | The targets the test runs under, one or more of `dotnet`, `wasm` and `llvm` separated by spaces or newlines. The test is run once per target, reported as `<path>[<target>]`, with `--target <name>` added to its `ghulflags`, which must not name a target itself. Each run happens in its own directory, `.targets/<target>/`, holding copies of the test's sources, inputs and expectations, so the runs neither collide nor leave artifacts in the test directory; the directory is remade on every run. An expectation file may name a target - `run.wasm.expected`, `err.llvm.expected`, `fail.wasm.expected` - and then stands in for the plain file in that target's run alone, so a test holds one `run.expected` for every target and a target-specific one only where the result legitimately differs. Under a configuration's `build_targets` the file names the test's targets in place of that list, and the run says which of the configuration's targets it leaves out. In a `msbuild`, `direct` or `ghul-cli` build the variants are built as `build_targets` describes. |

A basic “hello world” example can be found in the `integration-tests` folder of this repository.

A directory whose name starts with a dot is never a test and is not searched for one, which is what keeps a `.targets/<target>/` directory from being discovered twice.

## Expectation Comparison Workflow

1. The runner invokes the compiler using the arguments from `ghulflags` and the test’s `.ghul` sources. Compiler stdout/stderr is written to `compiler.out`.
2. `grep` extracts error and warning lines from `compiler.out` into `err.grep` and `warn.grep` respectively. It also looks for the `exception:` lines the compiler writes when one of its passes throws, and a test whose compiler output holds one fails on that alone: a pass that throws is a compiler defect whatever the test says about its source, and it is reported as neither an error nor a warning, so nothing a test asserts would otherwise notice it.
3. These files are sorted with `sort` (with `LC_COLLATE` set to `C` for stable output) into `err.sort` and `warn.sort`.
4. `diff` compares `err.sort` to `err.expected` and `warn.sort` to `warn.expected`. Whitespace differences are ignored and carriage returns are stripped.
5. If compilation succeeded, `ghul-runtime.dll` is symlinked into the test directory and the binary is executed via `dotnet`, with the arguments a `run.args` holds. A test built for the wasm target - its `ghulflags` include `--target wasm`, or, in a project build, its project's `GhulOptions` do - builds a WebAssembly module and the JavaScript loader the compiler writes beside it, and is run instead with `node` on the loader, so the comparisons below apply to it unchanged; nothing is symlinked for it, and the test fails with a message saying so where Node cannot be started. A configuration that names `wasm_host` runs the module under that program instead of under Node. A test built for the llvm target, with `--target llvm`, is a native executable and is run directly, with nothing symlinked beside it. A `run.in` is written to its standard input and the stream closed; a `run.session` is sent a line at a time as the program prompts for it, and echoed into the captured output. Input and both output streams are carried concurrently, so a program that fills one pipe while still reading another is not deadlocked by the runner. A program that has not exited within five minutes is killed and its test fails. Output is captured in `run.out` and compared to `run.expected` exactly, spacing and a final newline included, or handed to `run.check` where the test carries one.
6. The exit status is compared against `run.exit.expected` where the test carries one, and otherwise any non-zero status fails the test. If a `run.err.expected` file exists, what the program wrote to standard error is compared against it, after the same path and stack-trace normalisation `run.out` gets, and as exactly: each `   at …` frame loses its ` in <path>:line <N>` suffix, so a stack trace is portable. Where a trace still carries something local, a test can assert the exit status alone and leave the stream unasserted.
7. Every `<name>.png.expected` in the test directory is compared against the `<name>.png` the run wrote, by bytes and then, if those differ, by decoded pixels.
8. If an `il.expected` file exists, `diff` compares it against `il.out`. A compiler that wrote `il.out` itself has already answered; when it wrote nothing and the build succeeded, the emitted assembly is disassembled with `ildasm` to produce it instead. A test therefore moves from one to the other by dropping whatever made its compiler write the file. Lines that describe the run rather than the assembly are removed first: the disassembler's version banner, the MVID, the partial-disassembly warning, and the image base, which is where the file happened to be mapped and so differs on every run.
9. If a `format.expected` file exists, the sources are copied into a `formatted` subdirectory and formatted in place. The results are joined into `format.out` - each under a `// === <name> ===` header when there is more than one - and compared to `format.expected`, without ignoring whitespace, since whitespace is what the snapshot is about. The formatted sources are then built into their own binary and, for a test that is not a library, run - with the output compared to the same `run.expected` the original was. A snapshot on its own would say only that the formatter's output is what it was last time; building and running it is what says the output is still a program that does the same thing.

Any mismatches cause a failure report containing a unified diff of the actual versus expected output.

### Disassembler

The IL comparison uses Microsoft's `ildasm`, which ships with this tool for
`linux-x64` and `win-x64` and is found beside it. Override with the configuration's `ildasm` or the `GHUL_TEST_ILDASM`
environment variable, either of which must name an existing file; on any other platform
one of those is required, and a test wanting IL reports that none was found
rather than passing quietly.

## Configurations

A repository states how its suites are run in a `ghul-test.json`, and a run names one of its configurations:

```text
ghul-test --config ci integration-tests
```

The file is found in the working directory or the nearest directory above it. A run that names no configuration, and gives none of the options a configuration sets, runs the file's `default`, if it has one. Comments and trailing commas are allowed.

```json
{
    "default": "local",
    "configurations": {
        "local": {
            "compiler": { "publish": "publish" },
            "runtime": "beside-compiler",
            "targets": {
                "wasm": {
                    "libraries": [
                        { "name": "ghul-core", "root": ["libraries/ghul-core", "../ghul-core"], "sources": "src/**/*.ghul" },
                        { "name": "ghul-runtime", "root": ["libraries/ghul-runtime", "../ghul-runtime"], "sources": "@wasm-sources.rsp" }
                    ]
                }
            }
        },
        "ci": {
            "extends": "local",
            "compiler": "tool",
            "runtime": { "path": "bootstrap-tool/ghul-runtime.dll" }
        }
    }
}
```

Paths are relative to the file. A configuration holds:

- `extends` – another configuration of the file, applied first; what this one sets replaces what that one set, and `targets` is replaced target by target.
- `build` – how each test is built:
  - `compiler`, the default: the runner calls the compiler on the test's sources and links the configuration's runtime beside the program.
  - `msbuild`: each test folder is an MSBuild project (for ghūl, a `.ghulproj`), built with `dotnet build`.
  - `direct`: as `msbuild`, but a project is built with the compiler alone, as MSBuild would have called it, where everything in the project and in the `Directory.Build.props` above it is something the runner can read: an `Exe` on `Microsoft.NET.Sdk` for the runner's target framework, sources `*.ghul` or `**/*.ghul` in the test directory itself, `GhulOptions`, the `Ghul*` properties that become compiler flags, and a `PackageReference` to `ghul.runtime` alone, at a fixed version that is already restored. Its diagnostics are written as MSBuild writes them, so the same snapshots hold either way. Any other project, and one whose `ghulflags` is not empty, is built with `dotnet build`, and the run says how many of each, and why.
  - `ghul-cli`: a directory holding a `ghul-project.json` is a test, and needs no `ghulflags`. It is built with `ghul build --target <target>` in the test folder, and the program ghul-cli writes to `out/<target>/` is run: under `node` for wasm, directly for llvm, under `dotnet` for dotnet. The compiler and libraries are whatever the manifest says. `format.expected` and `il.expected` are not supported, and a library project is built and not run.
- `compiler` – for a `compiler` build, `"tool"` for the `ghul-compiler` the tool manifest pins, or `{ "publish": "<dir>" }` or `{ "path": "<dir>/ghul.dll" }` for a published compiler. For a `msbuild` or `direct` build, `{ "path": ... }` or `{ "command": "<words>" }` names the compiler each project is built with, passed to MSBuild as the `GhulCompiler` property, and `"project"` leaves the choice to each project, unless a `publish` directory at or above the working directory holds a compiler, which is then used. A command with no spaces in it must name an existing file. A project that assigns `GhulCompiler` itself overrides whatever the run chooses. Which compiler a project build uses is reported before the run starts.
- `runtime` – the `ghul-runtime.dll` a compiled test runs against: `"beside-compiler"`, `{ "path": "<file>" }`, or `{ "package": "ghul.runtime", "version": "<version>" }` from the NuGet package cache, where `"pinned_in": "<file>"` in place of `version` reads the version an MSBuild file such as `Directory.Packages.props` pins. A `compiler` build using the tool has to name its runtime. A project build takes its runtime from the project's own `PackageReference`.
- `targets` – for each target a test can be built for, the compiler `flags` and the `libraries` a run under it adds, after the test's own `ghulflags` and `--target <name>`. In a `direct` or `msbuild` build they apply to a variant built for a target other than dotnet. A library is a `name`, a `root` (or a list of candidate roots, the first that exists being used), and `sources`: `<dir>/**/<files>` under the root, or `@<listing>`, a file in the root listing source paths relative to it. The library's version is read from `VERSION` in its root, and each becomes a `--library-source`. A path under a library's root is written in a test's output as the library's name in angle brackets followed by the path within it, such as `<ghul-core>/src/tasks.ghul`, so an expectation naming a library source holds whichever root the library resolved to. A library whose root holds the test itself is left out of this. A library that names a `package`, such as `"package": "ghul.raster"`, is given only to a project build that references that package, standing in for it under a target other than dotnet.
- `build_targets` – the targets each test is built for, such as `["dotnet", "llvm"]`. Each test is built and run once per target, as a variant reported as `<path>[<target>]` in its own directory, where an expectation named for the target - `run.llvm.expected`, `fail.wasm.expected` - stands in for the plain one. A test whose `ghulflags` name a target is built for that one, and a test with a `targets` file for the ones it names. A `ghul-cli` project is built for the targets its manifest lists too. A `msbuild` or `direct` project is built for dotnet as usual, and for any other target with the compiler alone, as a `direct` build is, given the project's options, `--target` and the configuration's `targets` entry; a project the runner cannot read, or one that references a package no library stands for, is passed over for that target, and the run says why. A compiler build's variant directory is `.targets/<target>/` inside the test; a project build's is `.targets-<test>-<target>/` beside it, at the same depth, so paths a project gives relative to its own directory still resolve. A repository running project builds this way ignores `.targets-*/`. Left out, each test is built once, for the target it names.
- `run_targets` – the targets the run covers, such as `["dotnet", "wasm"]`. A test built for any other target, or a `targets` file's variant for one, is passed over rather than run, and the run says how many it passed over. A test's target is its variant's, or the `--target` its `ghulflags` give, or `dotnet`. Left out, every target is run.
- `ildasm` – the disassembler, in place of the copy that ships beside ghul-test.
- `wasm_host` – the program that runs a test built for the wasm target, in place of `node` on the loader the compiler writes: it is given the module and the arguments from `run.args`. Paths are relative to the file. Without it, wasm tests run under `node`.
- `ghul` and `ghul_target` – for a `ghul-cli` build, the command that runs ghul-cli (`ghul` unless given, `dotnet ghul` for a local tool) and the target each project is built for. A project whose manifest does not list the target is passed over; without one, each project is built for the first target its manifest lists.

## Command Line Usage

```text
ghul-test [--config <name>] [--compiler <command>] [--tag <name>]... [--not-tag <name>]... [--shard <index>/<count>] <test-folder> [...]
```

- `--config <name>` – run the named configuration from `ghul-test.json`; without it, the file's `default` runs. A run with no `ghul-test.json` at or above the working directory, or with neither, is refused. See [Configurations](#configurations).
- `--compiler <command>` – override the configuration's compiler: for a `compiler` build, the published compiler to run, such as `dotnet /path/to/ghul.dll`; for a `msbuild` or `direct` build, the `GhulCompiler` each project is built with.
- `--tag <name>` – restrict discovery to tests whose `tags` file contains at least one of the given names. Repeatable; the requested tags are matched as a union (a test runs if it carries *any* of them), not an intersection. A test with no `tags` file is excluded whenever any `--tag` is given.
- `--not-tag <name>` - exclude tests whose `tags` file contains any of the given names. Repeatable, and matched as a union like `--tag`. A test with no `tags` file is never excluded. Exclusion wins over inclusion, so `--tag generics --not-tag async` runs the generics tests that are not also async ones.
- `--shard <index>/<count>` - run only one part of the suite, so several processes can divide it between them. `--shard 2/6` runs the second of six parts. Tests are striped by discovery order rather than cut into contiguous blocks, since discovery walks the tree in sorted order and a block would put a whole directory into one shard. Every discovered test belongs to exactly one shard, so running all `<count>` of them runs the suite exactly once. The run reports how many of the discovered tests it took, and summing that across the shards shows none was dropped. Applies after `--tag`, so the two compose.
- `<test-folder>` – one or more directories containing tests. Each is recursively searched for subdirectories with a `ghulflags` file, or for a `ghul-cli` build with a `ghul-project.json`.

The options earlier versions took in place of a configuration (`--ci`, `--no-ci`, `--use-dotnet-build`, `--direct`, `--use-ghul-cli`, `--ghul`, `--target`, `--runtime-dll`, `--ildasm`, `--target-flags`) are refused, naming what the configuration says instead.

Environment variables:

- `GHUL_TEST_ILDASM` – the disassembler, overriding the configuration's `ildasm`. The path must name an existing file.
- `TEST_PROCESSES` – number of worker processes to use. If unset, a value derived from CPU count is used.
- `GHUL_TEST_KEEP_ARTIFACTS` – when set, keep every test's build and run artifacts instead of deleting them on success. A passing test normally cleans up after itself, so a green run leaves only the failures behind; set this to inspect what was actually built — to audit every emitted assembly, or to look at a test that passes but is suspected of passing for the wrong reason.

The runner prints progress for each test and a final summary indicating total, enabled, passed and failed counts. The configuration it runs is named on standard error.

## Runtime Library Handling

In a `compiler` build the produced executable expects to find `ghul-runtime.dll` beside it, so the runner links the configuration's runtime into the test directory, and deletes the link when the test passes. A project build needs no link: its runtime comes from its own `PackageReference`.

## MSBuild Projects

This runner does **not** execute arbitrary MSBuild projects. It either drives the compiler directly on `.ghul` source files or, in a `msbuild` or `direct` build, assumes the folder already contains a valid MSBuild project (for ghūl projects this means a `*.ghulproj` file). Only a small set of standard .NET assemblies is referenced so complex projects are out of scope.

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
