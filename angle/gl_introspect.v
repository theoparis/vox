// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Program, shader, uniform, attribute, texture, buffer and renderbuffer
// introspection. Every getter returns values as doubles (or none after
// recording the GL error), so the C layer can convert to the caller's type.

pub const gl_delete_status_pname = u32(0x8B80)
pub const gl_compile_status_pname = u32(0x8B81)
pub const gl_link_status_pname = u32(0x8B82)
pub const gl_validate_status = u32(0x8B83)
pub const gl_info_log_length_pname = u32(0x8B84)
pub const gl_attached_shaders = u32(0x8B85)
pub const gl_active_uniforms = u32(0x8B86)
pub const gl_active_uniform_max_length = u32(0x8B87)
pub const gl_shader_source_length = u32(0x8B88)
pub const gl_active_attributes = u32(0x8B89)
pub const gl_active_attribute_max_length = u32(0x8B8A)
pub const gl_shader_type_pname = u32(0x8B4F)
pub const gl_vertex_attrib_array_enabled = u32(0x8622)
pub const gl_vertex_attrib_array_size = u32(0x8623)
pub const gl_vertex_attrib_array_stride = u32(0x8624)
pub const gl_vertex_attrib_array_type = u32(0x8625)
pub const gl_current_vertex_attrib = u32(0x8626)
pub const gl_vertex_attrib_array_normalized = u32(0x886A)
pub const gl_vertex_attrib_array_pointer = u32(0x8645)
pub const gl_vertex_attrib_array_buffer_binding = u32(0x889F)
pub const gl_vertex_attrib_array_divisor = u32(0x88FE)
pub const gl_buffer_size = u32(0x8764)
pub const gl_buffer_usage = u32(0x8765)
pub const gl_renderbuffer_width = u32(0x8D42)
pub const gl_renderbuffer_height = u32(0x8D43)
pub const gl_renderbuffer_internal_format = u32(0x8D44)
pub const gl_renderbuffer_depth_size = u32(0x8D54)
pub const gl_renderbuffer_red_size = u32(0x8D50)
pub const gl_renderbuffer_green_size = u32(0x8D51)
pub const gl_renderbuffer_blue_size = u32(0x8D52)
pub const gl_renderbuffer_alpha_size = u32(0x8D53)
pub const gl_renderbuffer_stencil_size = u32(0x8D55)

fn b2f(v bool) f64 {
	return if v { 1.0 } else { 0.0 }
}

// type_enum is the GL type enum reported for a shader variable type.
fn type_enum(t Ty) u32 {
	return match t {
		.float_t { u32(0x1406) }
		.vec2 { u32(0x8B50) }
		.vec3 { u32(0x8B51) }
		.vec4 { u32(0x8B52) }
		.int_t { u32(0x1404) }
		.bool_t { u32(0x8B56) }
		.mat2 { u32(0x8B5A) }
		.mat3 { u32(0x8B5B) }
		.mat4 { u32(0x8B5C) }
		.sampler2d { u32(0x8B5E) }
		.void_t { u32(0) }
	}
}

pub fn (mut c Context) program_param(prog u32, pname u32) ?f64 {
	if prog !in c.programs {
		c.set_error(gl_invalid_value)
		return none
	}
	p := c.programs[prog]
	mut longest_attr := 0
	for a in p.attrs {
		if a.name.len + 1 > longest_attr {
			longest_attr = a.name.len + 1
		}
	}
	mut longest_uniform := 0
	for u in p.uniforms {
		if u.name.len + 1 > longest_uniform {
			longest_uniform = u.name.len + 1
		}
	}
	return match pname {
		gl_delete_status_pname {
			b2f(p.deleted)
		}
		gl_link_status_pname {
			b2f(p.linked)
		}
		gl_validate_status {
			b2f(p.validated)
		}
		gl_info_log_length_pname {
			if p.log.len == 0 { f64(0) } else { f64(p.log.len + 1) }
		}
		gl_attached_shaders {
			f64(int(p.vertex != 0) + int(p.fragment != 0))
		}
		gl_active_uniforms {
			f64(p.uniforms.len)
		}
		gl_active_uniform_max_length {
			f64(longest_uniform)
		}
		gl_active_attributes {
			f64(p.attrs.len)
		}
		gl_active_attribute_max_length {
			f64(longest_attr)
		}
		else {
			c.set_error(gl_invalid_enum)
			return none
		}
	}
}

pub fn (mut c Context) shader_param(shader u32, pname u32) ?f64 {
	if shader !in c.shaders {
		c.set_error(gl_invalid_value)
		return none
	}
	s := c.shaders[shader]
	return match pname {
		gl_delete_status_pname {
			b2f(s.deleted)
		}
		gl_compile_status_pname {
			b2f(s.ok)
		}
		gl_info_log_length_pname {
			if s.log.len == 0 { f64(0) } else { f64(s.log.len + 1) }
		}
		gl_shader_type_pname {
			if s.kind == .vertex { f64(gl_vertex_shader) } else { f64(gl_fragment_shader) }
		}
		gl_shader_source_length {
			if s.source.len == 0 { f64(0) } else { f64(s.source.len + 1) }
		}
		else {
			c.set_error(gl_invalid_enum)
			return none
		}
	}
}

// validate_program records whether the program could execute in the current
// state. A linked program always can here; sampler bindings are checked at draw.
pub fn (mut c Context) validate_program(prog u32) {
	if prog !in c.programs {
		c.set_error(gl_invalid_value)
		return
	}
	mut p := c.programs[prog]
	p.validated = p.linked
}

// bind_attrib_location requests a slot for an attribute; it takes effect at the
// next link.
pub fn (mut c Context) bind_attrib_location(prog u32, index int, name string) {
	if prog !in c.programs {
		c.set_error(gl_invalid_value)
		return
	}
	if index < 0 || index >= max_attribs {
		c.set_error(gl_invalid_value)
		return
	}
	if name.starts_with('gl_') {
		c.set_error(gl_invalid_operation)
		return
	}
	mut p := c.programs[prog]
	p.bound_attribs[name] = index
}

// ActiveInfo describes one active attribute or uniform.
pub struct ActiveInfo {
pub:
	name string
	typ  u32
	size int
}

pub fn (mut c Context) active_attrib(prog u32, index int) ?ActiveInfo {
	if prog !in c.programs {
		c.set_error(gl_invalid_value)
		return none
	}
	p := c.programs[prog]
	if index < 0 || index >= p.attrs.len {
		c.set_error(gl_invalid_value)
		return none
	}
	a := p.attrs[index]
	return ActiveInfo{
		name: a.name
		typ:  type_enum(a.ty)
		size: 1
	}
}

pub fn (mut c Context) active_uniform(prog u32, index int) ?ActiveInfo {
	if prog !in c.programs {
		c.set_error(gl_invalid_value)
		return none
	}
	p := c.programs[prog]
	if index < 0 || index >= p.uniforms.len {
		c.set_error(gl_invalid_value)
		return none
	}
	u := p.uniforms[index]
	return ActiveInfo{
		name: u.name
		typ:  type_enum(u.ty)
		size: 1
	}
}

// get_uniform returns the current value of a uniform in the program: its
// floats or integer, in declaration order (matrices column by column).
pub fn (mut c Context) get_uniform(prog u32, loc int) ?[]f64 {
	if prog !in c.programs {
		c.set_error(gl_invalid_value)
		return none
	}
	p := c.programs[prog]
	if !p.linked {
		c.set_error(gl_invalid_operation)
		return none
	}
	if loc < 0 || loc >= p.uniforms.len {
		c.set_error(gl_invalid_operation)
		return none
	}
	ty := p.uniforms[loc].ty
	data := p.uniform_data[loc]
	if ty == .int_t || ty == .sampler2d {
		return [f64(i32(get_u32(data, 0)))]
	}
	// Floats are packed as pack_floats lays them out: columns padded to 16
	// bytes (8 for mat2), float3 padded to 16.
	mut cols := 1
	mut rows := ty.comps()
	mut col_stride := 0
	if ty.mat_n() > 0 {
		cols = ty.mat_n()
		rows = cols
		col_stride = if cols == 2 { 8 } else { 16 }
	}
	mut out := []f64{}
	for col in 0 .. cols {
		for r in 0 .. rows {
			bits := get_u32(data, col * col_stride + r * 4)
			out << f64(unsafe { *(&f32(&bits)) })
		}
	}
	return out
}

pub fn (mut c Context) vertex_attrib_param(index int, pname u32) ?[]f64 {
	if index < 0 || index >= max_attribs {
		c.set_error(gl_invalid_value)
		return none
	}
	a := c.attribs[index]
	return match pname {
		gl_vertex_attrib_array_enabled {
			[b2f(a.enabled)]
		}
		gl_vertex_attrib_array_size {
			[f64(if a.size == 0 { 4 } else { a.size })]
		}
		gl_vertex_attrib_array_stride {
			[f64(a.stride)]
		}
		gl_vertex_attrib_array_type {
			[f64(gl_float)]
		}
		gl_vertex_attrib_array_normalized {
			[f64(0)]
		}
		gl_vertex_attrib_array_buffer_binding {
			[f64(a.buffer)]
		}
		gl_vertex_attrib_array_pointer {
			[f64(a.offset)]
		}
		gl_vertex_attrib_array_divisor {
			[f64(a.divisor)]
		}
		gl_current_vertex_attrib {
			v := c.attrib_const_value(index)
			[f64(v[0]), f64(v[1]), f64(v[2]), f64(v[3])]
		}
		else {
			c.set_error(gl_invalid_enum)
			return none
		}
	}
}

pub fn (mut c Context) tex_parameter_value(target u32, pname u32) ?f64 {
	if target != gl_texture_2d {
		c.set_error(gl_invalid_enum)
		return none
	}
	name := c.texture_units[c.active_unit]
	if name == 0 {
		c.set_error(gl_invalid_operation)
		return none
	}
	t := c.textures[name]
	return match pname {
		gl_texture_min_filter { f64(t.min_filter) }
		gl_texture_mag_filter { f64(t.mag_filter) }
		gl_texture_wrap_s { f64(t.wrap_s) }
		gl_texture_wrap_t { f64(t.wrap_t) }
		else {
			c.set_error(gl_invalid_enum)
			return none
		}
	}
}

pub fn (mut c Context) buffer_parameter(target u32, pname u32) ?f64 {
	name := c.bound_buffer(target) or { return none }
	b := c.buffers[name]
	return match pname {
		gl_buffer_size {
			f64(b.size)
		}
		gl_buffer_usage {
			f64(b.usage)
		}
		else {
			c.set_error(gl_invalid_enum)
			return none
		}
	}
}

pub fn (mut c Context) renderbuffer_parameter(target u32, pname u32) ?f64 {
	if target != gl_renderbuffer {
		c.set_error(gl_invalid_enum)
		return none
	}
	if c.bound_renderbuffer == 0 {
		c.set_error(gl_invalid_operation)
		return none
	}
	rb := c.renderbuffers[c.bound_renderbuffer]
	defined := rb.handle != 0
	return match pname {
		gl_renderbuffer_width {
			f64(rb.width)
		}
		gl_renderbuffer_height {
			f64(rb.height)
		}
		gl_renderbuffer_internal_format {
			f64(if defined { gl_depth_component16 } else { u32(0x8058) })
		}
		gl_renderbuffer_depth_size {
			f64(if defined { 16 } else { 0 })
		}
		gl_renderbuffer_red_size, gl_renderbuffer_green_size, gl_renderbuffer_blue_size,
		gl_renderbuffer_alpha_size, gl_renderbuffer_stencil_size {
			f64(0)
		}
		else {
			c.set_error(gl_invalid_enum)
			return none
		}
	}
}
