// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Vertex array objects. A VAO owns the 16 attribute pointers (with their
// enables and divisors) and the ELEMENT_ARRAY_BUFFER binding. The context keeps
// the bound VAO's state in `attribs` and `bound_buffers`, so draws read it
// directly; binding another VAO swaps that state with the stored copy. The
// generic constant attribute values (glVertexAttrib*) are context state, not
// VAO state, as in GL.

struct VertexArray {
mut:
	attribs        [16]AttribPointer
	element_buffer u32
	// used becomes true on first bind; glIsVertexArray is false before that.
	used bool
}

pub fn (mut c Context) gen_vertex_array() u32 {
	name := c.new_name()
	c.vaos[name] = VertexArray{}
	return name
}

// bind_vertex_array makes name current; 0 is the default array. An unknown
// name is INVALID_OPERATION.
pub fn (mut c Context) bind_vertex_array(name u32) {
	if name != 0 && name !in c.vaos {
		c.set_error(gl_invalid_operation)
		return
	}
	if name == c.bound_vao {
		if name != 0 {
			mut v := c.vaos[name]
			v.used = true
			c.vaos[name] = v
		}
		return
	}
	saved := VertexArray{
		attribs:        c.attribs
		element_buffer: c.bound_buffers[gl_element_array_buffer] or { 0 }
		used:           true
	}
	if c.bound_vao == 0 {
		c.default_vao = saved
	} else {
		c.vaos[c.bound_vao] = saved
	}
	mut next := if name == 0 { c.default_vao } else { c.vaos[name] }
	c.attribs = next.attribs
	c.bound_buffers[gl_element_array_buffer] = next.element_buffer
	if name != 0 {
		next.used = true
		c.vaos[name] = next
	}
	c.bound_vao = name
}

pub fn (mut c Context) delete_vertex_array(name u32) {
	if name == 0 || name !in c.vaos {
		return
	}
	if c.bound_vao == name {
		c.bind_vertex_array(0)
	}
	c.vaos.delete(name)
}

pub fn (c &Context) is_vertex_array(name u32) bool {
	return name != 0 && name in c.vaos && c.vaos[name].used
}
