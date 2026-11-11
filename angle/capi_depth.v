// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// C ABI for depth, culling and renderbuffers.

@[export: 'glDepthFunc']
pub fn capi_gl_depth_func(f u32) {
	mut c := capi_ctx() or { return }
	c.depth_func(f)
}

@[export: 'glDepthMask']
pub fn capi_gl_depth_mask(on u8) {
	mut c := capi_ctx() or { return }
	c.depth_mask(on != 0)
}

@[export: 'glClearDepthf']
pub fn capi_gl_clear_depthf(v f32) {
	mut c := capi_ctx() or { return }
	c.clear_depth(v)
}

@[export: 'glDepthRangef']
pub fn capi_gl_depth_rangef(near f32, far f32) {
	mut c := capi_ctx() or { return }
	c.depth_range(near, far)
}

@[export: 'glCullFace']
pub fn capi_gl_cull_face(mode u32) {
	mut c := capi_ctx() or { return }
	c.cull_face(mode)
}

@[export: 'glFrontFace']
pub fn capi_gl_front_face(mode u32) {
	mut c := capi_ctx() or { return }
	c.front_face(mode)
}

@[export: 'glGenRenderbuffers']
pub fn capi_gl_gen_renderbuffers(n i32, out &u32) {
	mut c := capi_ctx() or { return }
	for i in 0 .. int(n) {
		unsafe {
			out[i] = c.gen_renderbuffer()
		}
	}
}

@[export: 'glBindRenderbuffer']
pub fn capi_gl_bind_renderbuffer(target u32, name u32) {
	mut c := capi_ctx() or { return }
	c.bind_renderbuffer(target, name)
}

@[export: 'glRenderbufferStorage']
pub fn capi_gl_renderbuffer_storage(target u32, format u32, w i32, h i32) {
	mut c := capi_ctx() or { return }
	c.renderbuffer_storage(target, format, int(w), int(h))
}

@[export: 'glFramebufferRenderbuffer']
pub fn capi_gl_framebuffer_renderbuffer(target u32, attachment u32, rbtarget u32, rb u32) {
	mut c := capi_ctx() or { return }
	c.framebuffer_renderbuffer(target, attachment, rbtarget, rb)
}

@[export: 'glDeleteRenderbuffers']
pub fn capi_gl_delete_renderbuffers(n i32, names &u32) {
	mut c := capi_ctx() or { return }
	for i in 0 .. int(n) {
		unsafe {
			c.delete_renderbuffer(names[i])
		}
	}
}

@[export: 'glIsRenderbuffer']
pub fn capi_gl_is_renderbuffer(name u32) u8 {
	c := capi_ctx() or { return 0 }
	return capi_bool(c.is_renderbuffer(name))
}
