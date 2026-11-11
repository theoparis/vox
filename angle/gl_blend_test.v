// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Blend and index-draw tests. The draws run through the Metal device, so they
// run only on macOS; the 4x3 default surface comes from gl_fixture.

const quad_vs = '
attribute vec2 a_pos;
uniform vec2 u_offset;
void main() {
	gl_Position = vec4(a_pos + u_offset, 0.0, 1.0);
}
'

// fill_quad draws one full-surface quad of a color through the current state.
fn fill_quad(mut c Context, prog u32, r f32, g f32, b f32, a f32) {
	c.use_program(prog)
	c.uniform_floats(c.uniform_location(prog, 'u_offset'), [f32(0), 0])
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [r, g, b, a])
	c.draw_arrays(gl_triangle_strip, 0, 4)
}

fn quad_program(mut c Context) u32 {
	prog := link_program_for(mut c, quad_vs, solid_fs)
	bind_positions(mut c, prog, 'a_pos', [f32(-1), -1, 1, -1, -1, 1, 1, 1])
	return prog
}

// first_pixel reads texel 0 of the 4x3 surface.
fn first_pixel(mut c Context) []u8 {
	return c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)[0..4]
}

fn test_blend_state_validation_and_queries() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	assert !c.is_enabled(gl_blend)
	c.enable(gl_blend)
	assert c.is_enabled(gl_blend)
	assert c.get_integers(gl_blend_src_rgb) == [int(gl_one)]
	assert c.get_integers(gl_blend_dst_alpha) == [int(gl_zero)]
	c.blend_func(gl_src_alpha, gl_one_minus_src_alpha)
	assert c.get_integers(gl_blend_src_alpha) == [int(gl_src_alpha)]
	assert c.get_integers(gl_blend_dst_rgb) == [int(gl_one_minus_src_alpha)]
	// SRC_ALPHA_SATURATE is a source factor only.
	c.blend_func(gl_one, gl_src_alpha_saturate)
	assert c.get_error() == gl_invalid_enum
	c.blend_func(gl_src_alpha_saturate, gl_one)
	assert c.get_error() == gl_no_error
	c.blend_func(0x1234, gl_one)
	assert c.get_error() == gl_invalid_enum
	// A rejected call leaves the state untouched.
	assert c.get_integers(gl_blend_src_rgb) == [int(gl_src_alpha_saturate)]
	c.blend_equation(gl_func_reverse_subtract)
	assert c.get_integers(gl_blend_equation_alpha) == [int(gl_func_reverse_subtract)]
	c.blend_equation(0x8007) // GL_MIN is ES 3
	assert c.get_error() == gl_invalid_enum
	c.blend_color(2, -1, 0.5, 0.25)
	assert c.get_floats(gl_blend_color_pname) == [f32(1), 0, 0.5, 0.25]
	c.color_mask(true, false, true, false)
	assert c.get_integers(gl_color_writemask) == [1, 0, 1, 0]
	c.disable(gl_blend)
	assert !c.is_enabled(gl_blend)
	assert c.get_error() == gl_no_error
}

fn test_source_over_blending() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := quad_program(mut c)
	c.set_clear_color(0, 0, 1, 1)
	c.clear(gl_color_buffer_bit)
	c.enable(gl_blend)
	c.blend_func(gl_src_alpha, gl_one_minus_src_alpha)
	fill_quad(mut c, prog, 1, 0, 0, 1)
	assert c.get_error() == gl_no_error
	// Opaque source replaces the destination.
	assert first_pixel(mut c) == [u8(255), 0, 0, 255]
	c.set_clear_color(0, 0, 1, 1)
	c.clear(gl_color_buffer_bit)
	fill_quad(mut c, prog, 1, 0, 0, 0.5)
	px := first_pixel(mut c)
	// 0.5 * red + 0.5 * blue, within one step of unorm rounding.
	assert px[0] >= 127 && px[0] <= 128
	assert px[1] == 0
	assert px[2] >= 127 && px[2] <= 128
	// Without BLEND the source overwrites.
	c.disable(gl_blend)
	fill_quad(mut c, prog, 1, 0, 0, 0.5)
	assert first_pixel(mut c) == [u8(255), 0, 0, 128]
}

fn test_additive_and_constant_color_blending() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := quad_program(mut c)
	c.set_clear_color(0.2, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.enable(gl_blend)
	c.blend_func(gl_one, gl_one)
	fill_quad(mut c, prog, 0, 0.4, 0, 0)
	px := first_pixel(mut c)
	assert px[0] >= 50 && px[0] <= 52
	assert px[1] >= 101 && px[1] <= 103
	assert px[3] == 255
	// Subtraction: dst - src.
	c.set_clear_color(1, 1, 1, 1)
	c.clear(gl_color_buffer_bit)
	c.blend_equation(gl_func_reverse_subtract)
	c.blend_func(gl_one, gl_one)
	fill_quad(mut c, prog, 1, 0, 0, 0)
	assert first_pixel(mut c) == [u8(0), 255, 255, 255]
	// Constant blend color scales the source.
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.blend_equation(gl_func_add)
	c.blend_func(gl_constant_color, gl_zero)
	c.blend_color(0.5, 1, 0, 1)
	fill_quad(mut c, prog, 1, 1, 1, 1)
	px2 := first_pixel(mut c)
	assert px2[0] >= 127 && px2[0] <= 128
	assert px2[1] == 255
	assert px2[2] == 0
}

fn test_color_mask_limits_writes_and_blocks_clear() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := quad_program(mut c)
	c.set_clear_color(0, 0, 0, 0)
	c.clear(gl_color_buffer_bit)
	c.color_mask(true, false, true, true)
	fill_quad(mut c, prog, 1, 1, 1, 1)
	assert first_pixel(mut c) == [u8(255), 0, 255, 255]
	// A load-action clear cannot honor a partial mask, so it is refused.
	c.clear(gl_color_buffer_bit)
	assert c.get_error() == gl_invalid_operation
	c.color_mask(true, true, true, true)
	c.clear(gl_color_buffer_bit)
	assert c.get_error() == gl_no_error
}

// index_fixture binds a program and a position buffer of four corners that
// are only addressable through indices.
fn index_fixture(mut c Context) u32 {
	return quad_program(mut c)
}

fn bind_indices(mut c Context, data []u8) {
	ebo := c.gen_buffer()
	c.bind_buffer(gl_element_array_buffer, ebo)
	c.buffer_data(gl_element_array_buffer, data.len, data, gl_static_draw)
}

fn test_draw_elements_with_each_index_type() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := index_fixture(mut c)
	c.use_program(prog)
	c.uniform_floats(c.uniform_location(prog, 'u_offset'), [f32(0), 0])
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [f32(0), 1, 0, 1])
	// Two triangles covering the surface, listed out of vertex order.
	// Bytes.
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	bind_indices(mut c, [u8(0), 1, 2, 2, 1, 3])
	c.draw_elements(gl_triangles, 6, gl_unsigned_byte, 0)
	assert c.get_error() == gl_no_error
	assert c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte) == []u8{len: 48, init: [u8(0), 255, 0, 255][index % 4]}
	// Unsigned short with a byte offset skipping the first index pair.
	c.clear(gl_color_buffer_bit)
	bind_indices(mut c, [u8(9), 0, 9, 0, 0, 0, 1, 0, 2, 0, 2, 0, 1, 0, 3, 0])
	c.draw_elements(gl_triangles, 6, gl_unsigned_short, 4)
	assert c.get_error() == gl_no_error
	assert first_pixel(mut c) == [u8(0), 255, 0, 255]
	// Unsigned int.
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	mut wide := []u8{}
	for v in [0, 1, 2, 2, 1, 3] {
		wide << [u8(v), 0, 0, 0]
	}
	bind_indices(mut c, wide)
	c.draw_elements(gl_triangle_strip, 5, gl_unsigned_int, 8)
	assert c.get_error() == gl_invalid_operation // 20 bytes at offset 8 run past the 24-byte buffer
	c.draw_elements(gl_triangle_strip, 4, gl_unsigned_int, 0)
	assert c.get_error() == gl_no_error
	assert first_pixel(mut c)[1] == 255
}

fn test_draw_elements_validation() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := index_fixture(mut c)
	c.use_program(prog)
	c.draw_elements(gl_triangles, 3, gl_unsigned_byte, 0)
	assert c.get_error() == gl_invalid_operation // no element buffer
	bind_indices(mut c, [u8(0), 1, 2, 3, 4, 5])
	c.draw_elements(gl_triangles, 3, 0x1406, 0)
	assert c.get_error() == gl_invalid_enum
	c.draw_elements(gl_triangles, -1, gl_unsigned_byte, 0)
	assert c.get_error() == gl_invalid_value
	c.draw_elements(0x9999, 3, gl_unsigned_byte, 0)
	assert c.get_error() == gl_invalid_enum
	c.draw_elements(gl_triangles, 3, gl_unsigned_short, 1)
	assert c.get_error() == gl_invalid_operation // misaligned offset
	c.draw_elements(gl_triangles, 6, gl_unsigned_short, 0)
	assert c.get_error() == gl_invalid_operation // 12 bytes in a 6 byte buffer
	// Index 5 needs six vertices but the position buffer holds four.
	c.draw_elements(gl_triangles, 6, gl_unsigned_byte, 0)
	assert c.get_error() == gl_invalid_operation
	c.draw_elements(gl_triangles, 0, gl_unsigned_byte, 0)
	assert c.get_error() == gl_no_error
}
