// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

fn test_deleting_an_attached_shader_is_deferred_until_detach() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	vs := c.create_shader(gl_vertex_shader)
	prog := c.create_program()
	c.attach_shader(prog, vs)
	c.delete_shader(vs)
	assert c.is_shader(vs)
	c.detach_shader(prog, vs)
	assert !c.is_shader(vs)
	assert c.get_error() == gl_no_error
}

fn test_deleting_a_shader_frees_it_immediately_when_unattached() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	fs := c.create_shader(gl_fragment_shader)
	c.delete_shader(fs)
	assert !c.is_shader(fs)
	c.delete_shader(fs)
	assert c.get_error() == gl_invalid_value
	c.delete_shader(0)
	assert c.get_error() == gl_no_error
}

fn test_detaching_an_unattached_shader_is_invalid_operation() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	vs := c.create_shader(gl_vertex_shader)
	prog := c.create_program()
	c.detach_shader(prog, vs)
	assert c.get_error() == gl_invalid_operation
}

fn test_deleting_the_current_program_waits_for_it_to_be_replaced() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	first := link_program_for(mut c, tri_vs, solid_fs)
	second := link_program_for(mut c, tri_vs, solid_fs)
	c.use_program(first)
	c.delete_program(first)
	// Still current, so still usable.
	assert c.is_program(first)
	assert c.get_integers(gl_current_program) == [int(first)]
	c.use_program(second)
	assert !c.is_program(first)
	assert c.is_program(second)
	assert c.get_error() == gl_no_error
	// A program that is not current goes at once, and its shaders with it once released.
	c.delete_program(second)
	assert c.is_program(second)
	c.use_program(0)
	assert !c.is_program(second)
}

fn test_queries_report_actual_state_and_reject_unknown_names() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	assert c.get_integers(gl_viewport_pname) == [0, 0, 4, 3]
	c.viewport(1, 2, 3, 4)
	assert c.get_integers(gl_viewport_pname) == [1, 2, 3, 4]
	c.set_clear_color(0.25, 0.5, 0.75, 1)
	assert c.get_floats(gl_color_clear_value) == [f32(0.25), 0.5, 0.75, 1]
	assert c.get_integers(gl_max_vertex_attribs) == [16]
	buf := c.gen_buffer()
	c.bind_buffer(gl_array_buffer, buf)
	assert c.get_integers(gl_array_buffer_binding) == [int(buf)]
	assert c.get_integers(0x1234).len == 0
	assert c.get_error() == gl_invalid_enum
}

fn test_strings_describe_the_implementation_without_claiming_es3() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	assert (c.get_string(gl_version) or { '' }).starts_with('OpenGL ES 2.0')
	assert (c.get_string(gl_renderer) or { '' }).contains('metal:')
	assert (c.get_string(gl_extensions) or { 'x' }) == 'GL_ANGLE_instanced_arrays GL_OES_vertex_array_object'
	assert c.get_error() == gl_no_error
	c.get_string(0x1234) or {
		assert c.get_error() == gl_invalid_enum
		return
	}
	assert false, 'unknown string names must fail'
}

fn test_precision_formats_and_shader_source_round_trip() {
	$if !macos {
		return
	}
	mut f := gl_fixture() or { panic(err.msg()) }
	defer {
		f.teardown()
	}
	mut c := f.display.current()
	assert c.shader_precision_format(gl_fragment_shader, 0x8DF2) == [127, 127, 23]
	assert c.shader_precision_format(gl_vertex_shader, 0x8DF5) == [31, 30, 0]
	assert c.shader_precision_format(0x1234, 0x8DF2).len == 0
	assert c.get_error() == gl_invalid_enum
	vs := c.create_shader(gl_vertex_shader)
	c.shader_source(vs, 'void main() {}')
	assert c.get_shader_source(vs) == 'void main() {}'
}
