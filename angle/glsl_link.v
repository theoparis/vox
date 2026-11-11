// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Limits of the Metal translation. Metal binds 31 vertex buffers and 31
// user varyings; GLES 2 requires at least 16 attributes and varyings.
pub const max_attribs = 16
pub const max_uniforms = 16
pub const max_varyings = 16

// LinkPlan is the slot assignment shared by both stages of a program.
pub struct LinkPlan {
pub:
	vs_layout Layout
	fs_layout Layout
	uniforms  []LinkVar
}

// plan_link assigns attribute locations, varying locations, and uniform
// buffer indices, and checks that the two stages agree on their interface.
// It is pure, so it is tested without a GPU.
pub fn plan_link(vs &Unit, fs &Unit) !LinkPlan {
	return plan_link_with(vs, fs, map[string]int{})
}

// plan_link_with is plan_link honoring glBindAttribLocation requests. An
// active attribute with a request takes that slot; the rest fill the free
// slots in declaration order. Two active attributes may not share a slot.
pub fn plan_link_with(vs &Unit, fs &Unit, bindings map[string]int) !LinkPlan {
	mut active := []Global{}
	for g in vs.globals {
		if g.qual != .attribute || g.name !in vs.used {
			continue
		}
		if g.ty.mat_n() > 0 {
			return error('matrix attribute "${g.name}" is not supported yet')
		}
		if active.len == max_attribs {
			return error('the vertex shader uses more than ${max_attribs} attributes')
		}
		active << g
	}
	mut taken := map[int]string{}
	mut slot_of := map[string]int{}
	for g in active {
		if g.name in bindings {
			slot := bindings[g.name]
			if slot in taken {
				return error('attributes "${taken[slot]}" and "${g.name}" are bound to location ${slot}')
			}
			taken[slot] = g.name
			slot_of[g.name] = slot
		}
	}
	mut next_free := 0
	for g in active {
		if g.name in slot_of {
			continue
		}
		for {
			if next_free !in taken {
				break
			}
			next_free++
		}
		taken[next_free] = g.name
		slot_of[g.name] = next_free
	}
	mut attrs := []LinkVar{}
	for g in active {
		attrs << LinkVar{
			name: g.name
			ty:   g.ty
			loc:  slot_of[g.name]
		}
	}

	mut vs_vary := []Global{}
	for g in vs.globals {
		if g.qual == .varying {
			vs_vary << g
		}
	}
	// Fragment varyings take the first locations, in fragment declaration
	// order; vertex-only varyings follow.
	mut loc := 0
	mut fs_locs := map[string]int{}
	mut fs_out := []LinkVar{}
	for g in fs.globals {
		if g.qual != .varying {
			continue
		}
		mut found := false
		mut src_ty := Ty.void_t
		for v in vs_vary {
			if v.name == g.name {
				found = true
				src_ty = v.ty
			}
		}
		if !found {
			return error('fragment varying "${g.name}" is not declared in the vertex shader')
		}
		if src_ty != g.ty {
			return error('varying "${g.name}" has different types in the two shaders')
		}
		fs_locs[g.name] = loc
		fs_out << LinkVar{
			name: g.name
			ty:   g.ty
			loc:  loc
		}
		loc++
	}
	mut vs_out := []LinkVar{}
	for g in vs_vary {
		mut vloc := 0
		if g.name in fs_locs {
			vloc = fs_locs[g.name]
		} else {
			vloc = loc
			loc++
		}
		vs_out << LinkVar{
			name: g.name
			ty:   g.ty
			loc:  vloc
		}
	}
	if loc > max_varyings {
		return error('the program uses more than ${max_varyings} varyings')
	}

	mut uniforms := []LinkVar{}
	for g in vs.globals {
		if g.qual == .uniform && g.name in vs.used {
			uniforms << LinkVar{
				name: g.name
				ty:   g.ty
				loc:  uniforms.len
			}
		}
	}
	for g in fs.globals {
		if g.qual != .uniform {
			continue
		}
		mut known := false
		for u in uniforms {
			if u.name == g.name {
				known = true
				if u.ty != g.ty {
					return error('uniform "${g.name}" has different types in the two shaders')
				}
			}
		}
		if known || g.name !in fs.used {
			continue
		}
		uniforms << LinkVar{
			name: g.name
			ty:   g.ty
			loc:  uniforms.len
		}
	}
	for g in vs.globals {
		if g.qual != .uniform {
			continue
		}
		for f in fs.globals {
			if f.qual == .uniform && f.name == g.name && f.ty != g.ty {
				return error('uniform "${g.name}" has different types in the two shaders')
			}
		}
	}
	if uniforms.len > max_uniforms {
		return error('the program uses more than ${max_uniforms} uniforms')
	}
	// Samplers exist only in the fragment stage; the vertex stage keeps their
	// uniform slots free so both stages share one numbering.
	mut vs_uniforms := []LinkVar{}
	for u in uniforms {
		if u.ty != .sampler2d {
			vs_uniforms << u
		}
	}
	return LinkPlan{
		vs_layout: Layout{
			attrs:    attrs
			varyings: vs_out
			uniforms: vs_uniforms
		}
		fs_layout: Layout{
			varyings: fs_out
			uniforms: uniforms
		}
		uniforms:  uniforms
	}
}

// ShaderKind is the GL shader type.
pub enum ShaderKind {
	vertex
	fragment
}

// Shader is a GLES shader object. Compiling parses and checks the source for
// its stage; the Metal library is built at link time, once both stages exist.
pub struct Shader {
pub:
	kind ShaderKind
pub mut:
	source string
	unit   Unit
	ok     bool
	log    string
	// deleted marks a shader that glDeleteShader released while still attached.
	deleted bool
}

pub fn (mut s Shader) compile() {
	stage := if s.kind == .vertex { Stage.vertex } else { Stage.fragment }
	mut unit := glsl_parse(s.source) or {
		s.ok = false
		s.log = err.msg()
		return
	}
	check_unit(mut unit, stage) or {
		s.ok = false
		s.log = err.msg()
		return
	}
	s.unit = unit
	s.ok = true
	s.log = ''
}

// Program is a GLES program object after a successful link.
pub struct Program {
pub mut:
	vertex       u32
	fragment     u32
	linked       bool
	log          string
	attrs        []LinkVar
	uniforms     []LinkVar
	uniform_data [][]u8
	vs_lib       u32
	fs_lib       u32
	pipelines    map[string]u32
	// deleted marks a program that glDeleteProgram released while current.
	deleted bool
	// validated is the VALIDATE_STATUS set by glValidateProgram.
	validated bool
	// bound_attribs holds glBindAttribLocation requests, applied at link.
	bound_attribs map[string]int
}
