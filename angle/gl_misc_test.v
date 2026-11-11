// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Tests for the GLES 2 state setters, introspection, constant attributes,
// polygon offset and copy-to-texture. Draws run on the Metal device (macOS only).

const attr_vs = '
attribute vec2 a_pos;
attribute vec4 a_color;
uniform float u_z;
varying vec4 v_color;
void main() {
	v_color = a_color;
	gl_Position = vec4(a_pos, u_z, 1.0);
}
'

const attr_fs = '
precision mediump float;
varying vec4 v_color;
void main() {
	gl_FragColor = v_color;
}
'

const smp_vs = '
attribute vec2 a_pos;
varying vec2 v_uv;
void main() {
	v_uv = a_pos;
	gl_Position = vec4(a_pos, 0.0, 1.0);
}
'

const smp_fs = '
precision mediump float;
uniform sampler2D u_tex;
varying vec2 v_uv;
void main() {
	gl_FragColor = texture2D(u_tex, v_uv);
}
'

const quad_verts = [f32(-1), -1, 1, -1, -1, 1, 1, 1]

fn px0(mut c Context) []u8 {
	return c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)[0..4]
}

fn attr_program(mut c Context) u32 {
	prog := link_program_for(mut c, attr_vs, attr_fs)
	bind_positions(mut c, prog, 'a_pos', quad_verts)
	c.use_program(prog)
	c.uniform_floats(c.uniform_location(prog, 'u_z'), [f32(0)])
	return prog
}

fn test_constant_attributes_feed_disabled_arrays() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := attr_program(mut c)
	color := c.attrib_location(prog, 'a_color')
	assert color >= 0 && !c.attribs[color].enabled
	c.set_clear_color(0, 0, 1, 1)
	c.clear(gl_color_buffer_bit)
	// Unset: the default is (0, 0, 0, 1).
	c.draw_arrays(gl_triangle_strip, 0, 4)
	assert c.get_error() == gl_no_error
	assert px0(mut c) == [u8(0), 0, 0, 255]
	c.vertex_attrib_const(color, 1, 0, 0, 1)
	c.draw_arrays(gl_triangle_strip, 0, 4)
	assert px0(mut c) == [u8(255), 0, 0, 255]
	// Later changes take effect, and the pipeline cache keeps both layouts.
	c.vertex_attrib_const(color, 0, 1, 0, 1)
	c.draw_arrays(gl_triangle_strip, 0, 4)
	assert px0(mut c) == [u8(0), 255, 0, 255]
	assert c.vertex_attrib_param(color, gl_current_vertex_attrib) or { []f64{} } == [f64(0), 1, 0, 1]
	c.vertex_attrib_const(99, 0, 0, 0, 0)
	assert c.get_error() == gl_invalid_value
}

fn test_bind_attrib_location_applies_at_link() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	vs := c.create_shader(gl_vertex_shader)
	c.shader_source(vs, attr_vs)
	assert c.compile_shader(vs)
	fs := c.create_shader(gl_fragment_shader)
	c.shader_source(fs, attr_fs)
	assert c.compile_shader(fs)
	prog := c.create_program()
	c.attach_shader(prog, vs)
	c.attach_shader(prog, fs)
	c.bind_attrib_location(prog, 7, 'a_color')
	c.bind_attrib_location(prog, 3, 'a_pos')
	c.bind_attrib_location(prog, 99, 'a_pos')
	assert c.get_error() == gl_invalid_value
	c.bind_attrib_location(prog, 1, 'gl_Foo')
	assert c.get_error() == gl_invalid_operation
	c.bind_attrib_location(9999, 1, 'a_pos')
	assert c.get_error() == gl_invalid_value
	assert c.link_program(prog), c.program_log(prog)
	assert c.attrib_location(prog, 'a_color') == 7
	assert c.attrib_location(prog, 'a_pos') == 3
	// Two active attributes on one slot fail the link.
	c.bind_attrib_location(prog, 3, 'a_color')
	assert !c.link_program(prog)
	assert c.program_log(prog).contains('bound to location 3')
	// A binding for an inactive name is ignored, and unbound attributes fill free slots.
	c.bind_attrib_location(prog, 7, 'a_color')
	c.bind_attrib_location(prog, 0, 'a_missing')
	c.bind_attrib_location(prog, 0, 'a_pos')
	assert c.link_program(prog)
	assert c.attrib_location(prog, 'a_pos') == 0
	assert c.attrib_location(prog, 'a_color') == 7
	assert c.get_error() == gl_no_error
}

fn test_active_attribs_uniforms_and_parameters() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := attr_program(mut c)
	assert c.program_param(prog, gl_link_status_pname) or { -1 } == 1
	assert c.program_param(prog, gl_attached_shaders) or { -1 } == 2
	assert c.program_param(prog, gl_active_attributes) or { -1 } == 2
	assert c.program_param(prog, gl_active_uniforms) or { -1 } == 1
	assert c.program_param(prog, gl_active_attribute_max_length) or { -1 } == 8 // "a_color" + NUL
	assert c.program_param(prog, gl_active_uniform_max_length) or { -1 } == 4 // "u_z" + NUL
	assert c.program_param(prog, gl_validate_status) or { -1 } == 0
	c.validate_program(prog)
	assert c.program_param(prog, gl_validate_status) or { -1 } == 1
	c.program_param(prog, 0x1234) or {
		assert c.get_error() == gl_invalid_enum
		c.program_param(4242, gl_link_status_pname) or {
			assert c.get_error() == gl_invalid_value
			a0 := c.active_attrib(prog, 0) or { panic('missing attribute') }
			a1 := c.active_attrib(prog, 1) or { panic('missing attribute') }
			assert a0.name + a1.name in ['a_posa_color', 'a_colora_pos']
			assert a0.typ == 0x8B50 || a0.typ == 0x8B52
			u := c.active_uniform(prog, 0) or { panic('missing uniform') }
			assert u.name == 'u_z' && u.typ == 0x1406 && u.size == 1
			c.active_uniform(prog, 5) or {
				assert c.get_error() == gl_invalid_value
				return
			}
			assert false
			return
		}
		assert false
		return
	}
	assert false
}

fn test_uniform_roundtrip_and_shader_parameters() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := link_program_for(mut c, smp_vs, smp_fs)
	c.use_program(prog)
	tex_loc := c.uniform_location(prog, 'u_tex')
	c.uniform_ints(tex_loc, [3])
	assert c.get_uniform(prog, tex_loc) or { []f64{} } == [f64(3)]
	assert c.active_uniform(prog, tex_loc) or { ActiveInfo{} }.typ == 0x8B5E
	prog2 := link_program_for(mut c, tri_vs, solid_fs)
	c.use_program(prog2)
	loc := c.uniform_location(prog2, 'u_offset')
	c.uniform_floats(loc, [f32(0.25), -2])
	assert c.get_uniform(prog2, loc) or { []f64{} } == [f64(0.25), -2]
	// Matrices and vec3 come back unpadded.
	m := link_program_for(mut c, 'attribute vec2 p; uniform mat3 m; uniform vec3 v; void main() { gl_Position = vec4(m * v, 1.0) + vec4(p, 0.0, 0.0); }',
		solid_fs)
	c.use_program(m)
	c.uniform_matrix(c.uniform_location(m, 'm'), false, [f32(1), 2, 3, 4, 5, 6, 7, 8, 9])
	c.uniform_floats(c.uniform_location(m, 'v'), [f32(1), 2, 3])
	assert c.get_uniform(m, c.uniform_location(m, 'm')) or { []f64{} } == [f64(1), 2, 3, 4, 5, 6, 7, 8, 9]
	assert c.get_uniform(m, c.uniform_location(m, 'v')) or { []f64{} } == [f64(1), 2, 3]
	// Wrong-sized setters are INVALID_OPERATION, as GL specifies.
	c.uniform_floats(c.uniform_location(m, 'v'), [f32(1), 2])
	assert c.get_error() == gl_invalid_operation
	c.uniform_ints(tex_loc, [1, 2])
	assert c.get_error() == gl_invalid_operation
	c.get_uniform(m, 77) or {
		assert c.get_error() == gl_invalid_operation
		// Shader parameters.
		sh := c.create_shader(gl_fragment_shader)
		c.shader_source(sh, 'abc')
		assert c.shader_param(sh, gl_shader_source_length) or { -1 } == 4
		assert c.shader_param(sh, gl_shader_type_pname) or { -1 } == f64(gl_fragment_shader)
		assert c.shader_param(sh, gl_compile_status_pname) or { -1 } == 0
		c.shader_param(sh, 0x1234) or {
			assert c.get_error() == gl_invalid_enum
			return
		}
		assert false
		return
	}
	assert false
}

fn test_state_setters_validate_and_store() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	c.hint(gl_generate_mipmap_hint, gl_nicest)
	assert c.get_error() == gl_no_error
	c.hint(0x1234, gl_nicest)
	assert c.get_error() == gl_invalid_enum
	c.hint(gl_generate_mipmap_hint, 0x1234)
	assert c.get_error() == gl_invalid_enum
	c.line_width(0)
	assert c.get_error() == gl_invalid_value
	c.line_width(2)
	assert c.get_error() == gl_no_error
	c.pixel_store(gl_unpack_alignment, 1)
	c.pixel_store(gl_pack_alignment, 8)
	assert c.get_error() == gl_no_error
	c.pixel_store(gl_unpack_alignment, 3)
	assert c.get_error() == gl_invalid_value
	c.pixel_store(0x9240, 1) // UNPACK_FLIP_Y_WEBGL belongs to the WebGL layer
	assert c.get_error() == gl_invalid_enum
	c.sample_coverage(3, true)
	assert c.misc.coverage_value == 1
	// Dither is on by default; the others are off. All are tracked, none renders.
	assert c.is_enabled(gl_dither) && !c.is_enabled(gl_stencil_test_cap)
	c.disable(gl_dither)
	c.enable(gl_stencil_test_cap)
	c.enable(gl_sample_coverage_cap)
	c.enable(gl_polygon_offset_fill)
	assert !c.is_enabled(gl_dither) && c.is_enabled(gl_stencil_test_cap)
	assert c.is_enabled(gl_sample_coverage_cap) && c.is_enabled(gl_polygon_offset_fill)
	// Stencil state validates its enums.
	c.stencil_func(gl_always, 0, 0xff)
	c.stencil_func_separate(gl_front, gl_less, 1, 0xff)
	c.stencil_op(gl_keep, gl_incr_wrap, gl_invert)
	c.stencil_mask(0)
	c.stencil_mask_separate(gl_back, 0xff)
	c.clear_stencil(3)
	assert c.get_error() == gl_no_error
	c.stencil_func(0x1234, 0, 0xff)
	assert c.get_error() == gl_invalid_enum
	c.stencil_op(gl_keep, 0x1234, gl_keep)
	assert c.get_error() == gl_invalid_enum
	c.stencil_mask_separate(gl_cw, 0)
	assert c.get_error() == gl_invalid_enum
	// Draw and read buffer selectors accept only the one color buffer.
	c.draw_buffers([gl_back])
	c.read_buffer(gl_back)
	assert c.get_error() == gl_no_error
	c.draw_buffers([gl_back, gl_back])
	assert c.get_error() == gl_invalid_value
	c.draw_buffers([gl_color_attachment0])
	assert c.get_error() == gl_invalid_operation
	c.read_buffer(gl_color_attachment0)
	assert c.get_error() == gl_invalid_operation
}

fn test_polygon_offset_breaks_depth_ties() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := attr_program(mut c)
	color := c.attrib_location(prog, 'a_color')
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit | gl_depth_buffer_bit)
	c.enable(gl_depth_test)
	c.vertex_attrib_const(color, 1, 0, 0, 1)
	c.draw_arrays(gl_triangle_strip, 0, 4)
	// Same depth: LESS rejects the second quad.
	c.vertex_attrib_const(color, 0, 1, 0, 1)
	c.draw_arrays(gl_triangle_strip, 0, 4)
	assert px0(mut c) == [u8(255), 0, 0, 255]
	// A negative offset moves it nearer, so it passes.
	c.enable(gl_polygon_offset_fill)
	c.polygon_offset(0, -100)
	c.draw_arrays(gl_triangle_strip, 0, 4)
	assert c.get_error() == gl_no_error
	assert px0(mut c) == [u8(0), 255, 0, 255]
}

fn test_copy_tex_image_reads_the_framebuffer() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := attr_program(mut c)
	color := c.attrib_location(prog, 'a_color')
	c.set_clear_color(0, 0, 0, 0)
	c.clear(gl_color_buffer_bit)
	c.vertex_attrib_const(color, 1, 0, 0, 1)
	c.draw_arrays(gl_triangle_strip, 0, 4)
	tex := c.gen_texture()
	c.bind_texture(gl_texture_2d, tex)
	// Copy a 6x3 window that starts one pixel left of the surface: the pixels
	// outside it are transparent black.
	c.copy_tex_image_2d(gl_texture_2d, 0, gl_rgba, -1, 0, 6, 3, 0)
	assert c.get_error() == gl_no_error
	fb := c.gen_framebuffer()
	c.bind_framebuffer(gl_framebuffer, fb)
	c.framebuffer_texture_2d(gl_framebuffer, gl_color_attachment0, gl_texture_2d, tex, 0)
	got := c.read_pixels(0, 0, 6, 3, gl_rgba, gl_unsigned_byte)
	assert got[0..4] == [u8(0), 0, 0, 0]
	assert got[4..8] == [u8(255), 0, 0, 255]
	assert got[20..24] == [u8(0), 0, 0, 0]
	// CopyTexSubImage2D patches a rectangle of the existing texture.
	c.bind_framebuffer(gl_framebuffer, 0)
	c.copy_tex_sub_image_2d(gl_texture_2d, 0, 4, 2, 0, 0, 2, 1)
	assert c.get_error() == gl_no_error
	c.bind_framebuffer(gl_framebuffer, fb)
	after := c.read_pixels(0, 0, 6, 3, gl_rgba, gl_unsigned_byte)
	assert after[(2 * 6 + 4) * 4..(2 * 6 + 4) * 4 + 4] == [u8(255), 0, 0, 255]
	// Errors.
	c.bind_framebuffer(gl_framebuffer, 0)
	c.copy_tex_image_2d(gl_texture_2d, 0, gl_rgba, 0, 0, 2, 2, 1)
	assert c.get_error() == gl_invalid_value
	c.copy_tex_image_2d(gl_texture_2d, 0, 0x1907, 0, 0, 2, 2, 0)
	assert c.get_error() == gl_invalid_operation
	c.copy_tex_image_2d(0x1234, 0, gl_rgba, 0, 0, 2, 2, 0)
	assert c.get_error() == gl_invalid_enum
	c.compressed_tex_image_2d(gl_texture_2d, 0, 0x83F0)
	assert c.get_error() == gl_invalid_enum
}

fn test_parameter_getters() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	tex := c.gen_texture()
	c.bind_texture(gl_texture_2d, tex)
	assert c.tex_parameter_value(gl_texture_2d, gl_texture_min_filter) or { -1 } == f64(gl_nearest_mipmap_linear)
	assert c.tex_parameter_value(gl_texture_2d, gl_texture_wrap_s) or { -1 } == f64(gl_repeat)
	c.tex_parameteri(gl_texture_2d, gl_texture_wrap_t, int(gl_mirrored_repeat))
	assert c.tex_parameter_value(gl_texture_2d, gl_texture_wrap_t) or { -1 } == f64(gl_mirrored_repeat)
	buf := c.gen_buffer()
	c.bind_buffer(gl_array_buffer, buf)
	c.buffer_data(gl_array_buffer, 64, []u8{}, gl_dynamic_draw)
	assert c.buffer_parameter(gl_array_buffer, gl_buffer_size) or { -1 } == 64
	assert c.buffer_parameter(gl_array_buffer, gl_buffer_usage) or { -1 } == f64(gl_dynamic_draw)
	rb := c.gen_renderbuffer()
	c.bind_renderbuffer(gl_renderbuffer, rb)
	c.renderbuffer_storage(gl_renderbuffer, gl_depth_component16, 8, 4)
	assert c.renderbuffer_parameter(gl_renderbuffer, gl_renderbuffer_width) or { -1 } == 8
	assert c.renderbuffer_parameter(gl_renderbuffer, gl_renderbuffer_height) or { -1 } == 4
	assert c.renderbuffer_parameter(gl_renderbuffer, gl_renderbuffer_depth_size) or { -1 } == 16
	assert c.renderbuffer_parameter(gl_renderbuffer, gl_renderbuffer_stencil_size) or { -1 } == 0
	c.vertex_attrib_pointer(2, 3, gl_float, 24, 8)
	c.enable_vertex_attrib(2, true)
	assert c.vertex_attrib_param(2, gl_vertex_attrib_array_size) or { []f64{} } == [f64(3)]
	assert c.vertex_attrib_param(2, gl_vertex_attrib_array_stride) or { []f64{} } == [f64(24)]
	assert c.vertex_attrib_param(2, gl_vertex_attrib_array_pointer) or { []f64{} } == [f64(8)]
	assert c.vertex_attrib_param(2, gl_vertex_attrib_array_enabled) or { []f64{} } == [f64(1)]
	assert c.vertex_attrib_param(2, gl_vertex_attrib_array_buffer_binding) or { []f64{} } == [f64(buf)]
	assert c.get_error() == gl_no_error
	c.vertex_attrib_param(2, 0x1234) or {
		assert c.get_error() == gl_invalid_enum
		return
	}
	assert false
}
