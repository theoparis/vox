// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// C ABI for texture units, sampler parameters, and sub-image updates.

@[export: 'glActiveTexture']
pub fn capi_gl_active_texture(unit u32) {
	mut c := capi_ctx() or { return }
	c.active_texture(unit)
}

@[export: 'glTexParameteri']
pub fn capi_gl_tex_parameteri(target u32, pname u32, value i32) {
	mut c := capi_ctx() or { return }
	c.tex_parameteri(target, pname, int(value))
}

// glTexParameterf carries the same enums as floats; every accepted value is an
// integral enum, so it converts exactly.
@[export: 'glTexParameterf']
pub fn capi_gl_tex_parameterf(target u32, pname u32, value f32) {
	mut c := capi_ctx() or { return }
	c.tex_parameteri(target, pname, int(value))
}

// vox_angle_tex_sub_image_2d is glTexSubImage2D with format and type packed
// into one argument; see capi.v for why. capi_shim.h supplies the entry point.
@[export: 'vox_angle_tex_sub_image_2d']
pub fn capi_gl_tex_sub_image_2d(target u32, level i32, x i32, y i32, w i32, h i32, format_type u64, pixels voidptr) {
	mut c := capi_ctx() or { return }
	c.tex_sub_image_2d(target, int(level), int(x), int(y), int(w), int(h), u32(format_type >> 32),
		u32(format_type & 0xffffffff), capi_bytes(pixels, int(w) * int(h) * 4))
}
