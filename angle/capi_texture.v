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

@[export: 'glGenerateMipmap']
pub fn capi_gl_generate_mipmap(target u32) {
	mut c := capi_ctx() or { return }
	c.generate_mipmap(target)
}

// The Robust pixel transfers take bufSize and extra out-parameters, which puts
// them past V's eight-parameter export limit. capi_shim.h packs the extras:
// format and type share a u64, and read_pixels passes its four outputs
// through one array. A buffer smaller than the transfer is INVALID_OPERATION.

@[export: 'vox_angle_tex_image_2d_robust']
pub fn capi_gl_tex_image_2d_robust(target u32, level i32, internal_format i32, w i32, h i32, border_buf u64, format_type u64, pixels voidptr) {
	mut c := capi_ctx() or { return }
	border := i32(border_buf & 0xffffffff)
	buf_size := i32(border_buf >> 32)
	if border != 0 {
		c.set_error(gl_invalid_value)
		return
	}
	need := int(w) * int(h) * 4
	if pixels != unsafe { nil } && int(buf_size) < need {
		c.set_error(gl_invalid_operation)
		return
	}
	c.tex_image_2d(target, int(level), u32(internal_format), int(w), int(h), u32(format_type >> 32),
		u32(format_type & 0xffffffff), capi_bytes(pixels, need))
}

@[export: 'vox_angle_tex_sub_image_2d_robust']
pub fn capi_gl_tex_sub_image_2d_robust(target_level u64, x i32, y i32, w i32, h i32, format_type u64, buf_size i32, pixels voidptr) {
	mut c := capi_ctx() or { return }
	need := int(w) * int(h) * 4
	if int(buf_size) < need {
		c.set_error(gl_invalid_operation)
		return
	}
	c.tex_sub_image_2d(u32(target_level >> 32), int(i32(target_level & 0xffffffff)), int(x), int(y),
		int(w), int(h), u32(format_type >> 32), u32(format_type & 0xffffffff), capi_bytes(pixels, need))
}

// outs is {length, columns, rows, pixels}; each may be nil except pixels.
@[export: 'vox_angle_read_pixels_robust']
pub fn capi_gl_read_pixels_robust(x i32, y i32, w i32, h i32, format_type u64, buf_size i32, outs &voidptr) {
	mut c := capi_ctx() or { return }
	pixels := unsafe { outs[3] }
	need := int(w) * int(h) * 4
	if w < 0 || h < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	if int(buf_size) < need {
		c.set_error(gl_invalid_operation)
		return
	}
	data := c.read_pixels(int(x), int(y), int(w), int(h), u32(format_type >> 32), u32(format_type & 0xffffffff))
	if data.len != need || pixels == unsafe { nil } {
		return
	}
	unsafe {
		vmemcpy(pixels, data.data, need)
		if outs[0] != nil {
			*(&i32(outs[0])) = i32(need)
		}
		if outs[1] != nil {
			*(&i32(outs[1])) = w
		}
		if outs[2] != nil {
			*(&i32(outs[2])) = h
		}
	}
}
