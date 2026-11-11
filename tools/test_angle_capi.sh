#!/bin/sh
# Builds the V angle module as a shared library and runs the dlopen smoke test
# against it. Uses a private temp directory and removes it afterwards.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
v_bin=${V_BIN:-$(command -v v || echo "$HOME/code/v/v")}
out=$(mktemp -d "${TMPDIR:-/tmp}/angle-capi.XXXXXX")
trap 'rm -rf "$out"' EXIT
cd "$root"
"$v_bin" -b c -memory-limit 10G -enable-globals -d vox_angle_capi -shared -o "$out/libvoxangle.dylib" angle
cc -o "$out/capi_smoke" angle/capi_smoke.c
"$out/capi_smoke" "$out/libvoxangle.dylib"
