// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// EGL 1.5 error codes and enums used by the translation layer.
pub const egl_success = 0x3000
pub const egl_not_initialized = 0x3001
pub const egl_bad_access = 0x3002
pub const egl_bad_alloc = 0x3003
pub const egl_bad_attribute = 0x3004
pub const egl_bad_config = 0x3005
pub const egl_bad_context = 0x3006
pub const egl_bad_display = 0x3008
pub const egl_bad_match = 0x3009
pub const egl_bad_parameter = 0x300c
pub const egl_bad_surface = 0x300d
pub const egl_opengl_es2_bit = 0x0004
pub const egl_opengl_es3_bit = 0x0040
pub const egl_pbuffer_bit = 0x0001

// EglError carries the EGL error code that eglGetError would report.
pub struct EglError {
pub:
	egl_code int
	message  string
}

pub fn (e EglError) msg() string {
	return '${e.message} (EGL 0x${e.egl_code.hex()})'
}

pub fn (e EglError) code() int {
	return e.egl_code
}

// Display owns one backend and the EGL objects created from it. Like EGL,
// it records the most recent error until eglGetError-style retrieval.
@[heap]
pub struct Display {
mut:
	backend         Backend
	terminated      bool
	egl_error       int = egl_success
	current_context &Context = unsafe { nil }
}

// Config describes the single RGBA8888 pbuffer configuration offered for now.
pub struct Config {
pub:
	red_size        int = 8
	green_size      int = 8
	blue_size       int = 8
	alpha_size      int = 8
	depth_size      int = 24
	stencil_size    int // surfaces have no stencil buffer yet
	renderable_type int = egl_opengl_es2_bit | egl_opengl_es3_bit
	surface_type    int = egl_pbuffer_bit
}

// Surface is a pbuffer whose color texture is the default framebuffer.
@[heap]
pub struct Surface {
pub:
	width  int
	height int
mut:
	texture   u32
	depth     u32
	destroyed bool
}

// initialize_display creates the backend and returns a display that is ready
// for configuration. The Vulkan kind is reserved and reports unavailable.
pub fn initialize_display(kind BackendKind) !&Display {
	backend := new_backend(kind)!
	return &Display{
		backend: backend
	}
}

fn (mut d Display) fail(code int, message string) IError {
	d.egl_error = code
	return EglError{
		egl_code: code
		message:  message
	}
}

// get_error returns and clears the last EGL error, as eglGetError does.
pub fn (mut d Display) get_error() int {
	code := d.egl_error
	d.egl_error = egl_success
	return code
}

// choose_config returns the single available pbuffer configuration when the
// requested renderable type includes an OpenGL ES version the layer supports.
pub fn (mut d Display) choose_config(renderable_type int) !Config {
	if d.terminated {
		return d.fail(egl_not_initialized, 'display is terminated')
	}
	if renderable_type & (egl_opengl_es2_bit | egl_opengl_es3_bit) == 0 {
		return d.fail(egl_bad_attribute, 'renderable type must include an OpenGL ES bit')
	}
	return Config{
		renderable_type: egl_opengl_es2_bit | egl_opengl_es3_bit
	}
}

// create_pbuffer_surface allocates the surface's backend color texture.
pub fn (mut d Display) create_pbuffer_surface(width int, height int) !&Surface {
	if d.terminated {
		return d.fail(egl_not_initialized, 'display is terminated')
	}
	if width <= 0 || height <= 0 {
		return d.fail(egl_bad_parameter, 'pbuffer dimensions must be positive')
	}
	texture := d.backend.create_texture(width, height) or {
		return d.fail(egl_bad_alloc, err.msg())
	}
	// Zeroing the pbuffer gives the default framebuffer defined contents.
	d.backend.clear_texture(texture, 0, 0, 0, 0) or {
		d.backend.destroy_texture(texture)
		return d.fail(egl_bad_alloc, err.msg())
	}
	// The default framebuffer has a depth buffer, initially 1.0 as in GL.
	depth := d.backend.create_depth_texture(width, height) or {
		d.backend.destroy_texture(texture)
		return d.fail(egl_bad_alloc, err.msg())
	}
	d.backend.clear_depth(depth, 1.0) or {
		d.backend.destroy_texture(depth)
		d.backend.destroy_texture(texture)
		return d.fail(egl_bad_alloc, err.msg())
	}
	return &Surface{
		width:   width
		height:  height
		texture: texture
		depth:   depth
	}
}

// destroy_surface releases the color texture. A surface that is still bound
// to a context makes that context's default framebuffer incomplete.
pub fn (mut d Display) destroy_surface(mut surface Surface) {
	if surface.destroyed {
		return
	}
	d.backend.destroy_texture(surface.texture)
	if surface.depth != 0 {
		d.backend.destroy_texture(surface.depth)
	}
	surface.destroyed = true
}

// create_context validates the requested OpenGL ES version against the config.
pub fn (mut d Display) create_context(config Config, version int) !&Context {
	if d.terminated {
		return d.fail(egl_not_initialized, 'display is terminated')
	}
	if version != 2 && version != 3 {
		return d.fail(egl_bad_attribute, 'only OpenGL ES 2 and 3 contexts are supported')
	}
	needed := if version == 3 { egl_opengl_es3_bit } else { egl_opengl_es2_bit }
	if config.renderable_type & needed == 0 {
		return d.fail(egl_bad_config, 'config does not support the requested context version')
	}
	return new_context(unsafe { &d }, version)
}

// destroy_context unbinds the context when it is current, then releases its
// GL objects.
pub fn (mut d Display) destroy_context(mut context Context) {
	if context.destroyed {
		return
	}
	if voidptr(d.current_context) == voidptr(&context) {
		d.current_context = unsafe { nil }
		context.surface = unsafe { nil }
	}
	context.release_all()
	context.destroyed = true
}

// make_current binds a context to a surface. Passing nil for both unbinds.
pub fn (mut d Display) make_current(mut surface Surface, mut context Context) ! {
	if d.terminated {
		return d.fail(egl_not_initialized, 'display is terminated')
	}
	if context.destroyed {
		return d.fail(egl_bad_context, 'context is destroyed')
	}
	if surface.destroyed {
		return d.fail(egl_bad_surface, 'surface is destroyed')
	}
	d.current_context = &context
	context.surface = &surface
	context.display = unsafe { &d }
	context.reset_surface_state(surface.width, surface.height)
}

// make_current_surfaceless binds a context with no surface, as
// eglMakeCurrent(dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, ctx) does. Only
// framebuffer objects can then be drawn to; the default framebuffer is
// incomplete and its initial viewport and scissor are empty.
pub fn (mut d Display) make_current_surfaceless(mut context Context) ! {
	if d.terminated {
		return d.fail(egl_not_initialized, 'display is terminated')
	}
	if context.destroyed {
		return d.fail(egl_bad_context, 'context is destroyed')
	}
	d.current_context = &context
	context.surface = unsafe { nil }
	context.display = unsafe { &d }
	context.reset_surface_state(0, 0)
}

// unbind clears the current context, as eglMakeCurrent with no objects does.
pub fn (mut d Display) unbind() {
	if d.current_context != unsafe { nil } {
		d.current_context.surface = unsafe { nil }
	}
	d.current_context = unsafe { nil }
}

// current returns the context bound on this display, or nil when none is.
pub fn (d &Display) current() &Context {
	return d.current_context
}

// terminate releases every resource the backend still owns.
pub fn (mut d Display) terminate() {
	if d.terminated {
		return
	}
	d.unbind()
	d.backend.close()
	d.terminated = true
}
