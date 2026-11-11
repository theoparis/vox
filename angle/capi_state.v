// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// C ABI for state queries, object lifetime and synchronization. See capi.v.

__global (
	capi_strings map[u32]string
)

@[export: 'glGetIntegerv']
pub fn capi_gl_get_integerv(pname u32, out &i32) {
	mut c := capi_ctx() or { return }
	values := c.get_integers(pname)
	for i, v in values {
		unsafe {
			out[i] = i32(v)
		}
	}
}

@[export: 'glGetFloatv']
pub fn capi_gl_get_floatv(pname u32, out &f32) {
	mut c := capi_ctx() or { return }
	values := c.get_floats(pname)
	for i, v in values {
		unsafe {
			out[i] = v
		}
	}
}

// glGetString returns a pointer that stays valid for the life of the process:
// each distinct answer is cached in a global.
@[export: 'glGetString']
pub fn capi_gl_get_string(name u32) voidptr {
	mut c := capi_ctx() or { return unsafe { nil } }
	text := c.get_string(name) or { return unsafe { nil } }
	if name !in capi_strings {
		capi_strings[name] = text
	}
	return voidptr(capi_strings[name].str)
}

@[export: 'glGetShaderPrecisionFormat']
pub fn capi_gl_get_shader_precision_format(stage u32, precision u32, range &i32, bits &i32) {
	mut c := capi_ctx() or { return }
	values := c.shader_precision_format(stage, precision)
	if values.len == 3 {
		unsafe {
			range[0] = i32(values[0])
			range[1] = i32(values[1])
			*bits = i32(values[2])
		}
	}
}

@[export: 'glGetShaderSource']
pub fn capi_gl_get_shader_source(shader u32, size i32, length &i32, out voidptr) {
	mut c := capi_ctx() or { return }
	source := c.get_shader_source(shader)
	capi_write_log(source, size, length, out)
}

@[export: 'glIsEnabled']
pub fn capi_gl_is_enabled(cap u32) u8 {
	mut c := capi_ctx() or { return 0 }
	return if c.is_enabled(cap) { u8(1) } else { u8(0) }
}

fn capi_bool(v bool) u8 {
	return if v { u8(1) } else { u8(0) }
}

@[export: 'glIsBuffer']
pub fn capi_gl_is_buffer(name u32) u8 {
	c := capi_ctx() or { return 0 }
	return capi_bool(c.is_buffer(name))
}

@[export: 'glIsTexture']
pub fn capi_gl_is_texture(name u32) u8 {
	c := capi_ctx() or { return 0 }
	return capi_bool(c.is_texture(name))
}

@[export: 'glIsFramebuffer']
pub fn capi_gl_is_framebuffer(name u32) u8 {
	c := capi_ctx() or { return 0 }
	return capi_bool(c.is_framebuffer(name))
}

@[export: 'glIsShader']
pub fn capi_gl_is_shader(name u32) u8 {
	c := capi_ctx() or { return 0 }
	return capi_bool(c.is_shader(name))
}

@[export: 'glIsProgram']
pub fn capi_gl_is_program(name u32) u8 {
	c := capi_ctx() or { return 0 }
	return capi_bool(c.is_program(name))
}

@[export: 'glDeleteShader']
pub fn capi_gl_delete_shader(name u32) {
	mut c := capi_ctx() or { return }
	c.delete_shader(name)
}

@[export: 'glDeleteProgram']
pub fn capi_gl_delete_program(name u32) {
	mut c := capi_ctx() or { return }
	c.delete_program(name)
}

@[export: 'glDetachShader']
pub fn capi_gl_detach_shader(program u32, shader u32) {
	mut c := capi_ctx() or { return }
	c.detach_shader(program, shader)
}

// Every backend submission blocks until the GPU finishes, so there is never
// pending work for flush or finish to wait on.
@[export: 'glFlush']
pub fn capi_gl_flush() {}

@[export: 'glFinish']
pub fn capi_gl_finish() {}
