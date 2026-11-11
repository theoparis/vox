// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// C ABI for vertex array objects and instanced drawing, including the OES and
// ANGLE extension spellings WebGL 1 resolves.

@[export: 'glGenVertexArrays']
pub fn capi_gl_gen_vertex_arrays(n i32, out &u32) {
	mut c := capi_ctx() or { return }
	if n < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	for i in 0 .. int(n) {
		unsafe {
			out[i] = c.gen_vertex_array()
		}
	}
}

@[export: 'glGenVertexArraysOES']
pub fn capi_gl_gen_vertex_arrays_oes(n i32, out &u32) {
	capi_gl_gen_vertex_arrays(n, out)
}

@[export: 'glBindVertexArray']
pub fn capi_gl_bind_vertex_array(name u32) {
	mut c := capi_ctx() or { return }
	c.bind_vertex_array(name)
}

@[export: 'glBindVertexArrayOES']
pub fn capi_gl_bind_vertex_array_oes(name u32) {
	capi_gl_bind_vertex_array(name)
}

@[export: 'glDeleteVertexArrays']
pub fn capi_gl_delete_vertex_arrays(n i32, names &u32) {
	mut c := capi_ctx() or { return }
	if n < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	for i in 0 .. int(n) {
		unsafe {
			c.delete_vertex_array(names[i])
		}
	}
}

@[export: 'glDeleteVertexArraysOES']
pub fn capi_gl_delete_vertex_arrays_oes(n i32, names &u32) {
	capi_gl_delete_vertex_arrays(n, names)
}

@[export: 'glIsVertexArray']
pub fn capi_gl_is_vertex_array(name u32) u8 {
	c := capi_ctx() or { return 0 }
	return capi_bool(c.is_vertex_array(name))
}

@[export: 'glIsVertexArrayOES']
pub fn capi_gl_is_vertex_array_oes(name u32) u8 {
	return capi_gl_is_vertex_array(name)
}

@[export: 'glVertexAttribDivisor']
pub fn capi_gl_vertex_attrib_divisor(index u32, divisor u32) {
	mut c := capi_ctx() or { return }
	c.vertex_attrib_divisor(int(index), int(divisor))
}

@[export: 'glVertexAttribDivisorANGLE']
pub fn capi_gl_vertex_attrib_divisor_angle(index u32, divisor u32) {
	capi_gl_vertex_attrib_divisor(index, divisor)
}

@[export: 'glDrawArraysInstanced']
pub fn capi_gl_draw_arrays_instanced(mode u32, first i32, count i32, instances i32) {
	mut c := capi_ctx() or { return }
	c.draw_arrays_instanced(mode, int(first), int(count), int(instances))
}

@[export: 'glDrawArraysInstancedANGLE']
pub fn capi_gl_draw_arrays_instanced_angle(mode u32, first i32, count i32, instances i32) {
	capi_gl_draw_arrays_instanced(mode, first, count, instances)
}

@[export: 'glDrawElementsInstanced']
pub fn capi_gl_draw_elements_instanced(mode u32, count i32, typ u32, indices voidptr, instances i32) {
	mut c := capi_ctx() or { return }
	c.draw_elements_instanced(mode, int(count), typ, int(u64(indices)), int(instances))
}

@[export: 'glDrawElementsInstancedANGLE']
pub fn capi_gl_draw_elements_instanced_angle(mode u32, count i32, typ u32, indices voidptr, instances i32) {
	capi_gl_draw_elements_instanced(mode, count, typ, indices, instances)
}
