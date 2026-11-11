// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// C ABI for ES 3 and ANGLE entry points that behave on an ES 2 context, plus the
// error recorders the generated stubs in capi_es3_shim.h call.

// vox_angle_unsupported records INVALID_OPERATION for an entry point that does
// not exist on an ES 2 context.
@[export: 'vox_angle_unsupported']
pub fn capi_unsupported() {
	mut c := capi_ctx() or { return }
	c.set_error(gl_invalid_operation)
}

// vox_angle_invalid_enum records INVALID_ENUM for formats that are not supported.
@[export: 'vox_angle_invalid_enum']
pub fn capi_invalid_enum() {
	mut c := capi_ctx() or { return }
	c.set_error(gl_invalid_enum)
}

@[export: 'glRequestExtensionANGLE']
pub fn capi_gl_request_extension(name voidptr) {
	mut c := capi_ctx() or { return }
	c.request_extension(capi_string(name, -1))
}

@[export: 'glDrawRangeElements']
pub fn capi_gl_draw_range_elements(mode u32, start u32, end u32, count i32, typ u32, indices voidptr) {
	mut c := capi_ctx() or { return }
	c.draw_range_elements(mode, start, end, int(count), typ, int(u64(indices)))
}

@[export: 'glRenderbufferStorageMultisample']
pub fn capi_gl_renderbuffer_storage_multisample(target u32, samples i32, format u32, w i32, h i32) {
	mut c := capi_ctx() or { return }
	c.renderbuffer_storage_multisample(target, int(samples), format, int(w), int(h))
}

@[export: 'glInvalidateFramebuffer']
pub fn capi_gl_invalidate_framebuffer(target u32, n i32, attachments &u32) {
	mut c := capi_ctx() or { return }
	if n < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	mut list := []u32{}
	for i in 0 .. int(n) {
		list << unsafe { attachments[i] }
	}
	c.invalidate_framebuffer(target, list)
}

@[export: 'glInvalidateSubFramebuffer']
pub fn capi_gl_invalidate_sub_framebuffer(target u32, n i32, attachments &u32, x i32, y i32, w i32, h i32) {
	mut c := capi_ctx() or { return }
	if w < 0 || h < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	capi_gl_invalidate_framebuffer(target, n, attachments)
}

// glGetInternalformativRobustANGLE: no format is multisampled, so the SAMPLES
// query returns no values; every other query is an invalid enum.
@[export: 'glGetInternalformativRobustANGLE']
pub fn capi_gl_get_internalformativ_robust(target u32, format u32, pname u32, buf_size i32, length &i32, params &i32) {
	mut c := capi_ctx() or { return }
	if target != gl_renderbuffer {
		c.set_error(gl_invalid_enum)
		return
	}
	if pname != 0x80A9 { // GL_SAMPLES
		c.set_error(gl_invalid_enum)
		return
	}
	if buf_size < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	if length != unsafe { nil } {
		unsafe {
			*length = 0
		}
	}
}

// glGetVertexAttribPointervRobustANGLE returns the byte offset of the pointer
// as an opaque pointer value.
@[export: 'glGetVertexAttribPointervRobustANGLE']
pub fn capi_gl_get_vertex_attrib_pointerv_robust(index u32, pname u32, buf_size i32, length &i32, out &voidptr) {
	mut c := capi_ctx() or { return }
	if pname != gl_vertex_attrib_array_pointer {
		c.set_error(gl_invalid_enum)
		return
	}
	values := c.vertex_attrib_param(int(index), pname) or { return }
	if buf_size < 1 {
		c.set_error(gl_invalid_operation)
		return
	}
	unsafe {
		*out = voidptr(u64(values[0]))
	}
	if length != unsafe { nil } {
		unsafe {
			*length = 1
		}
	}
}
