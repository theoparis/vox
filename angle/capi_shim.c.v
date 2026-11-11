// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// capi_shim.h defines entry points whose C signature V cannot export directly
// (see capi.v). It forwards to exported V functions and is compiled only for
// the shared-library build, `-d vox_angle_capi`.
#include "@DIR/capi_shim.h"

$if vox_angle_capi ? {
	// V restricts shared-library exports to its own @[export] functions, so the
	// shim's entry point must be listed explicitly.
	#flag darwin -Wl,-exported_symbol,_glTexImage2D
}
