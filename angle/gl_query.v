// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// State queries: glGet*, glGetString and glGetShaderPrecisionFormat. Values
// describe what this implementation really supports; an unsupported pname is
// GL_INVALID_ENUM rather than a guessed number.

pub const gl_viewport_pname = u32(0x0BA2)
pub const gl_scissor_box = u32(0x0C10)
pub const gl_color_clear_value = u32(0x0C22)
pub const gl_max_texture_size = u32(0x0D33)
pub const gl_max_viewport_dims = u32(0x0D3A)
pub const gl_max_vertex_attribs = u32(0x8869)
pub const gl_max_vertex_uniform_vectors = u32(0x8DFB)
pub const gl_max_varying_vectors = u32(0x8DFC)
pub const gl_max_fragment_uniform_vectors = u32(0x8DFD)
pub const gl_current_program = u32(0x8B8D)
pub const gl_array_buffer_binding = u32(0x8894)
pub const gl_element_array_buffer_binding = u32(0x8895)
pub const gl_framebuffer_binding = u32(0x8CA6)
pub const gl_texture_binding_2d = u32(0x8069)
pub const gl_max_texture_image_units = u32(0x8872)
pub const gl_max_combined_texture_image_units = u32(0x8B4D)
pub const gl_max_vertex_texture_image_units = u32(0x8B4C)
pub const gl_vendor = u32(0x1F00)
pub const gl_renderer = u32(0x1F01)
pub const gl_version = u32(0x1F02)
pub const gl_extensions = u32(0x1F03)
pub const gl_shading_language_version = u32(0x8B8C)

const max_texture_dimension = 16384

// supported_extensions are the extensions this context implements.
const supported_extensions = ['GL_ANGLE_instanced_arrays', 'GL_OES_vertex_array_object']

// query_values returns a pname's values as doubles, or none for an unknown
// pname. Integers are exact; float values keep their precision.
fn (c &Context) query_values(pname u32) ?[]f64 {
	return match pname {
		gl_viewport_pname {
			[f64(c.viewport[0]), f64(c.viewport[1]), f64(c.viewport[2]), f64(c.viewport[3])]
		}
		gl_scissor_box {
			[f64(c.scissor_rect[0]), f64(c.scissor_rect[1]), f64(c.scissor_rect[2]),
				f64(c.scissor_rect[3])]
		}
		gl_color_clear_value {
			[f64(c.clear_color[0]), f64(c.clear_color[1]), f64(c.clear_color[2]),
				f64(c.clear_color[3])]
		}
		gl_max_texture_size {
			[f64(max_texture_dimension)]
		}
		gl_max_viewport_dims {
			[f64(max_texture_dimension), f64(max_texture_dimension)]
		}
		gl_max_vertex_attribs {
			[f64(max_attribs)]
		}
		gl_max_vertex_uniform_vectors, gl_max_fragment_uniform_vectors {
			[f64(max_uniforms)]
		}
		gl_max_varying_vectors {
			[f64(max_varyings)]
		}
		gl_blend_color_pname {
			[f64(c.blend.color[0]), f64(c.blend.color[1]), f64(c.blend.color[2]),
				f64(c.blend.color[3])]
		}
		gl_blend_src_rgb { [f64(c.blend.src_rgb)] }
		gl_blend_dst_rgb { [f64(c.blend.dst_rgb)] }
		gl_blend_src_alpha { [f64(c.blend.src_alpha)] }
		gl_blend_dst_alpha { [f64(c.blend.dst_alpha)] }
		gl_blend_equation_rgb { [f64(c.blend.eq_rgb)] }
		gl_blend_equation_alpha { [f64(c.blend.eq_alpha)] }
		gl_color_writemask {
			[f64(1 - int(c.blend.masked[0])), f64(1 - int(c.blend.masked[1])),
				f64(1 - int(c.blend.masked[2])), f64(1 - int(c.blend.masked[3]))]
		}
		gl_depth_func_pname { [f64(c.depth.func)] }
		gl_depth_writemask { [f64(if c.depth.mask_off { 0 } else { 1 })] }
		gl_depth_clear_value { [f64(c.depth.clear_value)] }
		gl_depth_range_pname { [f64(c.depth.near), f64(c.depth.far)] }
		gl_cull_face_mode { [f64(c.depth.cull_mode)] }
		gl_front_face_pname { [f64(c.depth.front_face)] }
		gl_renderbuffer_binding { [f64(c.bound_renderbuffer)] }
		gl_current_program {
			[f64(c.current_program)]
		}
		gl_array_buffer_binding {
			[f64(c.bound_buffers[gl_array_buffer] or { 0 })]
		}
		gl_element_array_buffer_binding {
			[f64(c.bound_buffers[gl_element_array_buffer] or { 0 })]
		}
		gl_framebuffer_binding {
			[f64(c.bound_framebuffer)]
		}
		gl_texture_binding_2d {
			[f64(c.texture_units[c.active_unit])]
		}
		gl_active_texture {
			[f64(gl_texture0 + u32(c.active_unit))]
		}
		gl_max_texture_image_units, gl_max_combined_texture_image_units {
			[f64(max_texture_units)]
		}
		gl_max_vertex_texture_image_units {
			[f64(0)]
		}
		else {
			c.query_fixed_values(pname)
		}
	}
}

// get_integers answers glGetIntegerv. The color clear value converts as the
// GL spec specifies for floats read as integers.
pub fn (mut c Context) get_integers(pname u32) []int {
	values := c.query_values(pname) or {
		c.set_error(gl_invalid_enum)
		return []int{}
	}
	mut out := []int{cap: values.len}
	for v in values {
		if pname == gl_color_clear_value || pname == gl_blend_color_pname {
			out << int((f64(4294967295.0) * v - 1.0) / 2.0)
		} else {
			out << int(v)
		}
	}
	return out
}

pub fn (mut c Context) get_floats(pname u32) []f32 {
	values := c.query_values(pname) or {
		c.set_error(gl_invalid_enum)
		return []f32{}
	}
	mut out := []f32{cap: values.len}
	for v in values {
		out << f32(v)
	}
	return out
}

// get_string answers glGetString. The version is ES 2.0: ES 3.0 entry points
// are not implemented, so none is advertised. Only the extensions below are exposed.
pub fn (mut c Context) get_string(name u32) ?string {
	return match name {
		gl_vendor { 'Vox' }
		gl_renderer { 'Vox angle (' + c.display.backend.name() + ')' }
		gl_version { 'OpenGL ES 2.0 (Vox angle)' }
		gl_shading_language_version { 'OpenGL ES GLSL ES 1.00 (Vox angle)' }
		gl_extensions { supported_extensions.join(' ') }
		else {
			c.set_error(gl_invalid_enum)
			none
		}
	}
}

// shader_precision_format reports {range_min, range_max, precision}. All
// stages compute in IEEE float32 and 32-bit integers on Metal.
pub fn (mut c Context) shader_precision_format(stage u32, precision u32) []int {
	if stage != gl_vertex_shader && stage != gl_fragment_shader {
		c.set_error(gl_invalid_enum)
		return []int{}
	}
	return match precision {
		0x8DF0, 0x8DF1, 0x8DF2 { [127, 127, 23] } // LOW/MEDIUM/HIGH_FLOAT
		0x8DF3, 0x8DF4, 0x8DF5 { [31, 30, 0] } // LOW/MEDIUM/HIGH_INT
		else {
			c.set_error(gl_invalid_enum)
			[]int{}
		}
	}
}

// shader_source returns the source last given to glShaderSource.
pub fn (mut c Context) get_shader_source(name u32) string {
	if name !in c.shaders {
		c.set_error(gl_invalid_value)
		return ''
	}
	return c.shaders[name].source
}

// query_fixed_values answers the pnames whose values are constants of this
// implementation or plain stored state. Stencil values are the GL defaults
// because stencil state is validate-only (there is no stencil buffer).
fn (c &Context) query_fixed_values(pname u32) ?[]f64 {
	return match pname {
		0x0D05 { [f64(c.misc.pack_alignment)] }
		0x0CF5 { [f64(c.misc.unpack_alignment)] }
		0x0B21 { [f64(c.misc.line_width)] }
		0x8038 { [f64(c.misc.polygon_factor)] }
		0x2A00 { [f64(c.misc.polygon_units)] }
		0x80AA { [f64(c.misc.coverage_value)] }
		0x80AB { [f64(if c.misc.coverage_invert { 1 } else { 0 })] }
		0x8192 { [f64(c.misc.generate_hint)] } // GENERATE_MIPMAP_HINT
		0x0D50 { [f64(0)] } // SUBPIXEL_BITS
		0x0D52, 0x0D53, 0x0D54, 0x0D55 { [f64(8)] } // R, G, B, A bits
		0x0D56 { [f64(if c.framebuffer_has_depth() { 24 } else { 0 })] }
		0x0D57 { [f64(if c.framebuffer_has_stencil() { 8 } else { 0 })] } // STENCIL_BITS
		0x84E8, 0x851C { [f64(max_texture_dimension)] } // MAX_RENDERBUFFER_SIZE, MAX_CUBE_MAP_TEXTURE_SIZE
		0x846D, 0x846E { [f64(1), f64(1)] } // ALIASED_POINT_SIZE_RANGE, ALIASED_LINE_WIDTH_RANGE
		0x86A2 { [f64(0)] } // NUM_COMPRESSED_TEXTURE_FORMATS
		0x86A3 { []f64{} } // COMPRESSED_TEXTURE_FORMATS
		0x8CA7 { [f64(c.bound_renderbuffer)] }
		0x85B5 { [f64(c.bound_vao)] } // VERTEX_ARRAY_BINDING
		0x8B9A { [f64(0x1908)] } // IMPLEMENTATION_COLOR_READ_FORMAT
		0x8B9B { [f64(0x1401)] } // IMPLEMENTATION_COLOR_READ_TYPE
		0x0B92 { [f64(c.stencil.front.func)] }
		0x0B93 { [f64(i32(c.stencil.front.mask))] }
		0x0B97 { [f64(c.stencil.front.ref)] }
		0x0B98 { [f64(i32(c.stencil.front.write))] }
		0x0B94 { [f64(c.stencil.front.fail)] }
		0x0B95 { [f64(c.stencil.front.zfail)] }
		0x0B96 { [f64(c.stencil.front.zpass)] }
		0x8800 { [f64(c.stencil.back.func)] }
		0x8CA4 { [f64(i32(c.stencil.back.mask))] }
		0x8CA3 { [f64(c.stencil.back.ref)] }
		0x8CA5 { [f64(i32(c.stencil.back.write))] }
		0x8801 { [f64(c.stencil.back.fail)] }
		0x8802 { [f64(c.stencil.back.zfail)] }
		0x8803 { [f64(c.stencil.back.zpass)] }
		0x0B91 { [f64(c.misc.clear_stencil)] }
		else { none }
	}
}

// framebuffer_has_stencil reports whether the bound draw target has stencil.
fn (c &Context) framebuffer_has_stencil() bool {
	if c.bound_framebuffer == 0 {
		return true
	}
	fb := c.framebuffers[c.bound_framebuffer]
	return fb.stencil_rb != 0
}

// framebuffer_has_depth reports whether the bound draw target has depth.
fn (c &Context) framebuffer_has_depth() bool {
	if c.bound_framebuffer == 0 {
		return true
	}
	return c.framebuffers[c.bound_framebuffer].depth_rb != 0
}
