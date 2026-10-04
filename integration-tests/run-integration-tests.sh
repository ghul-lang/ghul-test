#!/bin/bash

# The runner is built once here and its binary run for every case, so what
# each case captures is the runner's own report: a `dotnet run` would build
# first and write the build's diagnostics into the same output.
if ! dotnet build -nologo -v quiet > build-output 2>&1 ; then
    cat build-output

    echo building the runner failed

    exit 1
fi

RUNNER="dotnet bin/Debug/net10.0/ghul-test.dll"

echo integration-tests/execution-fail...

TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/execution-fail | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/execution-fail unexpectedly succeeded

    exit 1
fi

if [ ! -f actual-output ] ; then
    echo integration-tests/execution-fail produced no output

    exit 1
fi

if ! diff integration-tests/execution-fail/expected-output actual-output ; then
    echo integration-tests/execution-fail output did not match expected output

    exit 1
fi

echo integration-tests/execution-fail: PASS


TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/execution-pass | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/execution-pass unexpectedly succeeded

    exit 1
fi

if [ ! -f actual-output ] ; then
    echo integration-tests/execution-pass produced no output

    exit 1
fi

if ! diff integration-tests/execution-pass/expected-output actual-output ; then
    echo integration-tests/execution-pass output did not match expected output

    exit 1
fi

echo integration-tests/execution-pass: PASS


echo integration-tests/runtime-dll-override-valid...

# The --runtime-dll override should be transparent when pointed at the same
# runtime that CI mode would have discovered itself: hello-world still passes.
RUNTIME_DLL="$(pwd)/bin/Debug/net10.0/ghul-runtime.dll"

if [ ! -f "$RUNTIME_DLL" ]; then
    echo "expected runtime DLL not found at $RUNTIME_DLL"
    exit 1
fi

TEST_PROCESSES=1 CI=1 $RUNNER --runtime-dll "$RUNTIME_DLL" integration-tests/execution-pass | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/runtime-dll-override-valid unexpectedly failed

    exit 1
fi

if ! diff integration-tests/execution-pass/expected-output actual-output ; then
    echo integration-tests/runtime-dll-override-valid output did not match expected output

    exit 1
fi

echo integration-tests/runtime-dll-override-valid: PASS


echo integration-tests/runtime-dll-override-missing...

# A missing runtime DLL must fail fast with a clear message, not silently fall
# back to default discovery.
TEST_PROCESSES=1 CI=1 $RUNNER --runtime-dll /tmp/ghul-test-no-such-runtime.dll integration-tests/execution-pass | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/runtime-dll-override-missing did not exit 1

    exit 1
fi

if ! grep -q "runtime DLL not found" actual-output ; then
    echo integration-tests/runtime-dll-override-missing did not report missing-DLL error

    exit 1
fi

echo integration-tests/runtime-dll-override-missing: PASS


echo integration-tests/dotnet-build...

TEST_PROCESSES=1 CI=1 $RUNNER --use-dotnet-build --compiler "dotnet ghul-compiler" integration-tests/dotnet-build | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/dotnet-build unexpectedly failed

    exit 1
fi

if ! diff integration-tests/dotnet-build/expected-output actual-output ; then
    echo integration-tests/dotnet-build output did not match expected output

    exit 1
fi

echo integration-tests/dotnet-build: PASS


echo integration-tests/compiler-override-honoured...

# The chosen compiler has to reach the build itself, not just be reported: a
# command that is not a compiler must fail the build it was handed to.
TEST_PROCESSES=1 CI=1 $RUNNER --use-dotnet-build --compiler /bin/false integration-tests/dotnet-build | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/compiler-override-honoured did not exit 1

    exit 1
fi

if ! grep -q "unexpected build failure" actual-output ; then
    echo integration-tests/compiler-override-honoured did not fail the build

    exit 1
fi

echo integration-tests/compiler-override-honoured: PASS


echo integration-tests/compiler-override-missing...

# A missing compiler must fail fast with a clear message, not silently fall back
# to whatever the project resolves for itself.
TEST_PROCESSES=1 CI=1 $RUNNER --use-dotnet-build --compiler /tmp/ghul-test-no-such-compiler integration-tests/dotnet-build | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/compiler-override-missing did not exit 1

    exit 1
fi

if ! grep -q "compiler not found" actual-output ; then
    echo integration-tests/compiler-override-missing did not report missing-compiler error

    exit 1
fi

echo integration-tests/compiler-override-missing: PASS


echo integration-tests/compiler-override-wrong-mode...

# --compiler only means anything for a `dotnet build` run, so asking for it
# elsewhere is an error rather than a silently ignored flag.
TEST_PROCESSES=1 CI=1 $RUNNER --compiler /bin/false integration-tests/execution-pass | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/compiler-override-wrong-mode did not exit 1

    exit 1
fi

if ! grep -q "only be set for --use-dotnet-build" actual-output ; then
    echo integration-tests/compiler-override-wrong-mode did not report the mode error

    exit 1
fi

echo integration-tests/compiler-override-wrong-mode: PASS

echo integration-tests/undiscovered...

# A directory holding a test.ghul or an expected snapshot but no ghulflags
# is never run, so it is named and fails the run; a directory holding other
# source, such as a library a test builds against, is not a test at all.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/undiscovered | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/undiscovered did not exit 1

    exit 1
fi

if ! grep -q "not run: integration-tests/undiscovered/no-flags looks like a test but has no ghulflags" actual-output ; then
    echo integration-tests/undiscovered did not report the directory with no ghulflags

    exit 1
fi

if grep -q "not run: .*support" actual-output ; then
    echo integration-tests/undiscovered reported a directory that is not a test

    exit 1
fi

if ! grep -q "1/1 tests passed" actual-output ; then
    echo integration-tests/undiscovered did not still run the discovered test

    exit 1
fi

echo integration-tests/undiscovered: PASS

echo integration-tests/il-expected...

# A test carrying il.expected has the emitted assembly disassembled and
# compared, so this covers the whole path: running ildasm, dropping the lines
# that describe the run rather than the assembly, and diffing what is left.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/il-expected | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/il-expected unexpectedly failed

    exit 1
fi

if ! diff integration-tests/il-expected/expected-output actual-output ; then
    echo integration-tests/il-expected output did not match expected output

    exit 1
fi

echo integration-tests/il-expected: PASS

echo integration-tests/ildasm-override-missing...

# A disassembler named explicitly but absent must fail fast with one clear
# message, not fall back to discovery and quietly use something else.
TEST_PROCESSES=1 CI=1 $RUNNER --ildasm /tmp/ghul-test-no-such-ildasm integration-tests/execution-pass | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/ildasm-override-missing did not exit 1

    exit 1
fi

if ! grep -q "disassembler not found" actual-output ; then
    echo integration-tests/ildasm-override-missing did not report the missing disassembler

    exit 1
fi

echo integration-tests/ildasm-override-missing: PASS

echo integration-tests/il-item-missing...

# An il.item the assembly does not contain has to be reported. The
# disassembler says nothing about one and exits zero, writing only the
# assembly preamble, so a snapshot captured from it would assert nothing about
# the construct it names and pass for good.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/il-item-missing | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/il-item-missing did not exit 1

    exit 1
fi

if ! grep -q "which the emitted assembly does not contain" actual-output ; then
    echo integration-tests/il-item-missing did not report the missing item

    exit 1
fi

echo integration-tests/il-item-missing: PASS

echo integration-tests/il-item-property...

# An il.item naming a field or property is a documented use, and the enclosing
# class is written out around it, so the check that the item was found has to
# accept a member directive rather than only a method.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/il-item-property | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/il-item-property unexpectedly failed

    exit 1
fi

if ! diff integration-tests/il-item-property/expected-output actual-output ; then
    echo integration-tests/il-item-property output did not match expected output

    exit 1
fi

echo integration-tests/il-item-property: PASS


echo integration-tests/il-item-typo...

# A member that does not exist on a type that does. The enclosing class is
# written out either way, so this is the case a check for the class alone
# would wave through.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/il-item-typo | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/il-item-typo did not exit 1

    exit 1
fi

if ! grep -q "which the emitted assembly does not contain" actual-output ; then
    echo integration-tests/il-item-typo did not report the missing member

    exit 1
fi

echo integration-tests/il-item-typo: PASS

echo integration-tests/ildasm-override-relative...

# A relative --ildasm path is checked against this directory and then run from
# another: every test is launched with its own folder as the working
# directory. Unresolved, it would name a different file there, or nothing.
TEST_PROCESSES=1 CI=1 $RUNNER --ildasm ./bin/Debug/net10.0/runtimes/linux-x64/native/ildasm integration-tests/il-expected | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/ildasm-override-relative unexpectedly failed

    exit 1
fi

if ! diff integration-tests/il-expected/expected-output actual-output ; then
    echo integration-tests/ildasm-override-relative output did not match expected output

    exit 1
fi

echo integration-tests/ildasm-override-relative: PASS

echo integration-tests/ildasm-env-missing...

# GHUL_TEST_ILDASM is documented as equivalent to --ildasm, so a path that
# does not exist has to fail the same way rather than being ignored in favour
# of the shipped copy - which would silently run something other than what was
# asked for.
TEST_PROCESSES=1 CI=1 GHUL_TEST_ILDASM=/tmp/ghul-test-no-such-ildasm $RUNNER integration-tests/il-expected | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/ildasm-env-missing did not exit 1

    exit 1
fi

if ! grep -q "disassembler not found" actual-output ; then
    echo integration-tests/ildasm-env-missing did not report the missing disassembler

    exit 1
fi

echo integration-tests/ildasm-env-missing: PASS

echo integration-tests/run-in...

# A test carrying run.in has that file written to the program's standard input.
# The program reads to end of input, so this covers the close as well as the
# write: without it the read never returns and the run times out.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/run-in | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/run-in unexpectedly failed

    exit 1
fi

if ! diff integration-tests/run-in/expected-output actual-output ; then
    echo integration-tests/run-in output did not match expected output

    exit 1
fi

echo integration-tests/run-in: PASS


echo integration-tests/run-args...

# A test carrying run.args gives the program that command line, one
# argument a line. The second argument holds a space, so this also covers an
# argument reaching the program whole rather than split in two.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/run-args | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/run-args unexpectedly failed

    exit 1
fi

if ! diff integration-tests/run-args/expected-output actual-output ; then
    echo integration-tests/run-args output did not match expected output

    exit 1
fi

echo integration-tests/run-args: PASS


echo integration-tests/run-stderr...

# A test carrying run.err.expected asserts what the program wrote to its
# standard error, which is captured either way but compared only when the
# expectation is there.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/run-stderr | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/run-stderr unexpectedly failed

    exit 1
fi

if ! diff integration-tests/run-stderr/expected-output actual-output ; then
    echo integration-tests/run-stderr output did not match expected output

    exit 1
fi

echo integration-tests/run-stderr: PASS


echo integration-tests/run-stderr-fail...

# ... and reports a difference on that stream as a failure, rather than
# passing because the standard output matched.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/run-stderr-fail | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/run-stderr-fail unexpectedly succeeded

    exit 1
fi

if ! diff integration-tests/run-stderr-fail/expected-output actual-output ; then
    echo integration-tests/run-stderr-fail output did not match expected output

    exit 1
fi

echo integration-tests/run-stderr-fail: PASS


echo integration-tests/run-exit...

# A test carrying run.exit.expected passes when the program ends with that
# status, which is how a program whose subject is failing is tested at all.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/run-exit | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/run-exit unexpectedly failed

    exit 1
fi

if ! diff integration-tests/run-exit/expected-output actual-output ; then
    echo integration-tests/run-exit output did not match expected output

    exit 1
fi

echo integration-tests/run-exit: PASS


echo integration-tests/run-exit-fail...

# ... and fails when it ends with a different one.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/run-exit-fail | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/run-exit-fail unexpectedly succeeded

    exit 1
fi

if ! diff integration-tests/run-exit-fail/expected-output actual-output ; then
    echo integration-tests/run-exit-fail output did not match expected output

    exit 1
fi

echo integration-tests/run-exit-fail: PASS


echo integration-tests/back-pressure...

# The program fills its error pipe before it has finished reading its input,
# which deadlocks a runner that writes the whole input before reading any
# output. Both pipes have to be drained while the program is still running.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/back-pressure | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/back-pressure unexpectedly failed

    exit 1
fi

if ! diff integration-tests/back-pressure/expected-output actual-output ; then
    echo integration-tests/back-pressure output did not match expected output

    exit 1
fi

echo integration-tests/back-pressure: PASS


echo integration-tests/run-session...

# A test carrying run.session is driven the way a person at a terminal drives
# it: each line is sent when the program is sitting at a prompt, and echoed
# into the transcript there. The same input as a run.in produces the prompts
# with the answers missing, which is what this asserts is no longer captured.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/run-session | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/run-session unexpectedly failed

    exit 1
fi

if ! diff integration-tests/run-session/expected-output actual-output ; then
    echo integration-tests/run-session output did not match expected output

    exit 1
fi

echo integration-tests/run-session: PASS


echo integration-tests/input-conflict...

# run.in and run.session say different things about how input is sent, so a
# test carrying both is refused rather than having both written to the same
# stream. The test also carries a format.expected, because the formatted
# binary is given the input too and is run first: the refusal has to come
# before either of them, not from the run alone.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/input-conflict | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/input-conflict did not exit 1

    exit 1
fi

if ! grep -q "carries both run.in and run.session" actual-output ; then
    echo integration-tests/input-conflict did not report the conflict

    exit 1
fi

echo integration-tests/input-conflict: PASS


echo integration-tests/png-expected...

# The image the test writes is compared against its .expected. That
# expectation was recompressed by another tool, so the two files hold the
# same picture in different bytes: a comparison of the bytes alone would
# reject it, which is the whole reason the images are decoded.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/png-expected | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/png-expected unexpectedly failed

    exit 1
fi

if ! diff integration-tests/png-expected/expected-output actual-output ; then
    echo integration-tests/png-expected output did not match expected output

    exit 1
fi

echo integration-tests/png-expected: PASS

echo integration-tests/png-missing...

# An expectation naming an image the test never wrote is a failure, not a
# comparison quietly skipped.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/png-missing | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/png-missing did not exit 1

    exit 1
fi

if ! grep -q "the test wrote no such file" actual-output ; then
    echo integration-tests/png-missing did not report the missing image

    exit 1
fi

echo integration-tests/png-missing: PASS


echo integration-tests/png-filters...

# One image, written six times, against expectations that encode it with
# each of the five scanline filters in turn. The filters are how a PNG
# describes a line in terms of the bytes left of it and the line above, so
# an expectation from any other tool will use them even though the images
# written here do not.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/png-filters | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/png-filters unexpectedly failed

    exit 1
fi

if ! diff integration-tests/png-filters/expected-output actual-output ; then
    echo integration-tests/png-filters output did not match expected output

    exit 1
fi

echo integration-tests/png-filters: PASS


echo integration-tests/format-pass...

TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/format-pass | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/format-pass unexpectedly failed

    exit 1
fi

if ! diff integration-tests/format-pass/expected-output actual-output ; then
    echo integration-tests/format-pass output did not match expected output

    exit 1
fi

echo integration-tests/format-pass: PASS


echo integration-tests/format-fail...

TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/format-fail | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/format-fail unexpectedly succeeded

    exit 1
fi

if ! diff integration-tests/format-fail/expected-output actual-output ; then
    echo integration-tests/format-fail output did not match expected output

    exit 1
fi

echo integration-tests/format-fail: PASS


echo integration-tests/ildasm-not-executable...

# A NuGet package carries no Unix permissions, so the disassembler shipped
# inside the tool arrives without its execute bit and launching it fails with
# "Permission denied" naming a path that exists. Only reproducible against the
# packaged layout, which is what every consumer installs, so the built tool is
# run directly here with the bit cleared.
chmod -x bin/Debug/net10.0/runtimes/linux-x64/native/ildasm

rm -f integration-tests/il-expected/hello-world/il.out

TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/il-expected | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/ildasm-not-executable unexpectedly failed

    exit 1
fi

if [ ! -x bin/Debug/net10.0/runtimes/linux-x64/native/ildasm ]; then
    echo integration-tests/ildasm-not-executable did not restore the execute bit

    exit 1
fi

echo integration-tests/ildasm-not-executable: PASS

echo integration-tests/run-check...

# A program whose output varies is judged by a run.check rather than by a
# snapshot. The test also carries a run.expected that disagrees, which asserts
# the snapshot is ignored where a recognizer is present rather than both being
# applied.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/run-check | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/run-check unexpectedly failed

    exit 1
fi

if ! diff integration-tests/run-check/expected-output actual-output ; then
    echo integration-tests/run-check output did not match expected output

    exit 1
fi

echo integration-tests/run-check: PASS


echo integration-tests/run-check-fail...

# What the recognizer writes is what the failure report carries, because an
# exit status alone does not say which part of the output was wrong.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/run-check-fail | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/run-check-fail unexpectedly succeeded

    exit 1
fi

if ! diff integration-tests/run-check-fail/expected-output actual-output ; then
    echo integration-tests/run-check-fail output did not match expected output

    exit 1
fi

echo integration-tests/run-check-fail: PASS


echo integration-tests/library-run-files...

# A library is never run, so a file saying what running it produces is a
# mistake. Unreported it reads as a passing assertion, because the expectation
# is simply never compared - which is how a build that emitted nothing could
# pass against an empty run.expected.
TEST_PROCESSES=1 CI=1 $RUNNER integration-tests/library-run-files | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/library-run-files did not exit 1

    exit 1
fi

if ! diff integration-tests/library-run-files/expected-output actual-output ; then
    echo integration-tests/library-run-files output did not match expected output

    exit 1
fi

echo integration-tests/library-run-files: PASS


echo integration-tests/project-tests...

# A directory holding a ghul-project.json is built by ghul-cli, here the
# local tool, and its program run from out/<target>/: the same expectation
# files decide a project test as any other, so one program that runs and
# one that does not build cover both halves.
TEST_PROCESSES=1 CI=1 $RUNNER --use-ghul-cli --ghul "dotnet ghul" integration-tests/project-tests | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/project-tests unexpectedly failed

    exit 1
fi

if ! diff integration-tests/project-tests/expected-output actual-output ; then
    echo integration-tests/project-tests output did not match expected output

    exit 1
fi

echo integration-tests/project-tests: PASS


echo integration-tests/project-tests-target...

# --target picks which of a manifest's targets a project test is built for,
# and a project that does not list it is not a test of that target.
TEST_PROCESSES=1 CI=1 $RUNNER --use-ghul-cli --ghul "dotnet ghul" --target wasm integration-tests/project-tests | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/project-tests-target unexpectedly failed

    exit 1
fi

if ! grep -q "0 tests discovered" actual-output ; then
    echo integration-tests/project-tests-target ran a project that does not list the target

    exit 1
fi

echo integration-tests/project-tests-target: PASS


exit 0
