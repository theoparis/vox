// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Remaining GLES 2 state: hints, line width, polygon offset, sample coverage,
// pixel storage, stencil state, constant vertex attributes, and the capabilities
// that have no rendering effect here. Where state is accepted but has no
// effect it is because the feature is absent, not ignored: there is no stencil
// buffer or multisampling, so those tests pass trivially as GL specifies.

pub const gl_dither = u32(0x0BD0)
pub const gl_stencil_test_cap = u32(0x0B90)
pub const gl_polygon_offset_fill = u32(0x8037)
pub const gl_sample_alpha_to_coverage = u32(0x809E)
pub const gl_sample_coverage_cap = u32(0x80A0)
pub const gl_generate_mipmap_hint = u32(0x8192)
pub const gl_dont_care = u32(0x1100)
pub const gl_fastest = u32(0x1101)
pub const gl_nicest = u32(0x1102)
pub const gl_pack_alignment = u32(0x0D05)
pub const gl_unpack_alignment = u32(0x0CF5)
pub const gl_keep = u32(0x1E00)
pub const gl_replace = u32(0x1E01)
pub const gl_incr = u32(0x1E02)
pub const gl_decr = u32(0x1E03)
pub const gl_invert = u32(0x150A)
pub const gl_incr_wrap = u32(0x8507)
pub const gl_decr_wrap = u32(0x8508)

// AttribConst is a generic vertex attribute value set by glVertexAttrib*.
// Until set, an attribute reads (0, 0, 0, 1).
pub struct AttribConst {
pub mut:
	set bool
	v   [4]f32
}

pub struct MiscState {
pub mut:
	line_width        f32 = 1.0
	polygon_factor    f32
	polygon_units     f32
	polygon_offset    bool
	coverage_value    f32 = 1.0
	coverage_invert   bool
	dither_off        bool
	stencil_test      bool
	alpha_to_coverage bool
	sample_coverage   bool
	pack_alignment    int = 4
	unpack_alignment  int = 4
	generate_hint     u32 = gl_dont_care
	clear_stencil     int
}

pub fn (mut c Context) hint(target u32, mode u32) {
	if target != gl_generate_mipmap_hint {
		c.set_error(gl_invalid_enum)
		return
	}
	if mode != gl_dont_care && mode != gl_fastest && mode != gl_nicest {
		c.set_error(gl_invalid_enum)
		return
	}
	c.misc.generate_hint = mode
}

// line_width stores the requested width. Metal draws one-pixel lines, which
// is also ALIASED_LINE_WIDTH_RANGE, so wider requests render at width 1.
pub fn (mut c Context) line_width(w f32) {
	if !(w > 0) {
		c.set_error(gl_invalid_value)
		return
	}
	c.misc.line_width = w
}

pub fn (mut c Context) polygon_offset(factor f32, units f32) {
	c.misc.polygon_factor = factor
	c.misc.polygon_units = units
}

pub fn (mut c Context) sample_coverage(value f32, invert bool) {
	c.misc.coverage_value = clamp01(value)
	c.misc.coverage_invert = invert
}

// pixel_store accepts the two GLES 2 alignments. RGBA bytes are always
// 4-byte aligned, so the value never changes a transfer.
pub fn (mut c Context) pixel_store(pname u32, param int) {
	if pname != gl_pack_alignment && pname != gl_unpack_alignment {
		c.set_error(gl_invalid_enum)
		return
	}
	if param != 1 && param != 2 && param != 4 && param != 8 {
		c.set_error(gl_invalid_value)
		return
	}
	if pname == gl_pack_alignment {
		c.misc.pack_alignment = param
	} else {
		c.misc.unpack_alignment = param
	}
}

fn is_compare_func(f u32) bool {
	return depth_func_code(f) != none
}

fn is_stencil_op(v u32) bool {
	return v == gl_zero || v == gl_keep || v == gl_replace || v == gl_incr || v == gl_decr
		|| v == gl_invert || v == gl_incr_wrap || v == gl_decr_wrap
}

fn is_face(f u32) bool {
	return f == gl_front || f == gl_back || f == gl_front_and_back
}

pub fn (mut c Context) clear_stencil(s int) {
	c.misc.clear_stencil = s
}

pub fn (mut c Context) stencil_func(func u32, ref int, mask u32) {
	c.stencil_func_separate(gl_front_and_back, func, ref, mask)
}

pub fn (mut c Context) stencil_func_separate(face u32, func u32, ref int, mask u32) {
	if !is_face(face) || !is_compare_func(func) {
		c.set_error(gl_invalid_enum)
	}
}

pub fn (mut c Context) stencil_mask(mask u32) {
}

pub fn (mut c Context) stencil_mask_separate(face u32, mask u32) {
	if !is_face(face) {
		c.set_error(gl_invalid_enum)
	}
}

pub fn (mut c Context) stencil_op(fail u32, zfail u32, zpass u32) {
	c.stencil_op_separate(gl_front_and_back, fail, zfail, zpass)
}

pub fn (mut c Context) stencil_op_separate(face u32, fail u32, zfail u32, zpass u32) {
	if !is_face(face) || !is_stencil_op(fail) || !is_stencil_op(zfail) || !is_stencil_op(zpass) {
		c.set_error(gl_invalid_enum)
	}
}

// vertex_attrib_const sets the generic value of attribute index, used when the
// attribute's array is disabled.
pub fn (mut c Context) vertex_attrib_const(index int, x f32, y f32, z f32, w f32) {
	if index < 0 || index >= max_attribs {
		c.set_error(gl_invalid_value)
		return
	}
	c.attrib_consts[index] = AttribConst{
		set: true
		v:   [x, y, z, w]!
	}
}

// attrib_const_value is the generic value a disabled attribute reads.
fn (c &Context) attrib_const_value(index int) [4]f32 {
	k := c.attrib_consts[index]
	if !k.set {
		return [f32(0), 0, 0, 1]!
	}
	return k.v
}

// set_extra_capability handles capabilities that are tracked but cannot change
// the output: dither, stencil test, and multisample coverage have nothing to
// act on. It reports false for an unknown capability.
fn (mut c Context) set_extra_capability(cap u32, on bool) bool {
	match cap {
		gl_dither { c.misc.dither_off = !on }
		gl_stencil_test_cap { c.misc.stencil_test = on }
		gl_polygon_offset_fill { c.misc.polygon_offset = on }
		gl_sample_alpha_to_coverage { c.misc.alpha_to_coverage = on }
		gl_sample_coverage_cap { c.misc.sample_coverage = on }
		else { return false }
	}
	return true
}

fn (c &Context) extra_capability(cap u32) bool {
	return match cap {
		gl_dither { !c.misc.dither_off }
		gl_stencil_test_cap { c.misc.stencil_test }
		gl_polygon_offset_fill { c.misc.polygon_offset }
		gl_sample_alpha_to_coverage { c.misc.alpha_to_coverage }
		gl_sample_coverage_cap { c.misc.sample_coverage }
		else { false }
	}
}

// draw_buffers accepts the single color buffer; there are no others.
pub fn (mut c Context) draw_buffers(bufs []u32) {
	if bufs.len == 0 || bufs.len > 1 {
		c.set_error(gl_invalid_value)
		return
	}
	b := bufs[0]
	if c.bound_framebuffer == 0 {
		if b != gl_back && b != gl_none_buffer {
			c.set_error(gl_invalid_operation)
		}
		return
	}
	if b != gl_color_attachment0 && b != gl_none_buffer {
		c.set_error(gl_invalid_operation)
	}
}

pub const gl_none_buffer = u32(0)

pub fn (mut c Context) read_buffer(src u32) {
	if c.bound_framebuffer == 0 {
		if src != gl_back && src != gl_none_buffer {
			c.set_error(gl_invalid_operation)
		}
		return
	}
	if src != gl_color_attachment0 && src != gl_none_buffer {
		c.set_error(gl_invalid_operation)
	}
}
