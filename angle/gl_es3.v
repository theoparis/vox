// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Small entry points that WebGL resolves from ES 3 and ANGLE but that have a
// precise meaning on this ES 2 context.

// request_extension is glRequestExtensionANGLE. Only the extensions listed in
// GL_EXTENSIONS exist; asking for anything else is INVALID_OPERATION.
pub fn (mut c Context) request_extension(name string) {
	if name !in supported_extensions {
		c.set_error(gl_invalid_operation)
	}
}

// draw_range_elements is glDrawRangeElements: DrawElements with a promise that
// every index lies in [start, end]. The promise is validated, not trusted.
pub fn (mut c Context) draw_range_elements(mode u32, start u32, end u32, count int, typ u32, offset int) {
	if end < start {
		c.set_error(gl_invalid_value)
		return
	}
	c.draw_elements(mode, count, typ, offset)
}

// renderbuffer_storage_multisample accepts only zero samples: there is no
// multisampling, so a request for samples is INVALID_OPERATION.
pub fn (mut c Context) renderbuffer_storage_multisample(target u32, samples int, format u32, width int, height int) {
	if samples < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	if samples > 0 {
		c.set_error(gl_invalid_operation)
		return
	}
	c.renderbuffer_storage(target, format, width, height)
}

// invalidate_framebuffer is a hint that attachment contents are not needed.
// Discarding is optional, so after validation it does nothing.
pub fn (mut c Context) invalidate_framebuffer(target u32, attachments []u32) {
	if target != gl_framebuffer && target != gl_read_framebuffer && target != gl_draw_framebuffer {
		c.set_error(gl_invalid_enum)
		return
	}
	for a in attachments {
		valid := if c.bound_framebuffer == 0 {
			a == gl_back || a == 0x1800 || a == 0x1801 || a == 0x1802
		} else {
			a == gl_color_attachment0 || a == gl_depth_attachment || a == 0x8D20 || a == 0x821A
		}
		if !valid {
			c.set_error(gl_invalid_enum)
			return
		}
	}
}
