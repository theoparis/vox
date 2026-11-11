// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Depth buffer, depth test, face culling, and renderbuffers. Depth is stored
// as 32-bit float; stencil is not implemented.

pub const gl_depth_test = u32(0x0B71)
pub const gl_cull_face_cap = u32(0x0B44)
pub const gl_never = u32(0x0200)
pub const gl_less = u32(0x0201)
pub const gl_equal = u32(0x0202)
pub const gl_lequal = u32(0x0203)
pub const gl_greater = u32(0x0204)
pub const gl_notequal = u32(0x0205)
pub const gl_gequal = u32(0x0206)
pub const gl_always = u32(0x0207)
pub const gl_front = u32(0x0404)
pub const gl_back = u32(0x0405)
pub const gl_front_and_back = u32(0x0408)
pub const gl_cw = u32(0x0900)
pub const gl_ccw = u32(0x0901)
pub const gl_renderbuffer = u32(0x8D41)
pub const gl_depth_component16 = u32(0x81A5)
pub const gl_depth_attachment = u32(0x8D00)
pub const gl_depth_func_pname = u32(0x0B74)
pub const gl_depth_writemask = u32(0x0B72)
pub const gl_depth_clear_value = u32(0x0B73)
pub const gl_depth_range_pname = u32(0x0B70)
pub const gl_cull_face_mode = u32(0x0B45)
pub const gl_front_face_pname = u32(0x0B46)
pub const gl_renderbuffer_binding = u32(0x8CA7)

// DepthState holds the depth and culling state. Fields are arranged so that
// the zero value is not relied on: new_context sets the GL defaults.
pub struct DepthState {
pub mut:
	test        bool
	func        u32 = gl_less
	mask_off    bool
	clear_value f32 = 1.0
	near        f32
	far         f32 = 1.0
	cull        bool
	cull_mode   u32 = gl_back
	front_face  u32 = gl_ccw
}

fn (d &DepthState) write_enabled() bool {
	return !d.mask_off
}

fn depth_func_code(f u32) ?i32 {
	return match f {
		gl_never { 0 }
		gl_less { 1 }
		gl_equal { 2 }
		gl_lequal { 3 }
		gl_greater { 4 }
		gl_notequal { 5 }
		gl_gequal { 6 }
		gl_always { 7 }
		else { none }
	}
}

pub fn (mut c Context) depth_func(f u32) {
	depth_func_code(f) or {
		c.set_error(gl_invalid_enum)
		return
	}
	c.depth.func = f
}

pub fn (mut c Context) depth_mask(on bool) {
	c.depth.mask_off = !on
}

pub fn (mut c Context) clear_depth(v f32) {
	c.depth.clear_value = clamp01(v)
}

// depth_range clamps both ends to [0, 1], as GL does.
pub fn (mut c Context) depth_range(near f32, far f32) {
	c.depth.near = clamp01(near)
	c.depth.far = clamp01(far)
}

pub fn (mut c Context) cull_face(mode u32) {
	if mode != gl_front && mode != gl_back && mode != gl_front_and_back {
		c.set_error(gl_invalid_enum)
		return
	}
	c.depth.cull_mode = mode
}

pub fn (mut c Context) front_face(mode u32) {
	if mode != gl_cw && mode != gl_ccw {
		c.set_error(gl_invalid_enum)
		return
	}
	c.depth.front_face = mode
}

// depth_key identifies pipeline-relevant depth configuration. Only the
// presence of a depth attachment is baked into the pipeline.
fn (c &Context) depth_key(target RenderTarget) string {
	return if target.depth != 0 { 'd' } else { 'n' }
}

// cull_code is the backend culling mode for a draw, or -1 when every
// triangle is culled (FRONT_AND_BACK).
fn (c &Context) cull_code() i32 {
	if !c.depth.cull {
		return 0
	}
	return match c.depth.cull_mode {
		gl_front { 1 }
		gl_back { 2 }
		else { -1 }
	}
}

// ---- Renderbuffers -------------------------------------------------------

pub fn (mut c Context) gen_renderbuffer() u32 {
	name := c.new_name()
	c.renderbuffers[name] = GLRenderbuffer{}
	return name
}

pub fn (mut c Context) bind_renderbuffer(target u32, name u32) {
	if target != gl_renderbuffer {
		c.set_error(gl_invalid_enum)
		return
	}
	if name != 0 && name !in c.renderbuffers {
		c.renderbuffers[name] = GLRenderbuffer{}
	}
	c.bound_renderbuffer = name
}

// renderbuffer_storage allocates a depth renderbuffer. Only
// DEPTH_COMPONENT16 exists; color and stencil formats are valid GL but not
// implemented, so they report INVALID_OPERATION rather than a wrong format.
pub fn (mut c Context) renderbuffer_storage(target u32, format u32, width int, height int) {
	if target != gl_renderbuffer {
		c.set_error(gl_invalid_enum)
		return
	}
	if width < 0 || height < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	name := c.bound_renderbuffer
	if name == 0 {
		c.set_error(gl_invalid_operation)
		return
	}
	if format != gl_depth_component16 {
		c.set_error(gl_invalid_operation)
		return
	}
	old := c.renderbuffers[name]
	if old.handle != 0 {
		c.display.backend.destroy_texture(old.handle)
	}
	c.renderbuffers[name] = GLRenderbuffer{}
	if width == 0 || height == 0 {
		return
	}
	handle := c.display.backend.create_depth_texture(width, height) or {
		c.set_error(gl_out_of_memory)
		return
	}
	c.display.backend.clear_depth(handle, 1.0) or {
		c.display.backend.destroy_texture(handle)
		c.set_error(gl_out_of_memory)
		return
	}
	c.renderbuffers[name] = GLRenderbuffer{
		handle: handle
		width:  width
		height: height
	}
}

pub fn (mut c Context) delete_renderbuffer(name u32) {
	if name == 0 || name !in c.renderbuffers {
		return
	}
	rb := c.renderbuffers[name]
	if rb.handle != 0 {
		c.display.backend.destroy_texture(rb.handle)
	}
	c.renderbuffers.delete(name)
	if c.bound_renderbuffer == name {
		c.bound_renderbuffer = 0
	}
	for fname, fb in c.framebuffers {
		if fb.depth_rb == name {
			mut updated := fb
			updated.depth_rb = 0
			c.framebuffers[fname] = updated
		}
	}
}

pub fn (c &Context) is_renderbuffer(name u32) bool {
	return name != 0 && name in c.renderbuffers
}

// framebuffer_renderbuffer attaches a depth renderbuffer to the bound
// framebuffer. Color and stencil renderbuffer attachments are not implemented.
pub fn (mut c Context) framebuffer_renderbuffer(target u32, attachment u32, rbtarget u32, rb u32) {
	if target != gl_framebuffer && target != gl_read_framebuffer && target != gl_draw_framebuffer {
		c.set_error(gl_invalid_enum)
		return
	}
	if rbtarget != gl_renderbuffer {
		c.set_error(gl_invalid_enum)
		return
	}
	if c.bound_framebuffer == 0 {
		c.set_error(gl_invalid_operation)
		return
	}
	if attachment != gl_depth_attachment {
		c.set_error(gl_invalid_operation)
		return
	}
	if rb != 0 && rb !in c.renderbuffers {
		c.set_error(gl_invalid_operation)
		return
	}
	mut fb := c.framebuffers[c.bound_framebuffer]
	fb.depth_rb = rb
	c.framebuffers[c.bound_framebuffer] = fb
}
