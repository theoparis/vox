// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Ty is a GLSL ES 1.00 type in the supported subset. sampler2D exists only as a
// fragment-stage uniform; arrays, structs, and integer vectors are not part of it yet.
pub enum Ty {
	void_t
	bool_t
	int_t
	float_t
	vec2
	vec3
	vec4
	mat2
	mat3
	mat4
	sampler2d
}

pub fn ty_from_name(s string) ?Ty {
	match s {
		'void' { return .void_t }
		'bool' { return .bool_t }
		'int' { return .int_t }
		'float' { return .float_t }
		'vec2' { return .vec2 }
		'vec3' { return .vec3 }
		'vec4' { return .vec4 }
		'mat2' { return .mat2 }
		'mat3' { return .mat3 }
		'mat4' { return .mat4 }
		'sampler2D' { return .sampler2d }
		else {}
	}
	return none
}

// msl is the Metal Shading Language spelling of the type.
pub fn (t Ty) msl() string {
	return match t {
		.void_t { 'void' }
		.bool_t { 'bool' }
		.int_t { 'int' }
		.float_t { 'float' }
		.vec2 { 'float2' }
		.vec3 { 'float3' }
		.vec4 { 'float4' }
		.mat2 { 'float2x2' }
		.mat3 { 'float3x3' }
		.mat4 { 'float4x4' }
		.sampler2d { 'Sampler2D' }
	}
}

// comps is the number of scalar components a value of the type holds.
pub fn (t Ty) comps() int {
	return match t {
		.void_t { 0 }
		.bool_t, .int_t, .float_t, .sampler2d { 1 }
		.vec2 { 2 }
		.vec3 { 3 }
		.vec4 { 4 }
		.mat2 { 4 }
		.mat3 { 9 }
		.mat4 { 16 }
	}
}

pub fn (t Ty) vec_len() int {
	return match t {
		.vec2 { 2 }
		.vec3 { 3 }
		.vec4 { 4 }
		else { 0 }
	}
}

pub fn (t Ty) mat_n() int {
	return match t {
		.mat2 { 2 }
		.mat3 { 3 }
		.mat4 { 4 }
		else { 0 }
	}
}

pub fn (t Ty) is_scalar() bool {
	return t == .bool_t || t == .int_t || t == .float_t
}

// is_float_based covers float scalars, float vectors, and float matrices.
pub fn (t Ty) is_float_based() bool {
	return t == .float_t || t.vec_len() > 0 || t.mat_n() > 0
}

// is_gen covers the GLSL genType family: float and float vectors.
pub fn (t Ty) is_gen() bool {
	return t == .float_t || t.vec_len() > 0
}

// msl_size is the byte size of the type inside a Metal constant buffer, as
// setBytes lays it out. A float3 occupies 16 bytes; float3x3 uses 16-byte columns.
pub fn (t Ty) msl_size() int {
	return match t {
		.void_t { 0 }
		.bool_t, .int_t, .float_t, .sampler2d { 4 }
		.vec2 { 8 }
		.vec3, .vec4 { 16 }
		.mat2 { 16 }
		.mat3 { 48 }
		.mat4 { 64 }
	}
}

// Storage records what a resolved identifier names, so the emitter can
// route it to the right place in the generated stage functions.
pub enum Storage {
	unset_s
	local_s
	uniform_s
	attr_s
	varying_s
	position_s
	frag_color_s
}

pub enum ExprKind {
	lit
	ident
	unary
	binary
	ternary
	call
	field
}

// Expr is an expression node. The checker fills ty and storage.
pub struct Expr {
pub mut:
	kind     ExprKind
	text     string // literal text, identifier, operator, callee, or swizzle
	lit_type string // float, int, or bool for lit nodes
	args     []&Expr
	ty       Ty
	storage  Storage = .unset_s
	line     int
}

pub enum StmtKind {
	decl_s
	assign_s
	expr_s
	ret_s
	if_s
	for_s
	block_s
	break_s
	cont_s
}

// Stmt is a statement node. Field use depends on kind; see the parser.
pub struct Stmt {
pub mut:
	kind     StmtKind
	name     string // declared name
	op       string // assignment operator, or ++ / --
	ty       Ty     // declared type
	lhs      &Expr = unsafe { nil }
	rhs      &Expr = unsafe { nil }
	cond     &Expr = unsafe { nil }
	body     []Stmt
	alt      []Stmt
	for_init []Stmt
	for_step []Stmt
	line     int
}

pub struct Param {
pub:
	name string
	ty   Ty
}

pub struct Func {
pub mut:
	name   string
	ret    Ty
	params []Param
	body   []Stmt
	line   int
}

pub enum Qual {
	none_q
	attribute
	varying
	uniform
}

pub struct Global {
pub:
	name string
	qual Qual
	ty   Ty
	line int
}

// Unit is one parsed and (after check_unit) checked shader.
pub struct Unit {
pub mut:
	globals []Global
	funcs   []Func
	used    map[string]bool // global names referenced by the stage
}

fn no_expr() &Expr {
	return unsafe { nil }
}
