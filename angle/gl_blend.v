// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Blending and color write mask. Both are baked into the Metal render
// pipeline, so they are part of the pipeline cache key; the constant blend
// color is a per-draw value.

pub const gl_blend = u32(0x0BE2)
pub const gl_zero = u32(0)
pub const gl_one = u32(1)
pub const gl_src_color = u32(0x0300)
pub const gl_one_minus_src_color = u32(0x0301)
pub const gl_src_alpha = u32(0x0302)
pub const gl_one_minus_src_alpha = u32(0x0303)
pub const gl_dst_alpha = u32(0x0304)
pub const gl_one_minus_dst_alpha = u32(0x0305)
pub const gl_dst_color = u32(0x0306)
pub const gl_one_minus_dst_color = u32(0x0307)
pub const gl_src_alpha_saturate = u32(0x0308)
pub const gl_constant_color = u32(0x8001)
pub const gl_one_minus_constant_color = u32(0x8002)
pub const gl_constant_alpha = u32(0x8003)
pub const gl_one_minus_constant_alpha = u32(0x8004)
pub const gl_func_add = u32(0x8006)
pub const gl_func_subtract = u32(0x800A)
pub const gl_func_reverse_subtract = u32(0x800B)
pub const gl_blend_color_pname = u32(0x8005)
pub const gl_blend_dst_rgb = u32(0x80C8)
pub const gl_blend_src_rgb = u32(0x80C9)
pub const gl_blend_dst_alpha = u32(0x80CA)
pub const gl_blend_src_alpha = u32(0x80CB)
pub const gl_blend_equation_rgb = u32(0x8009)
pub const gl_blend_equation_alpha = u32(0x883D)
pub const gl_color_writemask = u32(0x0C23)

// BlendState is the blend function, equation, constant color and write mask.
// Factors and equations hold GL enums.
pub struct BlendState {
pub mut:
	src_rgb   u32 = gl_one
	dst_rgb   u32 = gl_zero
	src_alpha u32 = gl_one
	dst_alpha u32 = gl_zero
	eq_rgb    u32 = gl_func_add
	eq_alpha  u32 = gl_func_add
	color     [4]f32
	mask      [4]bool = [true, true, true, true]!
}

// factor_code maps a GL blend factor to the backend numbering used in
// PipelineDesc.blend. src_only admits SRC_ALPHA_SATURATE, which GL allows
// only as a source factor.
fn factor_code(f u32, src_only bool) ?i32 {
	return match f {
		gl_zero { 0 }
		gl_one { 1 }
		gl_src_color { 2 }
		gl_one_minus_src_color { 3 }
		gl_dst_color { 4 }
		gl_one_minus_dst_color { 5 }
		gl_src_alpha { 6 }
		gl_one_minus_src_alpha { 7 }
		gl_dst_alpha { 8 }
		gl_one_minus_dst_alpha { 9 }
		gl_constant_color { 10 }
		gl_one_minus_constant_color { 11 }
		gl_constant_alpha { 12 }
		gl_one_minus_constant_alpha { 13 }
		gl_src_alpha_saturate { if src_only { i32(14) } else { none } }
		else { none }
	}
}

fn equation_code(e u32) ?i32 {
	return match e {
		gl_func_add { 0 }
		gl_func_subtract { 1 }
		gl_func_reverse_subtract { 2 }
		else { none }
	}
}

pub fn (mut c Context) blend_func_separate(src_rgb u32, dst_rgb u32, src_alpha u32, dst_alpha u32) {
	factor_code(src_rgb, true) or {
		c.set_error(gl_invalid_enum)
		return
	}
	factor_code(src_alpha, true) or {
		c.set_error(gl_invalid_enum)
		return
	}
	factor_code(dst_rgb, false) or {
		c.set_error(gl_invalid_enum)
		return
	}
	factor_code(dst_alpha, false) or {
		c.set_error(gl_invalid_enum)
		return
	}
	c.blend.src_rgb = src_rgb
	c.blend.dst_rgb = dst_rgb
	c.blend.src_alpha = src_alpha
	c.blend.dst_alpha = dst_alpha
}

pub fn (mut c Context) blend_func(src u32, dst u32) {
	c.blend_func_separate(src, dst, src, dst)
}

pub fn (mut c Context) blend_equation_separate(rgb u32, alpha u32) {
	equation_code(rgb) or {
		c.set_error(gl_invalid_enum)
		return
	}
	equation_code(alpha) or {
		c.set_error(gl_invalid_enum)
		return
	}
	c.blend.eq_rgb = rgb
	c.blend.eq_alpha = alpha
}

pub fn (mut c Context) blend_equation(mode u32) {
	c.blend_equation_separate(mode, mode)
}

// blend_color values are clamped to [0, 1] when stored, as GL specifies.
pub fn (mut c Context) blend_color(r f32, g f32, b f32, a f32) {
	c.blend.color = [clamp01(r), clamp01(g), clamp01(b), clamp01(a)]!
}

fn clamp01(v f32) f32 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}

pub fn (mut c Context) color_mask(r bool, g bool, b bool, a bool) {
	c.blend.mask = [r, g, b, a]!
}

fn (b &BlendState) full_mask() bool {
	return b.mask[0] && b.mask[1] && b.mask[2] && b.mask[3]
}

// blend_key identifies the blend configuration inside the pipeline cache.
// With blending off only the write mask matters.
fn (c &Context) blend_key() string {
	b := c.blend
	mask := '${int(b.mask[0])}${int(b.mask[1])}${int(b.mask[2])}${int(b.mask[3])}'
	if !c.blend_enabled {
		return 'off:${mask}'
	}
	return '${b.src_rgb}:${b.dst_rgb}:${b.src_alpha}:${b.dst_alpha}:${b.eq_rgb}:${b.eq_alpha}:${mask}'
}

// blend_codes returns the backend numbering of the six blend settings, or an
// empty slice when blending is disabled.
fn (c &Context) blend_codes() []i32 {
	if !c.blend_enabled {
		return []i32{}
	}
	b := c.blend
	return [factor_code(b.src_rgb, true) or { 1 }, factor_code(b.dst_rgb, false) or { 0 },
		factor_code(b.src_alpha, true) or { 1 }, factor_code(b.dst_alpha, false) or { 0 },
		equation_code(b.eq_rgb) or { 0 }, equation_code(b.eq_alpha) or { 0 }]
}

// mask_bits packs the write mask as R=1, G=2, B=4, A=8.
fn (c &Context) mask_bits() i32 {
	mut bits := i32(0)
	for i in 0 .. 4 {
		if c.blend.mask[i] {
			bits |= i32(1) << i
		}
	}
	return bits
}
