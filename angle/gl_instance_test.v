// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Instancing and vertex array object tests; draws run on the Metal device.

const inst_vs = '
attribute vec2 a_pos;
attribute vec2 a_offset;
void main() {
	gl_Position = vec4(a_pos * 0.5 + a_offset, 0.0, 1.0);
}
'

// A quarter-size quad around the origin; instance offsets place it in each
// quadrant of the 4x3 surface.
const inst_quad = [f32(-1), -1, 1, -1, -1, 1, 1, 1]

fn inst_program(mut c Context) u32 {
	prog := link_program_for(mut c, inst_vs, solid_fs)
	c.use_program(prog)
	c.uniform_floats(c.uniform_location(prog, 'u_color'), [f32(1), 0, 0, 1])
	return prog
}

fn bind_floats(mut c Context, loc int, size int, data []f32) u32 {
	buf := c.gen_buffer()
	c.bind_buffer(gl_array_buffer, buf)
	c.buffer_data(gl_array_buffer, data.len * 4, f32_bytes_of(data), gl_static_draw)
	c.vertex_attrib_pointer(loc, size, gl_float, 0, 0)
	c.enable_vertex_attrib(loc, true)
	return buf
}

fn inst_pixel(mut c Context, x int, y int) []u8 {
	return c.read_pixels(x, y, 1, 1, gl_rgba, gl_unsigned_byte)
}

fn test_instanced_attributes_advance_per_divisor() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := inst_program(mut c)
	pos := c.attrib_location(prog, 'a_pos')
	off := c.attrib_location(prog, 'a_offset')
	bind_floats(mut c, pos, 2, inst_quad)
	// Two instances: lower-left and upper-right (offsets in NDC).
	bind_floats(mut c, off, 2, [f32(-0.5), -0.5, 0.5, 0.5])
	c.vertex_attrib_divisor(off, 1)
	assert c.vertex_attrib_param(off, gl_vertex_attrib_array_divisor) or { []f64{} } == [f64(1)]
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.draw_arrays_instanced(gl_triangle_strip, 0, 4, 2)
	assert c.get_error() == gl_no_error
	black := [u8(0), 0, 0, 255]
	red := [u8(255), 0, 0, 255]
	assert inst_pixel(mut c, 0, 0) == red // lower-left quadrant
	assert inst_pixel(mut c, 3, 2) == red // upper-right quadrant
	assert inst_pixel(mut c, 3, 0) == black
	assert inst_pixel(mut c, 0, 2) == black
	// A divisor of 2 holds the first offset for both instances.
	c.vertex_attrib_divisor(off, 2)
	c.clear(gl_color_buffer_bit)
	c.draw_arrays_instanced(gl_triangle_strip, 0, 4, 2)
	assert c.get_error() == gl_no_error
	assert inst_pixel(mut c, 0, 0) == red
	assert inst_pixel(mut c, 3, 2) == black
	// Zero instances draw nothing; negative counts are errors.
	c.draw_arrays_instanced(gl_triangle_strip, 0, 4, 0)
	assert c.get_error() == gl_no_error
	c.draw_arrays_instanced(gl_triangle_strip, 0, 4, -1)
	assert c.get_error() == gl_invalid_value
	c.vertex_attrib_divisor(99, 1)
	assert c.get_error() == gl_invalid_value
}

fn test_instanced_attribute_buffer_bounds_use_the_divisor() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := inst_program(mut c)
	pos := c.attrib_location(prog, 'a_pos')
	off := c.attrib_location(prog, 'a_offset')
	bind_floats(mut c, pos, 2, inst_quad)
	bind_floats(mut c, off, 2, [f32(-0.5), -0.5, 0.5, 0.5]) // two instances worth
	c.vertex_attrib_divisor(off, 1)
	c.draw_arrays_instanced(gl_triangle_strip, 0, 4, 3)
	assert c.get_error() == gl_invalid_operation // the third instance has no data
	c.vertex_attrib_divisor(off, 2)
	c.draw_arrays_instanced(gl_triangle_strip, 0, 4, 3) // instances 0..2 read element 0 and 1
	assert c.get_error() == gl_no_error
	c.vertex_attrib_divisor(off, 3)
	c.draw_arrays_instanced(gl_triangle_strip, 0, 4, 5)
	assert c.get_error() == gl_no_error // elements 0 and 1
}

fn test_draw_elements_instanced() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := inst_program(mut c)
	pos := c.attrib_location(prog, 'a_pos')
	off := c.attrib_location(prog, 'a_offset')
	bind_floats(mut c, pos, 2, inst_quad)
	bind_floats(mut c, off, 2, [f32(-0.5), -0.5, 0.5, 0.5])
	c.vertex_attrib_divisor(off, 1)
	ebo := c.gen_buffer()
	c.bind_buffer(gl_element_array_buffer, ebo)
	c.buffer_data(gl_element_array_buffer, 6, [u8(0), 1, 2, 2, 1, 3], gl_static_draw)
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.draw_elements_instanced(gl_triangles, 6, gl_unsigned_byte, 0, 2)
	assert c.get_error() == gl_no_error
	assert inst_pixel(mut c, 0, 0) == [u8(255), 0, 0, 255]
	assert inst_pixel(mut c, 3, 2) == [u8(255), 0, 0, 255]
	c.draw_elements_instanced(gl_triangles, 6, 0x1406, 0, 2)
	assert c.get_error() == gl_invalid_enum
}

fn test_vertex_array_objects_save_attribute_state() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	prog := inst_program(mut c)
	pos := c.attrib_location(prog, 'a_pos')
	off := c.attrib_location(prog, 'a_offset')
	assert !c.is_vertex_array(1)
	vao := c.gen_vertex_array()
	assert !c.is_vertex_array(vao) // generated but never bound
	c.bind_vertex_array(vao)
	assert c.is_vertex_array(vao)
	assert c.bound_vao == vao
	pbuf := bind_floats(mut c, pos, 2, inst_quad)
	bind_floats(mut c, off, 2, []f32{len: 8})
	ebo := c.gen_buffer()
	c.bind_buffer(gl_element_array_buffer, ebo)
	c.buffer_data(gl_element_array_buffer, 6, [u8(0), 1, 2, 2, 1, 3], gl_static_draw)
	// The default array has none of this state: its attributes are disabled and
	// read their generic values, so a draw is a degenerate point, not an error.
	c.bind_vertex_array(0)
	assert !c.attribs[pos].enabled
	assert c.get_integers(gl_element_array_buffer_binding) == [0]
	c.draw_arrays(gl_triangle_strip, 0, 4)
	assert c.get_error() == gl_no_error
	// Rebinding restores the pointers, the enables and the element buffer.
	c.bind_vertex_array(vao)
	assert c.attribs[pos].enabled && c.attribs[pos].buffer == pbuf
	assert c.get_integers(gl_element_array_buffer_binding) == [int(ebo)]
	c.set_clear_color(0, 0, 0, 1)
	c.clear(gl_color_buffer_bit)
	c.draw_elements(gl_triangles, 6, gl_unsigned_byte, 0)
	assert c.get_error() == gl_no_error
	assert inst_pixel(mut c, 1, 1) == [u8(255), 0, 0, 255]
	assert inst_pixel(mut c, 0, 0) == [u8(0), 0, 0, 255]
	// A second array is independent, including its element binding.
	vao2 := c.gen_vertex_array()
	c.bind_vertex_array(vao2)
	assert !c.attribs[pos].enabled
	assert c.get_integers(gl_element_array_buffer_binding) == [0]
	c.draw_elements(gl_triangles, 6, gl_unsigned_byte, 0)
	assert c.get_error() == gl_invalid_operation // no element buffer in this array
	// Deleting the bound array falls back to the default array.
	c.delete_vertex_array(vao2)
	assert c.bound_vao == 0 && !c.is_vertex_array(vao2)
	c.bind_vertex_array(vao2)
	assert c.get_error() == gl_invalid_operation
	c.bind_vertex_array(9999)
	assert c.get_error() == gl_invalid_operation
	// Divisors are per array.
	c.bind_vertex_array(vao)
	c.vertex_attrib_divisor(off, 4)
	c.bind_vertex_array(0)
	assert c.vertex_attrib_param(off, gl_vertex_attrib_array_divisor) or { []f64{} } == [f64(0)]
	c.bind_vertex_array(vao)
	assert c.vertex_attrib_param(off, gl_vertex_attrib_array_divisor) or { []f64{} } == [f64(4)]
}
