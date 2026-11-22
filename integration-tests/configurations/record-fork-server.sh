#!/bin/bash
# Stands in for a native compiler that serves builds with --fork-server:
# records the arguments it was started with, and each request's response
# file and directory, beside itself, and fails every build. Run without
# --fork-server, it is a compiler that records its arguments and fails.
here=$(dirname "$0")

if [[ " $* " != *" --fork-server "* ]]; then
    printf '%s\n' "$@" > "$here/compiler-arguments"
    exit 1
fi

printf '%s\n' "$@" > "$here/fork-server-arguments"
: > "$here/fork-requests"

served=0
while IFS= read -r line; do
    [ "$line" = quit ] && break
    response=${line%%$'\t'*}
    directory=${line#*$'\t'}
    { echo "directory $directory"; cat "$response"; } >> "$here/fork-requests"
    served=$((served + 1))
    printf 'error: served build\n\001build-done 1\n' >&2
done

printf '\001fork-server served %d cold 0\n' "$served" >&2
