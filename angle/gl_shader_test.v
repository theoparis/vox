// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// These tests draw through the Metal device. They run only on macOS.

fn test_triangle_draws_with_uniforms_and_bottom_left_origin() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := link_program_for(mut c, tri_vs, solid_fs)
	c.use_program(prog)
	bind_positions(mut c, prog, 'a_pos', [f32(-1), -1, 1, -1, -1, 1])
	c.uniform_floats(c.uniform_location(prog, 'u_offset'), [f32(0), 0])
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [f32(0), 1, 0, 1])
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.draw_arrays(gl_triangles, 0, 3)
	assert c.get_error() == gl_no_error
	px := c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)
	// The triangle covers the GL bottom-left corner, which is row 0 in readback order.
	assert px[0..4] == [u8(0), 255, 0, 255]
	// The top-right corner lies outside the triangle and keeps the clear color.
	assert px[44..48] == [u8(0), 0, 0, 255]
}

fn test_uniform_offset_moves_the_triangle() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := link_program_for(mut c, tri_vs, solid_fs)
	c.use_program(prog)
	bind_positions(mut c, prog, 'a_pos', [f32(-1), -1, 1, -1, -1, 1])
	c.uniform_floats(c.uniform_location(prog, 'u_offset'), [f32(1), 0])
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [f32(1), 0, 0, 1])
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.draw_arrays(gl_triangles, 0, 3)
	assert c.get_error() == gl_no_error
	px := c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)
	// Shifted right by one unit, the bottom-left pixel leaves the triangle.
	assert px[0..4] == [u8(0), 0, 0, 255]
	// The bottom-right pixel is now inside.
	assert px[12..16] == [u8(255), 0, 0, 255]
}

fn test_varying_passes_a_uniform_color_to_the_fragment_stage() {
	$if !macos {
		return
	}
	vs_src := '
attribute vec2 a_pos;
uniform vec4 u_color;
varying vec4 v_color;
void main() {
	v_color = u_color;
	gl_Position = vec4(a_pos, 0.0, 1.0);
}
'
	fs_src := '
precision mediump float;
varying vec4 v_color;
void main() {
	gl_FragColor = vec4(v_color.rgb, 1.0) * v_color.a;
}
'
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := link_program_for(mut c, vs_src, fs_src)
	c.use_program(prog)
	// A full-screen triangle covers every pixel.
	bind_positions(mut c, prog, 'a_pos', [f32(-1), -1, 3, -1, -1, 3])
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [f32(0), 0, 1, 1])
	c.draw_arrays(gl_triangles, 0, 3)
	assert c.get_error() == gl_no_error
	px := c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)
	assert px[0..4] == [u8(0), 0, 255, 255]
	assert px[44..48] == [u8(0), 0, 255, 255]
}

fn test_matrix_uniform_translates_the_geometry() {
	$if !macos {
		return
	}
	vs_src := '
attribute vec2 a_pos;
uniform mat4 u_model;
void main() {
	gl_Position = u_model * vec4(a_pos, 0.0, 1.0);
}
'
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := link_program_for(mut c, vs_src, solid_fs)
	c.use_program(prog)
	bind_positions(mut c, prog, 'a_pos', [f32(-1), -1, 1, -1, -1, 1])
	// Column-major translation by +1 along x.
	model := [f32(1), 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1]
	c.uniform_matrix(c.uniform_location(prog, 'u_model'), false, model)
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [f32(0), 0, 1, 1])
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.draw_arrays(gl_triangles, 0, 3)
	assert c.get_error() == gl_no_error
	px := c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)
	assert px[0..4] == [u8(0), 0, 0, 255]
	assert px[12..16] == [u8(0), 0, 255, 255]
}

fn test_disabled_attributes_read_a_constant_and_short_buffers_fail() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := link_program_for(mut c, tri_vs, solid_fs)
	c.use_program(prog)
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [f32(1), 1, 1, 1])
	// A disabled array reads the generic attribute (0, 0, 0, 1): a degenerate draw, not an error.
	c.draw_arrays(gl_triangles, 0, 3)
	assert c.get_error() == gl_no_error

	bind_positions(mut c, prog, 'a_pos', [f32(-1), -1, 1, -1])
	c.draw_arrays(gl_triangles, 0, 3)
	assert c.get_error() == gl_invalid_operation
	c.draw_arrays(gl_triangles, 0, 2)
	assert c.get_error() == gl_no_error
}

fn test_draw_rejects_unsupported_modes_and_bad_counts() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := link_program_for(mut c, tri_vs, solid_fs)
	c.use_program(prog)
	bind_positions(mut c, prog, 'a_pos', [f32(-1), -1, 1, -1, -1, 1])
	c.draw_arrays(gl_triangle_fan, 0, 3)
	assert c.get_error() == gl_invalid_operation
	c.draw_arrays(0x1234, 0, 3)
	assert c.get_error() == gl_invalid_enum
	c.draw_arrays(gl_triangles, 0, -1)
	assert c.get_error() == gl_invalid_value
}

fn test_linking_failure_reports_a_log_and_blocks_use() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	vs := c.create_shader(gl_vertex_shader)
	c.shader_source(vs, 'attribute vec2 a; varying vec2 v; void main() { v = a; gl_Position = vec4(a, 0.0, 1.0); }')
	assert c.compile_shader(vs)
	fs := c.create_shader(gl_fragment_shader)
	c.shader_source(fs, 'varying vec2 w; void main() { gl_FragColor = vec4(w, 0.0, 1.0); }')
	assert c.compile_shader(fs)
	prog := c.create_program()
	c.attach_shader(prog, vs)
	c.attach_shader(prog, fs)
	assert !c.link_program(prog)
	assert c.program_log(prog).contains('not declared in the vertex shader')
	c.use_program(prog)
	assert c.get_error() == gl_invalid_operation
}

fn test_compile_failure_reports_the_line() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	fs := c.create_shader(gl_fragment_shader)
	c.shader_source(fs, 'void main() {\n\tgl_FragColor = vec4(missing);\n}\n')
	assert !c.compile_shader(fs)
	assert c.shader_log(fs).contains('line 2')
}
