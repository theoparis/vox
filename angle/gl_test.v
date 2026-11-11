// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

fn test_default_framebuffer_clears_and_reads_back() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	assert c.check_framebuffer_status(gl_framebuffer) == gl_framebuffer_complete
	c.set_clear_color(1, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	assert c.get_error() == gl_no_error
	pixels := c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)
	assert c.get_error() == gl_no_error
	assert pixels == solid([u8(255), 0, 0, 255]!, 12)
}

fn test_read_pixels_crops_a_sub_rectangle_in_row_order() {
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
	// A 2x2 image whose four texels are distinct, to check row order.
	image := [u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 2, 2, gl_rgba, gl_unsigned_byte, image)
	assert c.get_error() == gl_no_error
	fbo := c.gen_framebuffer()
	c.bind_framebuffer(gl_framebuffer, fbo)
	c.framebuffer_texture_2d(gl_framebuffer, gl_color_attachment0, gl_texture_2d, tex, 0)
	assert c.check_framebuffer_status(gl_framebuffer) == gl_framebuffer_complete
	row_top_right := c.read_pixels(1, 0, 1, 1, gl_rgba, gl_unsigned_byte)
	assert row_top_right == [u8(5), 6, 7, 8]
	row_second := c.read_pixels(0, 1, 2, 1, gl_rgba, gl_unsigned_byte)
	assert row_second == [u8(9), 10, 11, 12, 13, 14, 15, 16]
	assert c.get_error() == gl_no_error
}

fn test_framebuffer_clear_writes_only_the_attached_texture() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	c.set_clear_color(0, 0, 1, 1)
	c.clear(gl_color_buffer_bit)

	tex := c.gen_texture()
	c.bind_texture(gl_texture_2d, tex)
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 2, 2, gl_rgba, gl_unsigned_byte, []u8{})
	fbo := c.gen_framebuffer()
	c.bind_framebuffer(gl_framebuffer, fbo)
	c.framebuffer_texture_2d(gl_framebuffer, gl_color_attachment0, gl_texture_2d, tex, 0)
	c.set_clear_color(0, 1, 0, 1)
	c.clear(gl_color_buffer_bit)
	assert c.read_pixels(0, 0, 2, 2, gl_rgba, gl_unsigned_byte) == solid([u8(0), 255, 0, 255]!, 4)

	c.bind_framebuffer(gl_framebuffer, 0)
	assert c.read_pixels(0, 0, 1, 1, gl_rgba, gl_unsigned_byte) == [u8(0), 0, 255, 255]
	assert c.get_error() == gl_no_error
}

fn test_incomplete_framebuffer_reports_framebuffer_error() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	fbo := c.gen_framebuffer()
	c.bind_framebuffer(gl_framebuffer, fbo)
	assert c.check_framebuffer_status(gl_framebuffer) == gl_framebuffer_incomplete_missing_attachment
	c.clear(gl_color_buffer_bit)
	assert c.get_error() == gl_invalid_framebuffer_operation
	assert c.get_error() == gl_no_error
}

fn test_buffer_data_and_sub_data_round_trip() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	buf := c.gen_buffer()
	c.bind_buffer(gl_array_buffer, buf)
	c.buffer_data(gl_array_buffer, 8, []u8{}, gl_static_draw)
	assert c.get_buffer_sub_data(gl_array_buffer, 0, 8) == []u8{len: 8}
	c.buffer_sub_data(gl_array_buffer, 2, [u8(9), 8, 7])
	assert c.get_buffer_sub_data(gl_array_buffer, 1, 5) == [u8(0), 9, 8, 7, 0]
	assert c.get_error() == gl_no_error

	c.buffer_sub_data(gl_array_buffer, 7, [u8(1), 2])
	assert c.get_error() == gl_invalid_value
	c.buffer_data(gl_array_buffer, 4, []u8{}, 0x1234)
	assert c.get_error() == gl_invalid_enum
}

fn test_unsupported_and_invalid_requests_record_gl_errors() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	// Clearing the stencil buffer of a surface that has none is a no-op, not an error.
	c.clear(gl_stencil_buffer_bit)
	assert c.get_error() == gl_no_error
	c.clear(0x8000)
	assert c.get_error() == gl_invalid_value
	c.bind_texture(0x1234, 1)
	assert c.get_error() == gl_invalid_enum
	c.read_pixels(0, 0, 9, 9, gl_rgba, gl_unsigned_byte)
	assert c.get_error() == gl_invalid_value
	assert c.get_error() == gl_no_error
}

fn test_deleting_a_texture_unbinds_it_and_releases_storage() {
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
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 1, 1, gl_rgba, gl_unsigned_byte, [u8(1), 2, 3, 4])
	c.delete_texture(tex)
	assert tex !in c.textures
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 1, 1, gl_rgba, gl_unsigned_byte, [u8(1), 2, 3, 4])
	assert c.get_error() == gl_invalid_operation
}
