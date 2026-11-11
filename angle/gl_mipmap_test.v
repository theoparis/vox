// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Mipmap tests: the sampling draws run on the Metal device (macOS only).

const mip_vs = '
attribute vec2 a_pos;
varying vec2 v_uv;
void main() {
	v_uv = a_pos * 0.5 + vec2(0.5);
	gl_Position = vec4(a_pos, 0.0, 1.0);
}
'

const mip_fs = '
precision mediump float;
uniform sampler2D u_tex;
varying vec2 v_uv;
void main() {
	gl_FragColor = texture2D(u_tex, v_uv);
}
'

fn mip_setup(mut c Context) u32 {
	prog := link_program_for(mut c, mip_vs, mip_fs)
	bind_positions(mut c, prog, 'a_pos', [f32(-1), -1, 1, -1, -1, 1, 1, 1])
	c.use_program(prog)
	return prog
}

// checker returns a 4x4 texture whose left half is red and right half is blue.
fn halves() []u8 {
	mut out := []u8{}
	for _ in 0 .. 4 {
		for x in 0 .. 4 {
			if x < 2 {
				out << [u8(255), 0, 0, 255]
			} else {
				out << [u8(0), 0, 255, 255]
			}
		}
	}
	return out
}

fn test_generate_mipmap_validation() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	c.generate_mipmap(0x1234)
	assert c.get_error() == gl_invalid_enum
	c.generate_mipmap(gl_texture_2d)
	assert c.get_error() == gl_invalid_operation // nothing bound
	tex := c.gen_texture()
	c.bind_texture(gl_texture_2d, tex)
	c.generate_mipmap(gl_texture_2d)
	assert c.get_error() == gl_invalid_operation // level 0 undefined
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 4, 3, gl_rgba, gl_unsigned_byte, []u8{})
	c.generate_mipmap(gl_texture_2d)
	assert c.get_error() == gl_invalid_operation // 4x3 is not a power of two in GLES 2
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 4, 4, gl_rgba, gl_unsigned_byte, halves())
	c.generate_mipmap(gl_texture_2d)
	assert c.get_error() == gl_no_error
	assert c.textures[tex].mipmapped
	// Redefining level 0 drops the chain.
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 4, 4, gl_rgba, gl_unsigned_byte, halves())
	assert !c.textures[tex].mipmapped
}

fn test_mipmap_filters_sample_the_chain() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := mip_setup(mut c)
	tex := c.gen_texture()
	c.bind_texture(gl_texture_2d, tex)
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 4, 4, gl_rgba, gl_unsigned_byte, halves())
	c.tex_parameteri(gl_texture_2d, gl_texture_mag_filter, int(gl_nearest))
	c.uniform_ints(c.uniform_location(prog, 'u_tex'), [0])
	c.set_clear_color(0, 0, 0, 1)
	// The default min filter is a mipmap filter and there is no chain yet: black.
	c.clear(gl_color_buffer_bit)
	c.draw_arrays(gl_triangle_strip, 0, 4)
	assert c.read_pixels(0, 0, 1, 1, gl_rgba, gl_unsigned_byte) == [u8(0), 0, 0, 255]
	// With the chain the same filter completes and samples a real level.
	c.generate_mipmap(gl_texture_2d)
	c.clear(gl_color_buffer_bit)
	c.draw_arrays(gl_triangle_strip, 0, 4)
	assert c.get_error() == gl_no_error
	left := c.read_pixels(0, 0, 1, 1, gl_rgba, gl_unsigned_byte)
	right := c.read_pixels(3, 0, 1, 1, gl_rgba, gl_unsigned_byte)
	assert left[0] > 200 && left[2] < 60
	assert right[2] > 200 && right[0] < 60
	// Squeeze the 4x4 texture into one pixel: the sampler selects level 2, the
	// 1x1 average of the red and blue halves.
	c.viewport(0, 0, 1, 1)
	c.tex_parameteri(gl_texture_2d, gl_texture_min_filter, int(gl_linear_mipmap_linear))
	c.clear(gl_color_buffer_bit)
	c.draw_arrays(gl_triangle_strip, 0, 4)
	assert c.get_error() == gl_no_error
	mixed := c.read_pixels(0, 0, 1, 1, gl_rgba, gl_unsigned_byte)
	assert mixed[0] >= 120 && mixed[0] <= 135
	assert mixed[2] >= 120 && mixed[2] <= 135
	// Without mipmapping the same minification picks one texel.
	c.tex_parameteri(gl_texture_2d, gl_texture_min_filter, int(gl_nearest))
	c.clear(gl_color_buffer_bit)
	c.draw_arrays(gl_triangle_strip, 0, 4)
	one := c.read_pixels(0, 0, 1, 1, gl_rgba, gl_unsigned_byte)
	assert (one[0] > 200 && one[2] < 60) || (one[2] > 200 && one[0] < 60)
}

fn test_npot_with_mipmap_filter_is_incomplete() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := mip_setup(mut c)
	tex := c.gen_texture()
	c.bind_texture(gl_texture_2d, tex)
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 4, 3, gl_rgba, gl_unsigned_byte, []u8{len: 48, init: 255})
	c.tex_parameteri(gl_texture_2d, gl_texture_wrap_s, int(gl_clamp_to_edge))
	c.tex_parameteri(gl_texture_2d, gl_texture_wrap_t, int(gl_clamp_to_edge))
	c.tex_parameteri(gl_texture_2d, gl_texture_min_filter, int(gl_linear_mipmap_nearest))
	c.uniform_ints(c.uniform_location(prog, 'u_tex'), [0])
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.draw_arrays(gl_triangle_strip, 0, 4)
	assert c.read_pixels(0, 0, 1, 1, gl_rgba, gl_unsigned_byte) == [u8(0), 0, 0, 255]
	c.tex_parameteri(gl_texture_2d, gl_texture_min_filter, int(gl_linear))
	c.draw_arrays(gl_triangle_strip, 0, 4)
	assert c.read_pixels(0, 0, 1, 1, gl_rgba, gl_unsigned_byte) == [u8(255), 255, 255, 255]
}
