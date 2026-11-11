// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

import strings

// LinkVar is a linked attribute, varying, or uniform with its slot.
pub struct LinkVar {
pub:
	name string
	ty   Ty
	loc  int
}

// Layout fixes the slots a stage uses: attribute and varying locations and
// uniform buffer indices. Both stages of a program share the uniform indices.
pub struct Layout {
pub:
	attrs    []LinkVar
	varyings []LinkVar
	uniforms []LinkVar
}

const msl_prelude = '#include <metal_stdlib>
using namespace metal;
template <typename T> T glsl_mod(T x, T y) { return x - y * floor(x / y); }
struct Sampler2D { texture2d<float> t; sampler s; };
'

// Emitter writes one checked stage as Metal Shading Language. GLSL main
// becomes f_main, a helper that receives the stage's inputs, outputs, and
// uniforms explicitly; the entry point wraps it with the Metal signature.
struct Emitter {
	stage  Stage
	layout Layout
	funcs  map[string]bool
mut:
	out strings.Builder
}

// emit_msl translates a checked unit to MSL source for one stage.
pub fn emit_msl(unit &Unit, stage Stage, layout Layout) string {
	mut funcs := map[string]bool{}
	for f in unit.funcs {
		funcs[f.name] = true
	}
	mut em := Emitter{
		stage:  stage
		layout: layout
		funcs:  funcs
		out:    strings.new_builder(4096)
	}
	em.out.write_string(msl_prelude)
	em.write_io_structs()
	for f in unit.funcs {
		em.write_function(f)
	}
	em.write_entry()
	return em.out.str()
}

fn (em &Emitter) in_type() string {
	return if em.stage == .vertex { 'VS_In' } else { 'FS_In' }
}

fn (em &Emitter) out_type() string {
	return if em.stage == .vertex { 'VS_Out' } else { 'FS_Out' }
}

fn (mut em Emitter) write_io_structs() {
	if em.stage == .vertex {
		em.out.write_string('struct VS_In {\n')
		for a in em.layout.attrs {
			em.out.write_string('\t${a.ty.msl()} a_${a.name} [[attribute(${a.loc})]];\n')
		}
		em.out.write_string('};\nstruct VS_Out {\n\tfloat4 position [[position]];\n')
		for v in em.layout.varyings {
			em.out.write_string('\t${v.ty.msl()} v_${v.name} [[user(locn${v.loc})]];\n')
		}
		em.out.write_string('};\n')
		return
	}
	em.out.write_string('struct FS_In {\n')
	for v in em.layout.varyings {
		em.out.write_string('\t${v.ty.msl()} v_${v.name} [[user(locn${v.loc})]];\n')
	}
	em.out.write_string('};\nstruct FS_Out {\n\tfloat4 color [[color(0)]];\n};\n')
}

// ctx_params is the parameter list every stage function shares.
fn (em &Emitter) ctx_params() string {
	mut s := 'thread ${em.in_type()} &_in, thread ${em.out_type()} &_out'
	for u in em.layout.uniforms {
		if u.ty == .sampler2d {
			s += ', thread Sampler2D &u_${u.name}'
		} else {
			s += ', constant ${u.ty.msl()} &u_${u.name}'
		}
	}
	return s
}

// ctx_args are the arguments that pass the shared context along.
fn (em &Emitter) ctx_args() string {
	mut s := '_in, _out'
	for u in em.layout.uniforms {
		s += ', u_${u.name}'
	}
	return s
}

fn (mut em Emitter) write_function(f Func) {
	mut params := []string{}
	for p in f.params {
		params << '${p.ty.msl()} l_${p.name}'
	}
	mut sig := ''
	if f.name == 'main' {
		sig = 'void f_main(${em.ctx_params()})'
	} else {
		mut all := []string{}
		all << em.ctx_params()
		all << params
		joined := all.join(', ')
		sig = '${f.ret.msl()} f_${f.name}(${joined})'
	}
	em.out.write_string('${sig} {\n')
	for s in f.body {
		em.stmt(s, 1)
	}
	em.out.write_string('}\n')
}

// write_entry emits the Metal entry point. The vertex wrapper also remaps
// clip z from GL's [-w, w] to Metal's [0, w]. It flips Y: GL
// window row 0 is the bottom, while Metal's row 0 is the top of the texture,
// so readback in memory order matches glReadPixels only after the flip.
fn (mut em Emitter) write_entry() {
	mut uparams := ''
	mut uargs := ''
	mut setup := ''
	for u in em.layout.uniforms {
		if u.ty == .sampler2d {
			// A sampler uniform is a texture plus a sampler state at the
			// uniform's slot; the struct is rebuilt so helpers take one value.
			uparams += ', texture2d<float> t_${u.name} [[texture(${u.loc})]], sampler s_${u.name} [[sampler(${u.loc})]]'
			setup += '\tSampler2D u_${u.name}{t_${u.name}, s_${u.name}};\n'
		} else {
			uparams += ', constant ${u.ty.msl()} &u_${u.name} [[buffer(${u.loc})]]'
		}
		uargs += ', u_${u.name}'
	}
	if em.stage == .vertex {
		em.out.write_string('vertex VS_Out vs_entry(VS_In _in [[stage_in]]${uparams}) {\n')
		em.out.write_string('\tVS_Out _out{};\n\tf_main(_in, _out${uargs});\n')
		em.out.write_string('\t_out.position.y = -_out.position.y;\n')
		// GL clip z spans [-w, w]; Metal's spans [0, w].
		em.out.write_string('\t_out.position.z = (_out.position.z + _out.position.w) * 0.5;\n\treturn _out;\n}\n')
		return
	}
	em.out.write_string('fragment FS_Out fs_entry(FS_In _in [[stage_in]]${uparams}) {\n')
	em.out.write_string('${setup}\tFS_Out _out{};\n\tf_main(_in, _out${uargs});\n\treturn _out;\n}\n')
}

fn (mut em Emitter) stmt(s Stmt, depth int) {
	pad := '\t'.repeat(depth)
	match s.kind {
		.decl_s {
			em.out.write_string('${pad}${em.decl_text(s)};\n')
		}
		.assign_s {
			em.out.write_string('${pad}${em.assign_text(s)};\n')
		}
		.expr_s {
			em.out.write_string('${pad}${em.expr(s.rhs)};\n')
		}
		.ret_s {
			if isnil(s.rhs) {
				em.out.write_string('${pad}return;\n')
			} else {
				em.out.write_string('${pad}return ${em.expr(s.rhs)};\n')
			}
		}
		.if_s {
			em.out.write_string('${pad}if (${em.expr(s.cond)}) {\n')
			for b in s.body {
				em.stmt(b, depth + 1)
			}
			if s.alt.len > 0 {
				em.out.write_string('${pad}} else {\n')
				for b in s.alt {
					em.stmt(b, depth + 1)
				}
			}
			em.out.write_string('${pad}}\n')
		}
		.for_s {
			mut init := ''
			if s.for_init.len > 0 {
				init = em.decl_text(s.for_init[0])
			}
			mut cond := ''
			if !isnil(s.cond) {
				cond = em.expr(s.cond)
			}
			mut step := ''
			if s.for_step.len > 0 {
				step = em.assign_text(s.for_step[0])
			}
			em.out.write_string('${pad}for (${init}; ${cond}; ${step}) {\n')
			for b in s.body {
				em.stmt(b, depth + 1)
			}
			em.out.write_string('${pad}}\n')
		}
		.block_s {
			em.out.write_string('${pad}{\n')
			for b in s.body {
				em.stmt(b, depth + 1)
			}
			em.out.write_string('${pad}}\n')
		}
		.break_s {
			em.out.write_string('${pad}break;\n')
		}
		.cont_s {
			em.out.write_string('${pad}continue;\n')
		}
	}
}

// decl_text declares a local with a zero value when it has no initializer.
fn (em &Emitter) decl_text(s Stmt) string {
	if isnil(s.rhs) {
		return '${s.ty.msl()} l_${s.name}{}'
	}
	return '${s.ty.msl()} l_${s.name} = ${em.expr(s.rhs)}'
}

// assign_text emits an assignment. Compound forms expand to plain assignment
// so that a lone ++ or compound operator needs no special MSL support.
fn (em &Emitter) assign_text(s Stmt) string {
	lhs := em.expr(s.lhs)
	if s.op == '++' || s.op == '--' {
		return '${lhs}${s.op}'
	}
	rhs := em.expr(s.rhs)
	if s.op == '=' {
		return '${lhs} = ${rhs}'
	}
	binop := s.op[..1]
	return '${lhs} = (${lhs}) ${binop} (${rhs})'
}

fn (em &Emitter) expr(e &Expr) string {
	match e.kind {
		.lit {
			if e.lit_type == 'float' {
				return msl_float_lit(e.text)
			}
			return e.text
		}
		.ident {
			return em.ident(e)
		}
		.unary {
			operand := em.expr(e.args[0])
			return '(${e.text}${operand})'
		}
		.binary {
			a := em.expr(e.args[0])
			b := em.expr(e.args[1])
			// GLSL == on vectors yields one bool; MSL yields a vector of bools.
			if e.text == '==' && e.args[0].ty.vec_len() > 0 {
				return 'all(${a} == ${b})'
			}
			if e.text == '!=' && e.args[0].ty.vec_len() > 0 {
				return 'any(${a} != ${b})'
			}
			return '(${a} ${e.text} ${b})'
		}
		.ternary {
			cond := em.expr(e.args[0])
			then_val := em.expr(e.args[1])
			else_val := em.expr(e.args[2])
			return '((${cond}) ? (${then_val}) : (${else_val}))'
		}
		.call {
			return em.call(e)
		}
		.field {
			base := em.expr(e.args[0])
			swz := msl_swizzle(e.text)
			return '(${base}).${swz}'
		}
	}
}

fn (em &Emitter) ident(e &Expr) string {
	return match e.storage {
		.local_s { 'l_${e.text}' }
		.uniform_s { 'u_${e.text}' }
		.attr_s { '_in.a_${e.text}' }
		.varying_s {
			if em.stage == .vertex {
				'_out.v_${e.text}'
			} else {
				'_in.v_${e.text}'
			}
		}
		.position_s { '_out.position' }
		.frag_color_s { '_out.color' }
		.unset_s { e.text }
	}
}

fn (em &Emitter) call(e &Expr) string {
	mut args := []string{}
	for a in e.args {
		args << em.expr(a)
	}
	if target := ty_from_name(e.text) {
		joined := args.join(', ')
		return '${target.msl()}(${joined})'
	}
	if e.text in em.funcs {
		mut all := []string{}
		all << em.ctx_args()
		all << args
		joined := all.join(', ')
		return 'f_${e.text}(${joined})'
	}
	if e.text == 'texture2D' {
		return '(${args[0]}.t.sample(${args[0]}.s, ${args[1]}))'
	}
	name := match e.text {
		'mod' { 'glsl_mod' }
		'inversesqrt' { 'rsqrt' }
		'atan' { if args.len == 2 { 'atan2' } else { 'atan' } }
		else { e.text }
	}
	joined := args.join(', ')
	return '${name}(${joined})'
}

// msl_float_lit makes GLSL float spellings such as .5 and 2. valid in MSL.
fn msl_float_lit(text string) string {
	mut s := text
	if s.starts_with('.') {
		s = '0' + s
	}
	if s.ends_with('.') {
		s += '0'
	}
	return s
}

// msl_swizzle maps stpq names onto the xyzw names MSL spells.
fn msl_swizzle(s string) string {
	mut out := ''
	for ch in s {
		out += match ch {
			`x`, `r`, `s` { 'x' }
			`y`, `g`, `t` { 'y' }
			`z`, `b`, `p` { 'z' }
			else { 'w' }
		}
	}
	return out
}
