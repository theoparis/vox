// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// C ABI for blending and the color write mask.

@[export: 'glBlendFunc']
pub fn capi_gl_blend_func(src u32, dst u32) {
	mut c := capi_ctx() or { return }
	c.blend_func(src, dst)
}

@[export: 'glBlendFuncSeparate']
pub fn capi_gl_blend_func_separate(src_rgb u32, dst_rgb u32, src_alpha u32, dst_alpha u32) {
	mut c := capi_ctx() or { return }
	c.blend_func_separate(src_rgb, dst_rgb, src_alpha, dst_alpha)
}

@[export: 'glBlendEquation']
pub fn capi_gl_blend_equation(mode u32) {
	mut c := capi_ctx() or { return }
	c.blend_equation(mode)
}

@[export: 'glBlendEquationSeparate']
pub fn capi_gl_blend_equation_separate(rgb u32, alpha u32) {
	mut c := capi_ctx() or { return }
	c.blend_equation_separate(rgb, alpha)
}

@[export: 'glBlendColor']
pub fn capi_gl_blend_color(r f32, g f32, b f32, a f32) {
	mut c := capi_ctx() or { return }
	c.blend_color(r, g, b, a)
}

@[export: 'glColorMask']
pub fn capi_gl_color_mask(r u8, g u8, b u8, a u8) {
	mut c := capi_ctx() or { return }
	c.color_mask(r != 0, g != 0, b != 0, a != 0)
}
