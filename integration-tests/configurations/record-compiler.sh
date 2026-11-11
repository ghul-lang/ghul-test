#!/bin/bash
# Stands in for a compiler: records the arguments it was given, one a line,
# beside itself, and fails the build.
printf '%s\n' "$@" > "$(dirname "$0")/compiler-arguments"
exit 1
