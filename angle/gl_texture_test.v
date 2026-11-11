// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Texture state tests run everywhere; the sampling tests draw through the
// Metal device and run only on macOS.

const tex_vs = '
attribute vec2 a_pos;
varying vec2 v_uv;
void main() {
	v_uv = a_pos * 0.5 + vec2(0.5);
	gl_Position = vec4(a_pos, 0.0, 1.0);
}
'

const tex_fs = '
precision mediump float;
uniform sampler2D u_tex;
varying vec2 v_uv;
void main() {
	gl_FragColor = texture2D(u_tex, v_uv);
}
'

// texels returns a w x h RGBA image whose pixel i is distinct.
fn texels(w int, h int) []u8 {
	mut out := []u8{}
	for i in 0 .. w * h {
		out << u8(i * 20)
		out << u8(255 - i)
		out << u8(7)
		out << u8(255)
	}
	return out
}

// nearest_clamp gives the bound texture the parameters a 4x3 (non power of
// two) texture needs to be complete.
fn nearest_clamp(mut c Context) {
	c.tex_parameteri(gl_texture_2d, gl_texture_min_filter, int(gl_nearest))
	c.tex_parameteri(gl_texture_2d, gl_texture_mag_filter, int(gl_nearest))
	c.tex_parameteri(gl_texture_2d, gl_texture_wrap_s, int(gl_clamp_to_edge))
	c.tex_parameteri(gl_texture_2d, gl_texture_wrap_t, int(gl_clamp_to_edge))
}

fn draw_quad(mut c Context, prog u32) {
	c.use_program(prog)
	bind_positions(mut c, prog, 'a_pos', [f32(-1), -1, 1, -1, -1, 1, 1, 1])
	c.set_clear_color(0, 0, 0, 0)
	c.clear(gl_color_buffer_bit)
	c.draw_arrays(gl_triangle_strip, 0, 4)
}

fn test_texture_unit_and_parameter_errors() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	c.active_texture(gl_texture0 + 8)
	assert c.get_error() == gl_invalid_enum
	c.active_texture(gl_texture0 - 1)
	assert c.get_error() == gl_invalid_enum
	c.tex_parameteri(gl_texture_2d, gl_texture_min_filter, int(gl_nearest))
	assert c.get_error() == gl_invalid_operation // nothing bound
	tex := c.gen_texture()
	c.bind_texture(gl_texture_2d, tex)
	c.tex_parameteri(0x8513, gl_texture_min_filter, int(gl_nearest))
	assert c.get_error() == gl_invalid_enum
	c.tex_parameteri(gl_texture_2d, 0x1234, 1)
	assert c.get_error() == gl_invalid_enum
	c.tex_parameteri(gl_texture_2d, gl_texture_mag_filter, int(gl_nearest_mipmap_linear))
	assert c.get_error() == gl_invalid_enum // mag filter has no mipmaps
	c.tex_parameteri(gl_texture_2d, gl_texture_wrap_s, int(gl_linear))
	assert c.get_error() == gl_invalid_enum
	c.tex_parameteri(gl_texture_2d, gl_texture_min_filter, int(gl_linear_mipmap_linear))
	assert c.get_error() == gl_no_error
	// Bindings are per unit.
	c.active_texture(gl_texture0 + 1)
	other := c.gen_texture()
	c.bind_texture(gl_texture_2d, other)
	assert c.get_integers(gl_texture_binding_2d) == [int(other)]
	assert c.get_integers(gl_active_texture) == [int(gl_texture0 + 1)]
	c.active_texture(gl_texture0)
	assert c.get_integers(gl_texture_binding_2d) == [int(tex)]
	assert c.get_integers(gl_max_texture_image_units) == [max_texture_units]
	assert c.get_integers(gl_max_vertex_texture_image_units) == [0]
	// Deleting a texture unbinds it from every unit.
	c.delete_texture(other)
	c.active_texture(gl_texture0 + 1)
	assert c.get_integers(gl_texture_binding_2d) == [0]
	assert c.get_error() == gl_no_error
}

fn test_tex_sub_image_validates_and_updates() {
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
	// Level 0 is undefined, so no rectangle fits.
	c.tex_sub_image_2d(gl_texture_2d, 0, 0, 0, 1, 1, gl_rgba, gl_unsigned_byte, [u8(1), 2, 3, 4])
	assert c.get_error() == gl_invalid_value
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 4, 3, gl_rgba, gl_unsigned_byte, texels(4, 3))
	c.tex_sub_image_2d(gl_texture_2d, 0, 3, 0, 2, 1, gl_rgba, gl_unsigned_byte, []u8{len: 8})
	assert c.get_error() == gl_invalid_value // x + width > 4
	c.tex_sub_image_2d(gl_texture_2d, 0, 0, 0, 1, 1, gl_rgba, gl_unsigned_byte, []u8{len: 3})
	assert c.get_error() == gl_invalid_value // wrong byte count
	c.tex_sub_image_2d(gl_texture_2d, 1, 0, 0, 1, 1, gl_rgba, gl_unsigned_byte, []u8{len: 4})
	assert c.get_error() == gl_invalid_value // no level 1
	c.tex_sub_image_2d(gl_texture_2d, 0, 0, 0, 1, 1, 0x1907, gl_unsigned_byte, []u8{len: 4})
	assert c.get_error() == gl_invalid_operation
	c.tex_sub_image_2d(gl_texture_2d, 0, 1, 1, 2, 1, gl_rgba, gl_unsigned_byte, [u8(9), 9, 9, 9, 8, 8,
		8, 8])
	assert c.get_error() == gl_no_error
	fb := c.gen_framebuffer()
	c.bind_framebuffer(gl_framebuffer, fb)
	c.framebuffer_texture_2d(gl_framebuffer, gl_color_attachment0, gl_texture_2d, tex, 0)
	px := c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)
	mut want := texels(4, 3)
	for i in 0 .. 4 {
		want[(1 * 4 + 1) * 4 + i] = 9
		want[(1 * 4 + 2) * 4 + i] = 8
	}
	assert px == want
}

fn test_sampler_reads_the_bound_texture_one_to_one() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := link_program_for(mut c, tex_vs, tex_fs)
	tex := c.gen_texture()
	c.bind_texture(gl_texture_2d, tex)
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 4, 3, gl_rgba, gl_unsigned_byte, texels(4, 3))
	nearest_clamp(mut c)
	c.use_program(prog)
	c.uniform_ints(c.uniform_location(prog, 'u_tex'), [0])
	draw_quad(mut c, prog)
	assert c.get_error() == gl_no_error
	// GL texel row 0 lands on GL window row 0, which is readback row 0.
	assert c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte) == texels(4, 3)
}

fn test_sampler_uses_the_unit_its_uniform_names() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := link_program_for(mut c, tex_vs, tex_fs)
	decoy := c.gen_texture()
	c.bind_texture(gl_texture_2d, decoy)
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 4, 3, gl_rgba, gl_unsigned_byte, []u8{len: 48, init: 77})
	nearest_clamp(mut c)
	c.active_texture(gl_texture0 + 3)
	tex := c.gen_texture()
	c.bind_texture(gl_texture_2d, tex)
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 4, 3, gl_rgba, gl_unsigned_byte, texels(4, 3))
	nearest_clamp(mut c)
	c.use_program(prog)
	c.uniform_ints(c.uniform_location(prog, 'u_tex'), [3])
	draw_quad(mut c, prog)
	assert c.get_error() == gl_no_error
	assert c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte) == texels(4, 3)
	c.uniform_ints(c.uniform_location(prog, 'u_tex'), [max_texture_units])
	assert c.get_error() == gl_invalid_value
	c.uniform_floats(c.uniform_location(prog, 'u_tex'), [f32(1)])
	assert c.get_error() == gl_invalid_operation
}

fn test_incomplete_texture_samples_opaque_black() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := link_program_for(mut c, tex_vs, tex_fs)
	tex := c.gen_texture()
	c.bind_texture(gl_texture_2d, tex)
	// Default minification is a mipmap filter and only level 0 exists.
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 4, 3, gl_rgba, gl_unsigned_byte, texels(4, 3))
	c.use_program(prog)
	draw_quad(mut c, prog)
	assert c.get_error() == gl_no_error
	mut black := []u8{}
	for _ in 0 .. 12 {
		black << [u8(0), 0, 0, 255]
	}
	assert c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte) == black
	// Non power of two with REPEAT is also incomplete; clamping completes it.
	c.tex_parameteri(gl_texture_2d, gl_texture_min_filter, int(gl_nearest))
	c.tex_parameteri(gl_texture_2d, gl_texture_mag_filter, int(gl_nearest))
	draw_quad(mut c, prog)
	assert c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)[0..4] == [u8(0), 0, 0, 255]
	c.tex_parameteri(gl_texture_2d, gl_texture_wrap_s, int(gl_clamp_to_edge))
	c.tex_parameteri(gl_texture_2d, gl_texture_wrap_t, int(gl_clamp_to_edge))
	draw_quad(mut c, prog)
	assert c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte) == texels(4, 3)
	// An unbound unit also reads black instead of failing.
	c.bind_texture(gl_texture_2d, 0)
	draw_quad(mut c, prog)
	assert c.get_error() == gl_no_error
	assert c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)[0..4] == [u8(0), 0, 0, 255]
}

fn test_sampling_the_render_target_is_an_error() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := link_program_for(mut c, tex_vs, tex_fs)
	tex := c.gen_texture()
	c.bind_texture(gl_texture_2d, tex)
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 4, 3, gl_rgba, gl_unsigned_byte, texels(4, 3))
	nearest_clamp(mut c)
	fb := c.gen_framebuffer()
	c.bind_framebuffer(gl_framebuffer, fb)
	c.framebuffer_texture_2d(gl_framebuffer, gl_color_attachment0, gl_texture_2d, tex, 0)
	c.use_program(prog)
	bind_positions(mut c, prog, 'a_pos', [f32(-1), -1, 1, -1, -1, 1])
	c.draw_arrays(gl_triangles, 0, 3)
	assert c.get_error() == gl_invalid_operation
	// The data is untouched.
	assert c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte) == texels(4, 3)
}
