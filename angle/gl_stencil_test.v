// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Stencil tests: state, clears, framebuffer attachments and draws on the Metal
// device (macOS only). The default surface is 4x3 and has a stencil plane.

const stencil_vs = '
attribute vec2 a_pos;
void main() {
	gl_Position = vec4(a_pos, 0.0, 1.0);
}
'

fn stencil_program(mut c Context) u32 {
	prog := link_program_for(mut c, stencil_vs, solid_fs)
	c.use_program(prog)
	return prog
}

// stencil_rect draws the NDC rectangle [x0, x1] x [-1, 1] in one color.
fn stencil_rect(mut c Context, prog u32, x0 f32, x1 f32, r f32, g f32, b f32) {
	bind_positions(mut c, prog, 'a_pos', [x0, f32(-1), x1, f32(-1), x0, f32(1), x1, f32(1)])
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [r, g, b, f32(1)])
	c.draw_arrays(gl_triangle_strip, 0, 4)
}

fn stencil_pixel(mut c Context, x int) []u8 {
	return c.read_pixels(x, 1, 1, 1, gl_rgba, gl_unsigned_byte)
}

fn stencil_clear(mut c Context) {
	c.set_clear_color(0, 0, 0, 1)
	c.clear_stencil(0)
	c.clear(gl_color_buffer_bit | gl_stencil_buffer_bit)
}

fn test_stencil_state_defaults_and_queries() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	assert c.get_integers(0x0B92) == [int(gl_always)]
	assert c.get_integers(0x0B97) == [0]
	assert c.get_integers(0x0B94) == [int(gl_keep)]
	assert c.get_integers(0x0D57) == [8]
	c.stencil_func_separate(gl_front, gl_less, 300, 0x0F)
	c.stencil_op_separate(gl_back, gl_replace, gl_incr, gl_decr)
	c.stencil_mask_separate(gl_back, 0x3C)
	assert c.get_error() == gl_no_error
	assert c.get_integers(0x0B92) == [int(gl_less)]
	assert c.get_integers(0x0B97) == [255] // the reference clamps to the plane
	assert c.get_integers(0x0B93) == [0x0F]
	assert c.get_integers(0x8800) == [int(gl_always)] // back face untouched
	assert c.get_integers(0x8801) == [int(gl_replace)]
	assert c.get_integers(0x8802) == [int(gl_incr)]
	assert c.get_integers(0x8803) == [int(gl_decr)]
	assert c.get_integers(0x8CA5) == [0x3C]
	assert c.get_integers(0x0B98) == [-1] // all 32 bits, as GL reports
}

fn test_stencil_masks_a_later_draw() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := stencil_program(mut c)
	stencil_clear(mut c)
	c.enable(gl_stencil_test_cap)
	// Mark the left half with 1 (the color is drawn too, then cleared again).
	c.stencil_func(gl_always, 1, 0xff)
	c.stencil_op(gl_keep, gl_keep, gl_replace)
	stencil_rect(mut c, prog, -1, 0, 1, 0, 0)
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	assert c.get_error() == gl_no_error
	// Only stencil == 1 passes now.
	c.stencil_func(gl_equal, 1, 0xff)
	c.stencil_op(gl_keep, gl_keep, gl_keep)
	stencil_rect(mut c, prog, -1, 1, 0, 1, 0)
	assert stencil_pixel(mut c, 0) == [u8(0), 255, 0, 255]
	assert stencil_pixel(mut c, 3) == [u8(0), 0, 0, 255]
	// NOTEQUAL covers the other half.
	c.clear(gl_color_buffer_bit)
	c.stencil_func(gl_notequal, 1, 0xff)
	stencil_rect(mut c, prog, -1, 1, 0, 0, 1)
	assert stencil_pixel(mut c, 0) == [u8(0), 0, 0, 255]
	assert stencil_pixel(mut c, 3) == [u8(0), 0, 255, 255]
	// Disabling the test draws everywhere.
	c.disable(gl_stencil_test_cap)
	stencil_rect(mut c, prog, -1, 1, 1, 1, 1)
	assert stencil_pixel(mut c, 0) == [u8(255), 255, 255, 255]
}

fn test_stencil_operations_and_write_mask() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := stencil_program(mut c)
	stencil_clear(mut c)
	c.enable(gl_stencil_test_cap)
	c.stencil_func(gl_always, 0, 0xff)
	c.stencil_op(gl_keep, gl_keep, gl_incr)
	stencil_rect(mut c, prog, -1, 1, 1, 1, 1)
	stencil_rect(mut c, prog, -1, 0, 1, 1, 1) // left half is now 2, right half 1
	stencil_rect(mut c, prog, -1, 0, 1, 1, 1) // left half 3
	c.stencil_op(gl_keep, gl_keep, gl_keep)
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.stencil_func(gl_equal, 3, 0xff)
	stencil_rect(mut c, prog, -1, 1, 0, 1, 0)
	assert stencil_pixel(mut c, 0) == [u8(0), 255, 0, 255]
	assert stencil_pixel(mut c, 3) == [u8(0), 0, 0, 255]
	// A zero write mask stops updates: INVERT would otherwise change 3 to 252.
	c.stencil_mask(0)
	c.stencil_op(gl_invert, gl_invert, gl_invert)
	c.stencil_func(gl_always, 0, 0xff)
	stencil_rect(mut c, prog, -1, 1, 1, 1, 1)
	c.stencil_mask(0xff)
	c.clear(gl_color_buffer_bit)
	c.stencil_op(gl_keep, gl_keep, gl_keep)
	c.stencil_func(gl_equal, 3, 0xff)
	stencil_rect(mut c, prog, -1, 1, 0, 1, 0)
	assert stencil_pixel(mut c, 0) == [u8(0), 255, 0, 255]
	// The read mask limits the compared bits: 3 & 0x01 == 1.
	c.clear(gl_color_buffer_bit)
	c.stencil_func(gl_equal, 1, 0x01)
	stencil_rect(mut c, prog, -1, 1, 0, 0, 1)
	assert stencil_pixel(mut c, 0) == [u8(0), 0, 255, 255]
	// Failing the stencil test applies the fail operation: ZERO clears it.
	c.stencil_func(gl_never, 0, 0xff)
	c.stencil_op(gl_zero, gl_keep, gl_keep)
	stencil_rect(mut c, prog, -1, 0, 1, 1, 1)
	c.clear(gl_color_buffer_bit)
	c.stencil_func(gl_equal, 0, 0xff)
	c.stencil_op(gl_keep, gl_keep, gl_keep)
	stencil_rect(mut c, prog, -1, 1, 1, 0, 0)
	assert stencil_pixel(mut c, 0) == [u8(255), 0, 0, 255] // left half zeroed
	assert stencil_pixel(mut c, 3) == [u8(0), 0, 0, 255] // right half still 1 or 3
	assert c.get_error() == gl_no_error
}

fn test_stencil_depth_fail_operation() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := link_program_for(mut c, 'attribute vec2 a_pos;\nuniform float u_z;\nvoid main() { gl_Position = vec4(a_pos, u_z, 1.0); }',
		solid_fs)
	c.use_program(prog)
	bind_positions(mut c, prog, 'a_pos', [f32(-1), -1, 1, -1, -1, 1, 1, 1])
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [f32(1), 1, 1, 1])
	c.set_clear_color(0, 0, 0, 1)
	c.clear_stencil(0)
	c.clear(gl_color_buffer_bit | gl_depth_buffer_bit | gl_stencil_buffer_bit)
	c.enable(gl_depth_test)
	c.enable(gl_stencil_test_cap)
	c.stencil_func(gl_always, 7, 0xff)
	c.stencil_op(gl_keep, gl_replace, gl_keep) // write 7 only when depth fails
	c.uniform_floats(c.uniform_location(prog, 'u_z'), [f32(-0.5)])
	c.draw_arrays(gl_triangle_strip, 0, 4) // passes depth: stencil stays 0
	c.uniform_floats(c.uniform_location(prog, 'u_z'), [f32(0.5)])
	c.draw_arrays(gl_triangle_strip, 0, 4) // farther than the first: depth fails
	c.clear(gl_color_buffer_bit)
	c.disable(gl_depth_test)
	c.stencil_func(gl_equal, 7, 0xff)
	c.stencil_op(gl_keep, gl_keep, gl_keep)
	c.draw_arrays(gl_triangle_strip, 0, 4)
	assert stencil_pixel(mut c, 1) == [u8(255), 255, 255, 255]
}

fn test_stencil_faces_are_separate() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := stencil_program(mut c)
	stencil_clear(mut c)
	c.enable(gl_stencil_test_cap)
	// The strip is counter-clockwise, so it is front-facing.
	c.stencil_func_separate(gl_front, gl_never, 0, 0xff)
	c.stencil_func_separate(gl_back, gl_always, 0, 0xff)
	stencil_rect(mut c, prog, -1, 1, 1, 0, 0)
	assert stencil_pixel(mut c, 1) == [u8(0), 0, 0, 255]
	c.stencil_func_separate(gl_front, gl_always, 0, 0xff)
	c.stencil_func_separate(gl_back, gl_never, 0, 0xff)
	stencil_rect(mut c, prog, -1, 1, 1, 0, 0)
	assert stencil_pixel(mut c, 1) == [u8(255), 0, 0, 255]
	// Flipping the front face swaps which state applies.
	c.clear(gl_color_buffer_bit)
	c.front_face(gl_cw)
	stencil_rect(mut c, prog, -1, 1, 0, 1, 0)
	assert stencil_pixel(mut c, 1) == [u8(0), 0, 0, 255]
}

fn test_stencil_clear_value_and_write_mask() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := stencil_program(mut c)
	c.set_clear_color(0, 0, 0, 1)
	c.clear_stencil(5)
	c.clear(gl_color_buffer_bit | gl_stencil_buffer_bit)
	c.enable(gl_stencil_test_cap)
	c.stencil_func(gl_equal, 5, 0xff)
	stencil_rect(mut c, prog, -1, 1, 0, 1, 0)
	assert stencil_pixel(mut c, 2) == [u8(0), 255, 0, 255]
	// Only the low 8 bits of the clear value reach the plane.
	c.clear_stencil(0x105)
	c.clear(gl_stencil_buffer_bit)
	c.clear(gl_color_buffer_bit)
	stencil_rect(mut c, prog, -1, 1, 1, 0, 0)
	assert stencil_pixel(mut c, 2) == [u8(255), 0, 0, 255]
	// A zero write mask leaves the plane alone; a partial mask is refused.
	c.stencil_mask(0)
	c.clear_stencil(9)
	c.clear(gl_stencil_buffer_bit)
	assert c.get_error() == gl_no_error
	c.stencil_mask(0x0f)
	c.clear(gl_stencil_buffer_bit)
	assert c.get_error() == gl_invalid_operation
	c.stencil_mask(0xff)
	c.clear(gl_color_buffer_bit)
	stencil_rect(mut c, prog, -1, 1, 0, 0, 1)
	assert stencil_pixel(mut c, 2) == [u8(0), 0, 255, 255] // still 5, equal to ref 5
}

fn stencil_fbo(mut c Context, w int, h int) {
	tex := c.gen_texture()
	c.bind_texture(gl_texture_2d, tex)
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, w, h, gl_rgba, gl_unsigned_byte, []u8{})
	fb := c.gen_framebuffer()
	c.bind_framebuffer(gl_framebuffer, fb)
	c.framebuffer_texture_2d(gl_framebuffer, gl_color_attachment0, gl_texture_2d, tex, 0)
}

fn test_stencil_renderbuffer_attachments() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := stencil_program(mut c)
	stencil_fbo(mut c, 4, 3)
	assert c.get_integers(0x0D57) == [0]
	// With no stencil attachment the test always passes.
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.enable(gl_stencil_test_cap)
	c.stencil_func(gl_never, 0, 0xff)
	stencil_rect(mut c, prog, -1, 1, 1, 0, 0)
	assert stencil_pixel(mut c, 0) == [u8(255), 0, 0, 255]
	// A stencil-only renderbuffer.
	srb := c.gen_renderbuffer()
	c.bind_renderbuffer(gl_renderbuffer, srb)
	c.renderbuffer_storage(gl_renderbuffer, gl_stencil_index8, 4, 3)
	assert c.get_error() == gl_no_error
	assert (c.renderbuffer_parameter(gl_renderbuffer, gl_renderbuffer_stencil_size) or { -1 }) == 8
	assert (c.renderbuffer_parameter(gl_renderbuffer, gl_renderbuffer_depth_size) or { -1 }) == 0
	c.framebuffer_renderbuffer(gl_framebuffer, gl_stencil_attachment, gl_renderbuffer, srb)
	assert c.check_framebuffer_status(gl_framebuffer) == gl_framebuffer_complete
	assert c.get_integers(0x0D57) == [8]
	c.clear(gl_color_buffer_bit | gl_stencil_buffer_bit)
	stencil_rect(mut c, prog, -1, 1, 0, 1, 0)
	assert stencil_pixel(mut c, 0) == [u8(0), 0, 0, 255] // NEVER now applies
	c.stencil_func(gl_equal, 0, 0xff)
	stencil_rect(mut c, prog, -1, 1, 0, 1, 0)
	assert stencil_pixel(mut c, 0) == [u8(0), 255, 0, 255]
	// Depth testing against a stencil-only target has nothing to compare: passes.
	c.enable(gl_depth_test)
	c.depth_func(gl_never)
	c.clear(gl_color_buffer_bit)
	stencil_rect(mut c, prog, -1, 1, 1, 1, 0)
	assert stencil_pixel(mut c, 0) == [u8(255), 255, 0, 255]
	c.disable(gl_depth_test)
	// A depth renderbuffer cannot serve as the stencil attachment.
	drb := c.gen_renderbuffer()
	c.bind_renderbuffer(gl_renderbuffer, drb)
	c.renderbuffer_storage(gl_renderbuffer, gl_depth_component16, 4, 3)
	c.framebuffer_renderbuffer(gl_framebuffer, gl_stencil_attachment, gl_renderbuffer, drb)
	assert c.check_framebuffer_status(gl_framebuffer) == gl_framebuffer_incomplete_attachment
	// Separate depth and stencil renderbuffers cannot share one texture.
	c.framebuffer_renderbuffer(gl_framebuffer, gl_stencil_attachment, gl_renderbuffer, srb)
	c.framebuffer_renderbuffer(gl_framebuffer, gl_depth_attachment, gl_renderbuffer, drb)
	assert c.check_framebuffer_status(gl_framebuffer) == gl_framebuffer_unsupported
	// A packed renderbuffer provides both planes through the combined attachment.
	prb := c.gen_renderbuffer()
	c.bind_renderbuffer(gl_renderbuffer, prb)
	c.renderbuffer_storage(gl_renderbuffer, gl_depth24_stencil8, 4, 3)
	c.framebuffer_renderbuffer(gl_framebuffer, gl_depth_stencil_attachment, gl_renderbuffer, prb)
	assert c.check_framebuffer_status(gl_framebuffer) == gl_framebuffer_complete
	assert c.get_integers(0x0D57) == [8]
	c.enable(gl_depth_test)
	c.depth_func(gl_less)
	c.stencil_func(gl_always, 0, 0xff)
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit | gl_depth_buffer_bit | gl_stencil_buffer_bit)
	stencil_rect(mut c, prog, -1, 1, 1, 0, 1)
	assert stencil_pixel(mut c, 0) == [u8(255), 0, 255, 255]
	// Dimension mismatches are reported for the stencil attachment too.
	c.bind_renderbuffer(gl_renderbuffer, prb)
	c.renderbuffer_storage(gl_renderbuffer, gl_depth24_stencil8, 2, 2)
	assert c.check_framebuffer_status(gl_framebuffer) == gl_framebuffer_incomplete_dimensions
}
