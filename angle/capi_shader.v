// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// C ABI for shaders, programs, uniforms, vertex attributes and draws. See
// capi.v for the conventions shared by every exported entry point.

const gl_delete_status = u32(0x8B80)
const gl_compile_status = u32(0x8B81)
const gl_link_status = u32(0x8B82)
const gl_shader_type_query = u32(0x8B4F)
const gl_info_log_length = u32(0x8B84)

// capi_string reads a C string of n bytes, or up to NUL when n is negative.
fn capi_string(p voidptr, n int) string {
	if p == unsafe { nil } {
		return ''
	}
	if n < 0 {
		return unsafe { cstring_to_vstring(&char(p)) }.clone()
	}
	return unsafe { tos(&u8(p), n) }.clone()
}

// capi_write_log copies a log into a caller buffer of size bytes, always
// NUL-terminated when size > 0, and reports the characters written.
fn capi_write_log(log string, size i32, length &i32, out voidptr) {
	mut n := 0
	if size > 0 && out != unsafe { nil } {
		n = if log.len < int(size) - 1 { log.len } else { int(size) - 1 }
		unsafe {
			if n > 0 {
				vmemcpy(out, log.str, n)
			}
			(&u8(out))[n] = 0
		}
	}
	if length != unsafe { nil } {
		unsafe {
			*length = i32(n)
		}
	}
}

@[export: 'glCreateShader']
pub fn capi_gl_create_shader(kind u32) u32 {
	mut c := capi_ctx() or { return 0 }
	return c.create_shader(kind)
}

@[export: 'glShaderSource']
pub fn capi_gl_shader_source(shader u32, count i32, strings &voidptr, lengths &i32) {
	mut c := capi_ctx() or { return }
	if count < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	mut source := ''
	for i in 0 .. int(count) {
		n := if lengths == unsafe { nil } { -1 } else { unsafe { int(lengths[i]) } }
		source += capi_string(unsafe { strings[i] }, n)
	}
	c.shader_source(shader, source)
}

@[export: 'glCompileShader']
pub fn capi_gl_compile_shader(shader u32) {
	mut c := capi_ctx() or { return }
	c.compile_shader(shader)
}

@[export: 'glGetShaderiv']
pub fn capi_gl_get_shaderiv(shader u32, pname u32, out &i32) {
	mut c := capi_ctx() or { return }
	if shader !in c.shaders {
		c.set_error(gl_invalid_value)
		return
	}
	unsafe {
		match pname {
			gl_compile_status { *out = if c.shader_compiled(shader) { 1 } else { 0 } }
			gl_info_log_length { log := c.shader_log(shader)
				*out = if log.len == 0 { 0 } else { i32(log.len + 1) } }
			gl_shader_type_query { *out = if c.shaders[shader].kind == .vertex { i32(gl_vertex_shader) } else { i32(gl_fragment_shader) } }
			gl_delete_status { *out = 0 }
			else { c.set_error(gl_invalid_enum) }
		}
	}
}

@[export: 'glGetShaderInfoLog']
pub fn capi_gl_get_shader_info_log(shader u32, size i32, length &i32, out voidptr) {
	mut c := capi_ctx() or { return }
	if shader !in c.shaders {
		c.set_error(gl_invalid_value)
		return
	}
	capi_write_log(c.shader_log(shader), size, length, out)
}

@[export: 'glCreateProgram']
pub fn capi_gl_create_program() u32 {
	mut c := capi_ctx() or { return 0 }
	return c.create_program()
}

@[export: 'glAttachShader']
pub fn capi_gl_attach_shader(program u32, shader u32) {
	mut c := capi_ctx() or { return }
	c.attach_shader(program, shader)
}

@[export: 'glLinkProgram']
pub fn capi_gl_link_program(program u32) {
	mut c := capi_ctx() or { return }
	c.link_program(program)
}

@[export: 'glGetProgramiv']
pub fn capi_gl_get_programiv(program u32, pname u32, out &i32) {
	mut c := capi_ctx() or { return }
	if program !in c.programs {
		c.set_error(gl_invalid_value)
		return
	}
	unsafe {
		match pname {
			gl_link_status { *out = if c.program_linked(program) { 1 } else { 0 } }
			gl_info_log_length { log := c.program_log(program)
				*out = if log.len == 0 { 0 } else { i32(log.len + 1) } }
			gl_delete_status { *out = 0 }
			else { c.set_error(gl_invalid_enum) }
		}
	}
}

@[export: 'glGetProgramInfoLog']
pub fn capi_gl_get_program_info_log(program u32, size i32, length &i32, out voidptr) {
	mut c := capi_ctx() or { return }
	if program !in c.programs {
		c.set_error(gl_invalid_value)
		return
	}
	capi_write_log(c.program_log(program), size, length, out)
}

@[export: 'glUseProgram']
pub fn capi_gl_use_program(program u32) {
	mut c := capi_ctx() or { return }
	c.use_program(program)
}

@[export: 'glGetAttribLocation']
pub fn capi_gl_get_attrib_location(program u32, name voidptr) i32 {
	mut c := capi_ctx() or { return -1 }
	return i32(c.attrib_location(program, capi_string(name, -1)))
}

@[export: 'glGetUniformLocation']
pub fn capi_gl_get_uniform_location(program u32, name voidptr) i32 {
	mut c := capi_ctx() or { return -1 }
	return i32(c.uniform_location(program, capi_string(name, -1)))
}

// glVertexAttribPointer: the pointer argument is a byte offset into the bound
// ARRAY_BUFFER. Only float attributes exist; normalized has no effect on them.
@[export: 'glVertexAttribPointer']
pub fn capi_gl_vertex_attrib_pointer(index u32, size i32, typ u32, normalized u8, stride i32, offset voidptr) {
	mut c := capi_ctx() or { return }
	c.vertex_attrib_pointer(int(index), int(size), typ, int(stride), int(u64(offset)))
}

@[export: 'glEnableVertexAttribArray']
pub fn capi_gl_enable_vertex_attrib_array(index u32) {
	mut c := capi_ctx() or { return }
	c.enable_vertex_attrib(int(index), true)
}

@[export: 'glDisableVertexAttribArray']
pub fn capi_gl_disable_vertex_attrib_array(index u32) {
	mut c := capi_ctx() or { return }
	c.enable_vertex_attrib(int(index), false)
}

// capi_floats copies n floats from a C pointer.
fn capi_floats(p &f32, n int) []f32 {
	mut out := []f32{len: n}
	for i in 0 .. n {
		out[i] = unsafe { p[i] }
	}
	return out
}

@[export: 'glUniform1f']
pub fn capi_gl_uniform1f(loc i32, x f32) {
	mut c := capi_ctx() or { return }
	c.uniform_floats(int(loc), [x])
}

@[export: 'glUniform2f']
pub fn capi_gl_uniform2f(loc i32, x f32, y f32) {
	mut c := capi_ctx() or { return }
	c.uniform_floats(int(loc), [x, y])
}

@[export: 'glUniform3f']
pub fn capi_gl_uniform3f(loc i32, x f32, y f32, z f32) {
	mut c := capi_ctx() or { return }
	c.uniform_floats(int(loc), [x, y, z])
}

@[export: 'glUniform4f']
pub fn capi_gl_uniform4f(loc i32, x f32, y f32, z f32, w f32) {
	mut c := capi_ctx() or { return }
	c.uniform_floats(int(loc), [x, y, z, w])
}

@[export: 'glUniform1i']
pub fn capi_gl_uniform1i(loc i32, x i32) {
	mut c := capi_ctx() or { return }
	c.uniform_ints(int(loc), [int(x)])
}

// capi_uniform_vector handles glUniform{1,2,3,4}fv. Uniform arrays are not
// supported by the shader subset, so count must be 1.
fn capi_uniform_vector(n int, loc i32, count i32, v &f32) {
	mut c := capi_ctx() or { return }
	if count < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	if count != 1 || v == unsafe { nil } {
		c.set_error(gl_invalid_operation)
		return
	}
	c.uniform_floats(int(loc), capi_floats(v, n))
}

@[export: 'glUniform1fv']
pub fn capi_gl_uniform1fv(loc i32, count i32, v &f32) {
	capi_uniform_vector(1, loc, count, v)
}

@[export: 'glUniform2fv']
pub fn capi_gl_uniform2fv(loc i32, count i32, v &f32) {
	capi_uniform_vector(2, loc, count, v)
}

@[export: 'glUniform3fv']
pub fn capi_gl_uniform3fv(loc i32, count i32, v &f32) {
	capi_uniform_vector(3, loc, count, v)
}

@[export: 'glUniform4fv']
pub fn capi_gl_uniform4fv(loc i32, count i32, v &f32) {
	capi_uniform_vector(4, loc, count, v)
}

fn capi_uniform_matrix(n int, loc i32, count i32, transpose u8, v &f32) {
	mut c := capi_ctx() or { return }
	if count < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	if count != 1 || v == unsafe { nil } {
		c.set_error(gl_invalid_operation)
		return
	}
	c.uniform_matrix(int(loc), transpose != 0, capi_floats(v, n * n))
}

@[export: 'glUniformMatrix2fv']
pub fn capi_gl_uniform_matrix2fv(loc i32, count i32, transpose u8, v &f32) {
	capi_uniform_matrix(2, loc, count, transpose, v)
}

@[export: 'glUniformMatrix3fv']
pub fn capi_gl_uniform_matrix3fv(loc i32, count i32, transpose u8, v &f32) {
	capi_uniform_matrix(3, loc, count, transpose, v)
}

@[export: 'glUniformMatrix4fv']
pub fn capi_gl_uniform_matrix4fv(loc i32, count i32, transpose u8, v &f32) {
	capi_uniform_matrix(4, loc, count, transpose, v)
}

@[export: 'glDrawArrays']
pub fn capi_gl_draw_arrays(mode u32, first i32, count i32) {
	mut c := capi_ctx() or { return }
	c.draw_arrays(mode, int(first), int(count))
}
