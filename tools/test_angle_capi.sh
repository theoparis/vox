#!/bin/sh
# Builds the V angle module as a shared library, checks that it exports every
# symbol webgl/angle_dispatch_darwin.h resolves, and runs the dlopen smoke test
# against it. Uses a private temp directory and removes it afterwards.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
v_bin=${V_BIN:-$(command -v v || echo "$HOME/code/v/v")}
out=$(mktemp -d "${TMPDIR:-/tmp}/angle-capi.XXXXXX")
trap 'rm -rf "$out"' EXIT
cd "$root"
"$v_bin" -b c -memory-limit 10G -enable-globals -d vox_angle_capi -shared -o "$out/libvoxangle.dylib" angle
python3 - "$out/libvoxangle.dylib" <<'PY'
import re, subprocess, sys
header = open('webgl/angle_dispatch_darwin.h').read()
required = sorted(set(re.findall(r'\b((?:egl|gl)[A-Z][A-Za-z0-9]*)\b', header)))
listing = subprocess.run(['nm', '-gU', sys.argv[1]], capture_output=True, text=True, check=True).stdout
exported = {line.split()[-1].lstrip('_') for line in listing.splitlines() if line.strip()}
missing = [name for name in required if name not in exported]
if missing:
    sys.exit('missing exports: ' + ' '.join(missing))
print('all %d dispatch symbols exported' % len(required))
PY
cc -o "$out/capi_smoke" angle/capi_smoke.c
"$out/capi_smoke" "$out/libvoxangle.dylib"
