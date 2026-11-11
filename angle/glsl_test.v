// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// These tests run on every platform: they exercise the GLSL front end, the
// link planner, and the MSL emitter without a GPU.

const pair_vs = '
attribute vec2 a_pos;
attribute vec3 a_color;
uniform vec2 u_offset;
uniform vec4 u_tint;
varying vec3 v_color;
void main() {
	v_color = a_color * u_tint.rgb;
	gl_Position = vec4(a_pos + u_offset, 0.0, 1.0);
}
'

const pair_fs = '
precision mediump float;
varying vec3 v_color;
uniform vec4 u_tint;
void main() {
	gl_FragColor = vec4(v_color, u_tint.a);
}
'

fn parse_checked(src string, stage Stage) Unit {
	mut unit := glsl_parse(src) or { panic(err.msg()) }
	check_unit(mut unit, stage) or { panic(err.msg()) }
	return unit
}

// expect_shader_error asserts that parsing or checking fails with a message
// containing want.
fn expect_shader_error(src string, stage Stage, want string) {
	mut unit := glsl_parse(src) or {
		assert err.msg().contains(want), 'got "${err.msg()}", want "${want}"'
		return
	}
	check_unit(mut unit, stage) or {
		assert err.msg().contains(want), 'got "${err.msg()}", want "${want}"'
		return
	}
	assert false, 'expected an error containing "${want}"'
}

fn test_plan_assigns_attribute_varying_and_uniform_slots() {
	vs := parse_checked(pair_vs, .vertex)
	fs := parse_checked(pair_fs, .fragment)
	plan := plan_link(&vs, &fs) or { panic(err.msg()) }
	assert plan.vs_layout.attrs.len == 2
	assert plan.vs_layout.attrs[0].name == 'a_pos'
	assert plan.vs_layout.attrs[0].loc == 0
	assert plan.vs_layout.attrs[1].name == 'a_color'
	assert plan.vs_layout.attrs[1].loc == 1
	assert plan.uniforms.len == 2
	assert plan.uniforms[0].name == 'u_offset'
	assert plan.uniforms[1].name == 'u_tint'
	assert plan.fs_layout.varyings.len == 1
	assert plan.fs_layout.varyings[0].loc == 0
	assert plan.vs_layout.varyings[0].loc == 0
}

fn test_emits_vertex_and_fragment_msl_with_flip_and_io_structs() {
	vs := parse_checked(pair_vs, .vertex)
	fs := parse_checked(pair_fs, .fragment)
	plan := plan_link(&vs, &fs) or { panic(err.msg()) }
	vsrc := emit_msl(&vs, .vertex, plan.vs_layout)
	fsrc := emit_msl(&fs, .fragment, plan.fs_layout)
	assert vsrc.contains('float2 a_a_pos [[attribute(0)]];')
	assert vsrc.contains('float3 a_a_color [[attribute(1)]];')
	assert vsrc.contains('float3 v_v_color [[user(locn0)]];')
	assert vsrc.contains('vertex VS_Out vs_entry(')
	assert vsrc.contains('_out.position.y = -_out.position.y;')
	assert vsrc.contains('constant float4 &u_u_tint [[buffer(1)]]')
	assert fsrc.contains('fragment FS_Out fs_entry(')
	assert fsrc.contains('float3 v_v_color [[user(locn0)]];')
	assert fsrc.contains('FS_Out _out{};')
}

fn test_emits_glsl_builtins_and_constructors_as_msl() {
	src := '
uniform float u_scale;
void main() {
	float t = mod(u_scale, 0.3) + .5;
	gl_Position = vec4(t, 1.0, 0.0, 1.0).xyzw;
}
'
	unit := parse_checked(src, .vertex)
	plan := plan_link(&unit, &unit) or { panic(err.msg()) }
	code := emit_msl(&unit, .vertex, plan.vs_layout)
	assert code.contains('glsl_mod(u_u_scale, 0.3)')
	assert code.contains('0.5')
	assert code.contains('float4(l_t, 1.0, 0.0, 1.0)')
}

fn test_vector_equality_emits_all_and_any() {
	src := '
void main() {
	bool same = vec2(1.0, 2.0) == vec2(1.0, 2.0);
	bool differ = vec2(1.0) != vec2(2.0);
	gl_Position = vec4(0.0);
	if (same && differ) {
		gl_Position.x = 1.0;
	}
}
'
	unit := parse_checked(src, .vertex)
	plan := plan_link(&unit, &unit) or { panic(err.msg()) }
	code := emit_msl(&unit, .vertex, plan.vs_layout)
	assert code.contains('all(')
	assert code.contains('any(')
}

fn test_loops_and_compound_assignment_translate() {
	src := '
precision mediump float;
void main() {
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += 0.25;
	}
	gl_FragColor = vec4(s);
}
'
	unit := parse_checked(src, .fragment)
	plan := plan_link(&unit, &unit) or { panic(err.msg()) }
	code := emit_msl(&unit, .fragment, plan.fs_layout)
	assert code.contains('for (int l_i = 0; (l_i < 4); l_i++) {')
	assert code.contains('l_s = (l_s) + (0.25);')
}

fn test_rejects_undeclared_identifiers() {
	expect_shader_error('void main() { gl_FragColor = nope; }', .fragment, 'undeclared identifier')
}

fn test_rejects_mismatched_initializers_and_assignments() {
	expect_shader_error('void main() { float x = vec2(1.0, 2.0); gl_Position = vec4(x); }',
		.vertex, 'cannot initialize')
	expect_shader_error('void main() { vec2 v = vec2(1.0); v = 1.0; gl_Position = vec4(v, 0.0, 1.0); }',
		.vertex, 'cannot assign')
}

fn test_rejects_stage_storage_misuse() {
	expect_shader_error('attribute vec2 a; void main() { gl_FragColor = vec4(a, 0.0, 1.0); }',
		.fragment, 'only available in vertex shaders')
	expect_shader_error('uniform float u; void main() { u = 1.0; gl_Position = vec4(0.0); }',
		.vertex, 'cannot be assigned')
	expect_shader_error('varying float v; void main() { v = 1.0; gl_FragColor = vec4(v); }',
		.fragment, 'read-only in a fragment shader')
	expect_shader_error('attribute float a; void main() { a = 1.0; gl_Position = vec4(a); }',
		.vertex, 'cannot be assigned')
}

fn test_rejects_unsupported_preprocessor_and_samplers() {
	expect_shader_error('#define X 1\nvoid main() { gl_Position = vec4(0.0); }', .vertex,
		'unsupported directive')
	expect_shader_error('#version 300 es\nvoid main() { gl_Position = vec4(0.0); }', .vertex,
		'unsupported directive')
	expect_shader_error('uniform float u; void main() { gl_FragColor = texture2D(u, u); }',
		.fragment, 'samplers are not supported')
}

fn test_rejects_forward_calls_and_missing_main() {
	expect_shader_error('void main() { gl_Position = f(); } vec4 f() { return vec4(0.0); }',
		.vertex, 'must be defined before it is called')
	expect_shader_error('float helper() { return 1.0; }', .vertex, 'no main function')
	expect_shader_error('void main(float x) { gl_Position = vec4(x); }', .vertex, 'main must be declared')
}

fn test_rejects_bad_swizzles_and_break_outside_loops() {
	expect_shader_error('void main() { vec2 v = vec2(1.0); gl_Position = vec4(v.z); }', .vertex,
		'out of range')
	expect_shader_error('void main() { vec2 v = vec2(1.0); gl_Position = vec4(v.xg, 0.0, 1.0); }',
		.vertex, 'not a valid swizzle')
	expect_shader_error('void main() { break; }', .vertex, 'only valid inside a loop')
}

fn test_link_rejects_fragment_varying_without_vertex_match() {
	vs := parse_checked('attribute vec2 a; varying vec2 v; void main() { v = a; gl_Position = vec4(a, 0.0, 1.0); }',
		.vertex)
	missing := parse_checked('varying vec2 w; void main() { gl_FragColor = vec4(w, 0.0, 1.0); }',
		.fragment)
	plan_link(&vs, &missing) or {
		assert err.msg().contains('not declared in the vertex shader')
		return
	}
	assert false, 'a fragment varying without a vertex match must not link'
}

fn test_link_rejects_varying_type_mismatch() {
	vs := parse_checked('attribute vec2 a; varying vec2 v; void main() { v = a; gl_Position = vec4(a, 0.0, 1.0); }',
		.vertex)
	wrong := parse_checked('varying vec3 v; void main() { gl_FragColor = vec4(v, 1.0); }', .fragment)
	plan_link(&vs, &wrong) or {
		assert err.msg().contains('different types')
		return
	}
	assert false, 'varying types must agree'
}

fn test_link_rejects_matrix_attributes() {
	vs := parse_checked('attribute mat2 m; void main() { gl_Position = vec4(m * vec2(1.0), 0.0, 1.0); }',
		.vertex)
	fs := parse_checked('void main() { gl_FragColor = vec4(1.0); }', .fragment)
	plan_link(&vs, &fs) or {
		assert err.msg().contains('matrix attribute')
		return
	}
	assert false, 'matrix attributes are not supported yet'
}

fn test_link_rejects_uniform_type_conflicts() {
	vs := parse_checked('uniform vec2 u; void main() { gl_Position = vec4(u, 0.0, 1.0); }', .vertex)
	fs := parse_checked('uniform vec3 u; void main() { gl_FragColor = vec4(u, 1.0); }', .fragment)
	plan_link(&vs, &fs) or {
		assert err.msg().contains('different types')
		return
	}
	assert false, 'uniform types must agree across stages'
}

fn test_pack_floats_pads_vec3_and_matrix_columns() {
	v3 := pack_floats(.vec3, [f32(1), 2, 3])
	assert v3.len == 16
	assert v3[8..12] == f32_bytes_of([f32(3)])
	assert v3[12..16] == []u8{len: 4}
	m3 := pack_floats(.mat3, []f32{len: 9, init: f32(index)})
	assert m3.len == 48
	assert m3[16..20] == f32_bytes_of([f32(3)])
	m2 := pack_floats(.mat2, [f32(1), 2, 3, 4])
	assert m2.len == 16
	assert m2[8..12] == f32_bytes_of([f32(3)])
}
