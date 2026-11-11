// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Depth, culling, and renderbuffer tests. Draws run through the Metal device,
// so they run only on macOS.

const depth_vs = '
attribute vec2 a_pos;
uniform float u_z;
void main() {
	gl_Position = vec4(a_pos, u_z, 1.0);
}
'

fn depth_program(mut c Context) u32 {
	prog := link_program_for(mut c, depth_vs, solid_fs)
	bind_positions(mut c, prog, 'a_pos', [f32(-1), -1, 1, -1, -1, 1, 1, 1])
	c.use_program(prog)
	return prog
}

// quad_at draws the full-surface quad at clip z in one color.
fn quad_at(mut c Context, prog u32, z f32, r f32, g f32, b f32) {
	c.uniform_floats(c.uniform_location(prog, 'u_z'), [z])
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [r, g, b, f32(1)])
	c.draw_arrays(gl_triangle_strip, 0, 4)
}

fn clear_all(mut c Context) {
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit | gl_depth_buffer_bit)
}

// corner reads texel 0 of the 4x3 surface.
fn corner(mut c Context) []u8 {
	return c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)[0..4]
}

fn red() []u8 {
	return [u8(255), 0, 0, 255]
}

fn green() []u8 {
	return [u8(0), 255, 0, 255]
}

fn black() []u8 {
	return [u8(0), 0, 0, 255]
}

fn test_depth_state_defaults_validation_and_queries() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	assert c.get_integers(gl_depth_func_pname) == [int(gl_less)]
	assert c.get_integers(gl_depth_writemask) == [1]
	assert c.get_floats(gl_depth_clear_value) == [f32(1)]
	assert c.get_floats(gl_depth_range_pname) == [f32(0), 1]
	assert c.get_integers(gl_cull_face_mode) == [int(gl_back)]
	assert c.get_integers(gl_front_face_pname) == [int(gl_ccw)]
	assert !c.is_enabled(gl_depth_test) && !c.is_enabled(gl_cull_face_cap)
	c.enable(gl_depth_test)
	c.enable(gl_cull_face_cap)
	assert c.is_enabled(gl_depth_test) && c.is_enabled(gl_cull_face_cap)
	c.depth_func(0x1234)
	assert c.get_error() == gl_invalid_enum
	c.depth_func(gl_gequal)
	assert c.get_integers(gl_depth_func_pname) == [int(gl_gequal)]
	c.cull_face(gl_cw)
	assert c.get_error() == gl_invalid_enum
	c.front_face(gl_back)
	assert c.get_error() == gl_invalid_enum
	c.depth_range(-1, 2)
	assert c.get_floats(gl_depth_range_pname) == [f32(0), 1]
	c.clear_depth(5)
	assert c.get_floats(gl_depth_clear_value) == [f32(1)]
	c.depth_mask(false)
	assert c.get_integers(gl_depth_writemask) == [0]
	assert c.get_error() == gl_no_error
}

fn test_depth_test_keeps_the_nearer_fragment() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := depth_program(mut c)
	clear_all(mut c)
	c.enable(gl_depth_test)
	quad_at(mut c, prog, 0.5, 1, 0, 0)
	// Farther: rejected under LESS.
	quad_at(mut c, prog, 0.8, 0, 1, 0)
	assert c.get_error() == gl_no_error
	assert corner(mut c) == red()
	// Nearer: accepted.
	quad_at(mut c, prog, 0.2, 0, 1, 0)
	assert corner(mut c) == green()
	// With the test disabled the last draw wins regardless of depth.
	c.disable(gl_depth_test)
	quad_at(mut c, prog, 0.9, 1, 0, 0)
	assert corner(mut c) == red()
}

fn test_clip_z_uses_the_gl_range() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := depth_program(mut c)
	clear_all(mut c)
	// GL clip z in [-1, 1] is visible, including negative values.
	quad_at(mut c, prog, -0.5, 1, 0, 0)
	assert corner(mut c) == red()
	// Beyond the far plane the geometry is clipped.
	clear_all(mut c)
	quad_at(mut c, prog, 1.5, 1, 0, 0)
	assert corner(mut c) == black()
	clear_all(mut c)
	quad_at(mut c, prog, -1.5, 1, 0, 0)
	assert corner(mut c) == black()
}

fn test_depth_mask_clear_and_range() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := depth_program(mut c)
	clear_all(mut c)
	c.enable(gl_depth_test)
	// A draw that does not write depth leaves the buffer open.
	c.depth_mask(false)
	quad_at(mut c, prog, -0.5, 1, 0, 0)
	quad_at(mut c, prog, 0.5, 0, 1, 0)
	assert corner(mut c) == green()
	// With the mask off, clearing depth does nothing, so depth stays 1.0 here.
	c.depth_mask(true)
	quad_at(mut c, prog, -0.5, 1, 0, 0)
	quad_at(mut c, prog, 0.5, 0, 1, 0)
	assert corner(mut c) == red()
	// Clearing depth reopens the buffer.
	c.clear(gl_depth_buffer_bit)
	quad_at(mut c, prog, 0.5, 0, 1, 0)
	assert corner(mut c) == green()
	// A clear value of 0 rejects everything under LESS.
	c.clear_depth(0)
	c.clear(gl_depth_buffer_bit)
	quad_at(mut c, prog, -1, 1, 0, 0)
	assert corner(mut c) == green()
	c.clear_depth(1)
	// DepthRange squeezes window depth: both quads land on 0.5, so LESS
	// rejects the second and LEQUAL accepts it.
	c.clear(gl_depth_buffer_bit)
	c.depth_range(0.5, 0.5)
	quad_at(mut c, prog, -0.5, 1, 0, 0)
	quad_at(mut c, prog, 0.5, 0, 1, 0)
	assert corner(mut c) == red()
	c.depth_func(gl_lequal)
	quad_at(mut c, prog, 0.5, 0, 1, 0)
	assert corner(mut c) == green()
}

fn draw_triangle(mut c Context) []u8 {
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.draw_arrays(gl_triangles, 0, 3)
	return corner(mut c)
}

fn test_face_culling() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := link_program_for(mut c, depth_vs, solid_fs)
	// One triangle covering the lower-left half, wound counter-clockwise in GL.
	bind_positions(mut c, prog, 'a_pos', [f32(-1), -1, 1, -1, -1, 1])
	c.use_program(prog)
	c.uniform_floats(c.uniform_location(prog, 'u_z'), [f32(0)])
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [f32(1), 0, 0, 1])
	assert draw_triangle(mut c) == red() // culling off
	c.enable(gl_cull_face_cap)
	assert draw_triangle(mut c) == red() // CCW is front by default; back faces are culled
	c.front_face(gl_cw)
	assert draw_triangle(mut c) == black() // now the triangle is a back face
	c.cull_face(gl_front)
	assert draw_triangle(mut c) == red() // culling front faces keeps the back face
	c.front_face(gl_ccw)
	assert draw_triangle(mut c) == black()
	c.cull_face(gl_front_and_back)
	assert draw_triangle(mut c) == black()
	c.disable(gl_cull_face_cap)
	assert draw_triangle(mut c) == red()
	assert c.get_error() == gl_no_error
}

fn test_renderbuffer_depth_in_a_framebuffer() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := depth_program(mut c)
	tex := c.gen_texture()
	c.bind_texture(gl_texture_2d, tex)
	c.tex_image_2d(gl_texture_2d, 0, gl_rgba, 4, 3, gl_rgba, gl_unsigned_byte, []u8{})
	fb := c.gen_framebuffer()
	c.bind_framebuffer(gl_framebuffer, fb)
	c.framebuffer_texture_2d(gl_framebuffer, gl_color_attachment0, gl_texture_2d, tex, 0)
	rb := c.gen_renderbuffer()
	c.bind_renderbuffer(gl_renderbuffer, rb)
	c.renderbuffer_storage(gl_renderbuffer, gl_depth_component16, 2, 2)
	c.framebuffer_renderbuffer(gl_framebuffer, gl_depth_attachment, gl_renderbuffer, rb)
	assert c.get_error() == gl_no_error
	assert c.check_framebuffer_status(gl_framebuffer) == gl_framebuffer_incomplete_dimensions
	c.renderbuffer_storage(gl_renderbuffer, gl_depth_component16, 4, 3)
	assert c.check_framebuffer_status(gl_framebuffer) == gl_framebuffer_complete
	clear_all(mut c)
	c.enable(gl_depth_test)
	quad_at(mut c, prog, 0.5, 1, 0, 0)
	quad_at(mut c, prog, 0.8, 0, 1, 0)
	assert c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)[0..4] == red()
	quad_at(mut c, prog, 0.2, 0, 1, 0)
	assert c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)[0..4] == green()
	// Without a depth attachment the test has nothing to compare with and passes.
	c.framebuffer_renderbuffer(gl_framebuffer, gl_depth_attachment, gl_renderbuffer, 0)
	quad_at(mut c, prog, 0.9, 1, 0, 0)
	assert c.read_pixels(0, 0, 4, 3, gl_rgba, gl_unsigned_byte)[0..4] == red()
	assert c.get_error() == gl_no_error
	// Deleting an attached renderbuffer detaches it.
	c.framebuffer_renderbuffer(gl_framebuffer, gl_depth_attachment, gl_renderbuffer, rb)
	c.delete_renderbuffer(rb)
	assert c.check_framebuffer_status(gl_framebuffer) == gl_framebuffer_complete
	assert !c.is_renderbuffer(rb)
}

fn test_renderbuffer_validation() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	c.renderbuffer_storage(gl_renderbuffer, gl_depth_component16, 4, 3)
	assert c.get_error() == gl_invalid_operation // nothing bound
	rb := c.gen_renderbuffer()
	c.bind_renderbuffer(0x1234, rb)
	assert c.get_error() == gl_invalid_enum
	c.bind_renderbuffer(gl_renderbuffer, rb)
	c.renderbuffer_storage(gl_renderbuffer, gl_depth_component16, -1, 3)
	assert c.get_error() == gl_invalid_value
	c.renderbuffer_storage(gl_renderbuffer, 0x8058, 4, 3) // GL_RGBA8: not implemented
	assert c.get_error() == gl_invalid_operation
	c.renderbuffer_storage(gl_renderbuffer, 0x84F9, 4, 3) // DEPTH24_STENCIL8: no stencil
	assert c.get_error() == gl_invalid_operation
	fb := c.gen_framebuffer()
	c.framebuffer_renderbuffer(gl_framebuffer, gl_depth_attachment, gl_renderbuffer, rb)
	assert c.get_error() == gl_invalid_operation // default framebuffer bound
	c.bind_framebuffer(gl_framebuffer, fb)
	c.framebuffer_renderbuffer(gl_framebuffer, 0x8D20, gl_renderbuffer, rb)
	assert c.get_error() == gl_invalid_operation // stencil attachment
	c.framebuffer_renderbuffer(gl_framebuffer, gl_depth_attachment, gl_renderbuffer, 9999)
	assert c.get_error() == gl_invalid_operation
	assert c.get_integers(gl_renderbuffer_binding) == [int(rb)]
}
