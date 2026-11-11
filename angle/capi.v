// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// C ABI for the V EGL/GLES core. Built as a shared library, these symbols
// replace libEGL and libGLESv2: webgl/native_egl.h resolves them by name.
//
// Differences from a real driver, all deliberate:
//  - EGL handles are small nonzero integers, not pointers.
//  - GL calls act on one process-wide current context (no per-thread binding),
//    which matches WebGL's single GPU thread. Calls without a current context
//    do nothing, as in GL.
//  - Entry points outside the implemented core are absent. The dispatch table
//    requires every symbol, so this library cannot yet back WebGL on its own;
//    see README.md.

__global (
	capi_display  &Display
	capi_current  &Context
	capi_contexts map[u64]&Context
	capi_configs  map[u64]Config
	capi_next_id  u64
	capi_last_egl int
)

const egl_true = u32(1)
const egl_false = u32(0)
const egl_renderable_type_attr = 0x3040
const egl_context_client_version_attr = 0x3098
const egl_none_attr = 0x3038

fn capi_id() u64 {
	capi_next_id++
	return capi_next_id
}

fn capi_fail(code int) u32 {
	capi_last_egl = code
	return egl_false
}

fn capi_ctx() ?&Context {
	if capi_current == unsafe { nil } {
		return none
	}
	return capi_current
}

// capi_attr_list reads an EGL attribute list ({key, value}* EGL_NONE) of
// 32-bit ints into a map. A nil list is empty.
fn capi_attr_list(attribs voidptr) map[int]int {
	mut out := map[int]int{}
	if attribs == unsafe { nil } {
		return out
	}
	p := unsafe { &i32(attribs) }
	mut i := 0
	for {
		key := unsafe { int(p[i]) }
		if key == egl_none_attr {
			break
		}
		out[key] = unsafe { int(p[i + 1]) }
		i += 2
		if i > 4096 {
			break
		}
	}
	return out
}

@[export: 'eglGetPlatformDisplay']
pub fn capi_egl_get_platform_display(platform u32, native voidptr, attribs voidptr) voidptr {
	if capi_display == unsafe { nil } {
		d := initialize_display(.metal) or {
			capi_last_egl = egl_not_initialized
			return unsafe { nil }
		}
		capi_display = d
	}
	return voidptr(u64(1))
}

@[export: 'eglInitialize']
pub fn capi_egl_initialize(display voidptr, major &i32, minor &i32) u32 {
	if capi_display == unsafe { nil } || u64(display) != 1 {
		return capi_fail(egl_bad_display)
	}
	unsafe {
		if major != nil {
			*major = 1
		}
		if minor != nil {
			*minor = 5
		}
	}
	return egl_true
}

@[export: 'eglChooseConfig']
pub fn capi_egl_choose_config(display voidptr, attribs voidptr, configs &voidptr, size i32, num &i32) u32 {
	if capi_display == unsafe { nil } || u64(display) != 1 {
		return capi_fail(egl_bad_display)
	}
	if num == unsafe { nil } {
		return capi_fail(egl_bad_parameter)
	}
	list := capi_attr_list(attribs)
	renderable := list[egl_renderable_type_attr] or { egl_opengl_es3_bit }
	config := capi_display.choose_config(renderable) or {
		return capi_fail(err.code())
	}
	id := capi_id()
	capi_configs[id] = config
	unsafe {
		if configs != nil && size > 0 {
			configs[0] = voidptr(id)
			*num = 1
		} else {
			*num = 1
		}
	}
	return egl_true
}

@[export: 'eglCreateContext']
pub fn capi_egl_create_context(display voidptr, config voidptr, share voidptr, attribs voidptr) voidptr {
	if capi_display == unsafe { nil } || u64(display) != 1 {
		capi_last_egl = egl_bad_display
		return unsafe { nil }
	}
	cfg := capi_configs[u64(config)] or {
		capi_last_egl = egl_bad_config
		return unsafe { nil }
	}
	list := capi_attr_list(attribs)
	version := list[egl_context_client_version_attr] or { 1 }
	// ES 3.0 entry points are not implemented, so an ES3 request fails like an
	// unsupported version on a real driver and the caller falls back to ES2.
	if version == 3 {
		capi_last_egl = egl_bad_attribute
		return unsafe { nil }
	}
	ctx := capi_display.create_context(cfg, version) or {
		capi_last_egl = err.code()
		return unsafe { nil }
	}
	id := capi_id()
	capi_contexts[id] = ctx
	return voidptr(id)
}

@[export: 'eglDestroyContext']
pub fn capi_egl_destroy_context(display voidptr, context voidptr) u32 {
	mut ctx := capi_contexts[u64(context)] or { return capi_fail(egl_bad_context) }
	if voidptr(capi_current) == voidptr(ctx) {
		capi_current = unsafe { nil }
	}
	capi_display.destroy_context(mut ctx)
	capi_contexts.delete(u64(context))
	return egl_true
}

// eglMakeCurrent supports only the surfaceless form WebGL uses, plus unbinding.
@[export: 'eglMakeCurrent']
pub fn capi_egl_make_current(display voidptr, draw voidptr, read voidptr, context voidptr) u32 {
	if capi_display == unsafe { nil } || u64(display) != 1 {
		return capi_fail(egl_bad_display)
	}
	if context == unsafe { nil } {
		capi_display.unbind()
		capi_current = unsafe { nil }
		return egl_true
	}
	if draw != unsafe { nil } || read != unsafe { nil } {
		return capi_fail(egl_bad_surface)
	}
	mut ctx := capi_contexts[u64(context)] or { return capi_fail(egl_bad_context) }
	capi_display.make_current_surfaceless(mut ctx) or { return capi_fail(err.code()) }
	capi_current = ctx
	return egl_true
}

@[export: 'eglGetError']
pub fn capi_egl_get_error() i32 {
	code := if capi_last_egl == 0 { egl_success } else { capi_last_egl }
	capi_last_egl = 0
	return i32(code)
}

// ---- GL ----

@[export: 'glGetError']
pub fn capi_gl_get_error() u32 {
	mut c := capi_ctx() or { return gl_no_error }
	return c.get_error()
}

@[export: 'glClearColor']
pub fn capi_gl_clear_color(r f32, g f32, b f32, a f32) {
	mut c := capi_ctx() or { return }
	c.set_clear_color(r, g, b, a)
}

@[export: 'glClear']
pub fn capi_gl_clear(mask u32) {
	mut c := capi_ctx() or { return }
	c.clear(mask)
}

@[export: 'glViewport']
pub fn capi_gl_viewport(x i32, y i32, w i32, h i32) {
	mut c := capi_ctx() or { return }
	c.viewport(int(x), int(y), int(w), int(h))
}

@[export: 'glScissor']
pub fn capi_gl_scissor(x i32, y i32, w i32, h i32) {
	mut c := capi_ctx() or { return }
	c.scissor(int(x), int(y), int(w), int(h))
}

@[export: 'glEnable']
pub fn capi_gl_enable(cap u32) {
	mut c := capi_ctx() or { return }
	c.enable(cap)
}

@[export: 'glDisable']
pub fn capi_gl_disable(cap u32) {
	mut c := capi_ctx() or { return }
	c.disable(cap)
}

// capi_bytes copies n bytes from a C pointer; a nil pointer is an empty slice.
fn capi_bytes(data voidptr, n int) []u8 {
	if data == unsafe { nil } || n <= 0 {
		return []u8{}
	}
	mut out := []u8{len: n}
	unsafe { vmemcpy(out.data, data, n) }
	return out
}

@[export: 'glGenBuffers']
pub fn capi_gl_gen_buffers(n i32, out &u32) {
	mut c := capi_ctx() or { return }
	for i in 0 .. int(n) {
		unsafe {
			out[i] = c.gen_buffer()
		}
	}
}

@[export: 'glBindBuffer']
pub fn capi_gl_bind_buffer(target u32, name u32) {
	mut c := capi_ctx() or { return }
	c.bind_buffer(target, name)
}

@[export: 'glBufferData']
pub fn capi_gl_buffer_data(target u32, size i64, data voidptr, usage u32) {
	mut c := capi_ctx() or { return }
	c.buffer_data(target, int(size), capi_bytes(data, int(size)), usage)
}

@[export: 'glBufferSubData']
pub fn capi_gl_buffer_sub_data(target u32, offset i64, size i64, data voidptr) {
	mut c := capi_ctx() or { return }
	c.buffer_sub_data(target, int(offset), capi_bytes(data, int(size)))
}

@[export: 'glDeleteBuffers']
pub fn capi_gl_delete_buffers(n i32, names &u32) {
	mut c := capi_ctx() or { return }
	for i in 0 .. int(n) {
		unsafe {
			c.delete_buffer(names[i])
		}
	}
}

@[export: 'glGenTextures']
pub fn capi_gl_gen_textures(n i32, out &u32) {
	mut c := capi_ctx() or { return }
	for i in 0 .. int(n) {
		unsafe {
			out[i] = c.gen_texture()
		}
	}
}

@[export: 'glBindTexture']
pub fn capi_gl_bind_texture(target u32, name u32) {
	mut c := capi_ctx() or { return }
	c.bind_texture(target, name)
}

// vox_angle_tex_image_2d is glTexImage2D with format and type packed into
// one argument ((format << 32) | type): V's export wrappers mishandle more
// than eight parameters. capi_shim.h supplies the real entry point.
@[export: 'vox_angle_tex_image_2d']
pub fn capi_gl_tex_image_2d(target u32, level i32, internal_format i32, w i32, h i32, border i32, format_type u64, pixels voidptr) {
	mut c := capi_ctx() or { return }
	if border != 0 {
		c.set_error(gl_invalid_value)
		return
	}
	c.tex_image_2d(target, int(level), u32(internal_format), int(w), int(h), u32(format_type >> 32),
		u32(format_type & 0xffffffff), capi_bytes(pixels, int(w) * int(h) * 4))
}

@[export: 'glDeleteTextures']
pub fn capi_gl_delete_textures(n i32, names &u32) {
	mut c := capi_ctx() or { return }
	for i in 0 .. int(n) {
		unsafe {
			c.delete_texture(names[i])
		}
	}
}

@[export: 'glGenFramebuffers']
pub fn capi_gl_gen_framebuffers(n i32, out &u32) {
	mut c := capi_ctx() or { return }
	for i in 0 .. int(n) {
		unsafe {
			out[i] = c.gen_framebuffer()
		}
	}
}

@[export: 'glBindFramebuffer']
pub fn capi_gl_bind_framebuffer(target u32, name u32) {
	mut c := capi_ctx() or { return }
	c.bind_framebuffer(target, name)
}

@[export: 'glFramebufferTexture2D']
pub fn capi_gl_framebuffer_texture_2d(target u32, attachment u32, textarget u32, texture u32, level i32) {
	mut c := capi_ctx() or { return }
	c.framebuffer_texture_2d(target, attachment, textarget, texture, int(level))
}

@[export: 'glCheckFramebufferStatus']
pub fn capi_gl_check_framebuffer_status(target u32) u32 {
	mut c := capi_ctx() or { return 0 }
	return c.check_framebuffer_status(target)
}

@[export: 'glDeleteFramebuffers']
pub fn capi_gl_delete_framebuffers(n i32, names &u32) {
	mut c := capi_ctx() or { return }
	for i in 0 .. int(n) {
		unsafe {
			c.delete_framebuffer(names[i])
		}
	}
}

@[export: 'glReadPixels']
pub fn capi_gl_read_pixels(x i32, y i32, w i32, h i32, format u32, typ u32, data voidptr) {
	mut c := capi_ctx() or { return }
	px := c.read_pixels(int(x), int(y), int(w), int(h), format, typ)
	if px.len > 0 && data != unsafe { nil } {
		unsafe { vmemcpy(data, px.data, px.len) }
	}
}
