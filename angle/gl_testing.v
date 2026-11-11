// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Test fixtures shared by the GL test files. They create real EGL contexts on
// the Metal device; the translation path never calls them.

// GLFixture is a current GLES3 context on a 4x3 pbuffer. Callers must use it
// only on macOS, where the Metal backend exists.
struct GLFixture {
mut:
	display &Display = unsafe { nil }
	surface &Surface = unsafe { nil }
	context &Context = unsafe { nil }
}

fn gl_fixture() !GLFixture {
	mut display := initialize_display(.metal)!
	config := display.choose_config(egl_opengl_es3_bit)!
	mut surface := display.create_pbuffer_surface(4, 3)!
	mut context := display.create_context(config, 3)!
	display.make_current(mut surface, mut context)!
	return GLFixture{
		display: display
		surface: surface
		context: context
	}
}

fn (mut f GLFixture) teardown() {
	f.display.unbind()
	f.display.destroy_context(mut f.context)
	f.display.destroy_surface(mut f.surface)
	f.display.terminate()
}

// solid returns count RGBA8 pixels of one color.
fn solid(pixel [4]u8, count int) []u8 {
	mut out := []u8{cap: count * 4}
	for _ in 0 .. count {
		out << pixel[0]
		out << pixel[1]
		out << pixel[2]
		out << pixel[3]
	}
	return out
}

// f32_bytes_of packs values as little-endian floats, the layout GL buffers use.
fn f32_bytes_of(values []f32) []u8 {
	mut out := []u8{cap: values.len * 4}
	for v in values {
		bits := f32_bits(v)
		out << u8(bits)
		out << u8(bits >> 8)
		out << u8(bits >> 16)
		out << u8(bits >> 24)
	}
	return out
}

const tri_vs = '
attribute vec2 a_pos;
uniform vec2 u_offset;
void main() {
	gl_Position = vec4(a_pos + u_offset, 0.0, 1.0);
}
'

const solid_fs = '
precision mediump float;
uniform vec4 u_color;
void main() {
	gl_FragColor = u_color;
}
'

// link_program_for compiles and links a vertex and fragment source pair.
fn link_program_for(mut c Context, vs_src string, fs_src string) u32 {
	vs := c.create_shader(gl_vertex_shader)
	c.shader_source(vs, vs_src)
	assert c.compile_shader(vs), c.shader_log(vs)
	fs := c.create_shader(gl_fragment_shader)
	c.shader_source(fs, fs_src)
	assert c.compile_shader(fs), c.shader_log(fs)
	prog := c.create_program()
	c.attach_shader(prog, vs)
	c.attach_shader(prog, fs)
	assert c.link_program(prog), c.program_log(prog)
	return prog
}

// bind_positions uploads positions to a buffer and enables the attribute.
fn bind_positions(mut c Context, prog u32, name string, positions []f32) {
	buf := c.gen_buffer()
	c.bind_buffer(gl_array_buffer, buf)
	c.buffer_data(gl_array_buffer, positions.len * 4, f32_bytes_of(positions), gl_static_draw)
	loc := c.attrib_location(prog, name)
	assert loc >= 0
	c.vertex_attrib_pointer(loc, 2, gl_float, 0, 0)
	c.enable_vertex_attrib(loc, true)
}
