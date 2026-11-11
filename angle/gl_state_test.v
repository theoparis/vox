// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Draws in these tests use a full-screen triangle on the 4x3 fixture surface.
// Pixel (x, y) is at byte offset (y * 4 + x) * 4 in readback order.

const full_screen = [f32(-1), -1, 3, -1, -1, 3]

fn pixel_at(px []u8, x int, y int) []u8 {
	i := (y * 4 + x) * 4
	return px[i..i + 4]
}

fn test_context_starts_with_a_full_surface_viewport_and_scissor() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	c := f.display.current()
	assert c.viewport == [0, 0, 4, 3]!
	assert c.scissor_rect == [0, 0, 4, 3]!
	assert !c.scissor_test
}

fn test_negative_viewport_and_scissor_sizes_are_invalid_values() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	c.viewport(0, 0, -1, 1)
	assert c.get_error() == gl_invalid_value
	c.scissor(0, 0, 1, -1)
	assert c.get_error() == gl_invalid_value
	// A rejected call leaves the previous rectangle intact.
	assert c.viewport == [0, 0, 4, 3]!
}

fn test_enable_rejects_unknown_capabilities() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	c.enable(0x0B20) // GL_LINE_SMOOTH
	assert c.get_error() == gl_invalid_enum
	c.enable(gl_scissor_test)
	assert c.scissor_test
	c.disable(gl_scissor_test)
	assert !c.scissor_test
}

fn test_scissor_limits_a_draw_to_its_rectangle() {
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
	bind_positions(mut c, prog, 'a_pos', full_screen)
	c.uniform_floats(c.uniform_location(prog, 'u_offset'), [f32(0), 0])
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [f32(1), 1, 1, 1])
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.enable(gl_scissor_test)
	c.scissor(1, 1, 2, 1)
	c.draw_arrays(gl_triangles, 0, 3)
	assert c.get_error() == gl_no_error
	px := c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)
	white := [u8(255), 255, 255, 255]
	black := [u8(0), 0, 0, 255]
	assert pixel_at(px, 1, 1) == white
	assert pixel_at(px, 2, 1) == white
	// Neighbours outside the rectangle keep the clear color.
	assert pixel_at(px, 0, 1) == black
	assert pixel_at(px, 3, 1) == black
	assert pixel_at(px, 1, 0) == black
	assert pixel_at(px, 1, 2) == black
}

fn test_scissor_rectangle_is_clipped_to_the_target() {
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
	bind_positions(mut c, prog, 'a_pos', full_screen)
	c.uniform_floats(c.uniform_location(prog, 'u_offset'), [f32(0), 0])
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [f32(1), 1, 1, 1])
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.enable(gl_scissor_test)
	// Extends beyond the 4x3 target on every side, so Metal would reject it unclipped.
	c.scissor(-5, -5, 100, 100)
	c.draw_arrays(gl_triangles, 0, 3)
	assert c.get_error() == gl_no_error
	px := c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)
	assert pixel_at(px, 0, 0) == [u8(255), 255, 255, 255]
	assert pixel_at(px, 3, 2) == [u8(255), 255, 255, 255]
}

fn test_empty_scissor_draws_nothing_without_an_error() {
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
	bind_positions(mut c, prog, 'a_pos', full_screen)
	c.uniform_floats(c.uniform_location(prog, 'u_offset'), [f32(0), 0])
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [f32(1), 1, 1, 1])
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.enable(gl_scissor_test)
	c.scissor(0, 0, 0, 3)
	c.draw_arrays(gl_triangles, 0, 3)
	assert c.get_error() == gl_no_error
	px := c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)
	assert pixel_at(px, 0, 0) == [u8(0), 0, 0, 255]
	// Scissor off again: the same draw now covers the surface.
	c.disable(gl_scissor_test)
	c.draw_arrays(gl_triangles, 0, 3)
	px2 := c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)
	assert pixel_at(px2, 0, 0) == [u8(255), 255, 255, 255]
}

fn test_viewport_maps_ndc_to_a_sub_rectangle() {
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
	// This triangle covers the whole NDC square, so it fills exactly the viewport.
	bind_positions(mut c, prog, 'a_pos', full_screen)
	c.uniform_floats(c.uniform_location(prog, 'u_offset'), [f32(0), 0])
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [f32(1), 1, 1, 1])
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.viewport(2, 1, 2, 2)
	c.draw_arrays(gl_triangles, 0, 3)
	assert c.get_error() == gl_no_error
	px := c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)
	// Clipping to the NDC square happens before the viewport transform, so the
	// fill is exactly x 2..3, y 1..2 and everything else keeps the clear color.
	white := [u8(255), 255, 255, 255]
	black := [u8(0), 0, 0, 255]
	assert pixel_at(px, 2, 1) == white
	assert pixel_at(px, 3, 2) == white
	assert pixel_at(px, 1, 1) == black
	assert pixel_at(px, 2, 0) == black
	assert pixel_at(px, 0, 0) == black
}

fn test_scissored_clear_touches_only_the_rectangle() {
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
	c.enable(gl_scissor_test)
	c.scissor(1, 1, 2, 1)
	c.set_clear_color(1, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	assert c.get_error() == gl_no_error
	px := fn [mut c] (x int, y int) []u8 {
		return c.read_pixels(x, y, 1, 1, gl_rgba, gl_unsigned_byte)
	}
	assert px(1, 1) == [u8(255), 0, 0, 255]
	assert px(2, 1) == [u8(255), 0, 0, 255]
	assert px(0, 1) == [u8(0), 0, 255, 255]
	assert px(3, 1) == [u8(0), 0, 255, 255]
	assert px(1, 0) == [u8(0), 0, 255, 255]
	assert px(1, 2) == [u8(0), 0, 255, 255]
	// An empty rectangle clears nothing, and clears do not depend on the viewport.
	c.scissor(0, 0, 0, 0)
	c.set_clear_color(0, 1, 0, 1)
	c.clear(gl_color_buffer_bit)
	assert px(1, 1) == [u8(255), 0, 0, 255]
	c.viewport(0, 0, 0, 0)
	c.scissor(0, 0, 4, 3)
	c.clear(gl_color_buffer_bit)
	assert px(3, 2) == [u8(0), 255, 0, 255]
	assert c.get_error() == gl_no_error
}
