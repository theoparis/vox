// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Stage selects the shader stage whose rules a unit is checked against.
pub enum Stage {
	vertex
	fragment
}

struct Sym {
	ty      Ty
	storage Storage
}

struct FuncSig {
	ret    Ty
	params []Ty
}

// Checker resolves names and types. GLSL has no implicit conversions, so
// every operator and call must match exactly.
struct Checker {
mut:
	stage   Stage
	globals map[string]Sym
	funcs   map[string]FuncSig
	done    map[string]bool // functions whose bodies are already checked
	scopes  []map[string]Sym
	ret     Ty
	loops   int
	used    map[string]bool
}

// check_unit validates one parsed unit for a stage, fills in each expression's
// type and storage, and records the global names the unit references.
pub fn check_unit(mut unit Unit, stage Stage) ! {
	mut c := Checker{
		stage:   stage
		globals: map[string]Sym{}
		funcs:   map[string]FuncSig{}
		done:    map[string]bool{}
		used:    map[string]bool{}
	}
	for g in unit.globals {
		if g.name in c.globals {
			return error('line ${g.line}: "${g.name}" is declared twice')
		}
		if !g.ty.is_float_based() && g.qual != .uniform {
			return error('line ${g.line}: "${g.name}" must be a float, vector, or matrix')
		}
		storage := match g.qual {
			.attribute {
				if stage == .fragment {
					return error('line ${g.line}: attributes are only available in vertex shaders')
				}
				Storage.attr_s
			}
			.varying {
				Storage.varying_s
			}
			.uniform {
				if g.ty == .bool_t {
					return error('line ${g.line}: bool uniforms are not supported')
				}
				if g.ty == .sampler2d && stage == .vertex {
					return error('line ${g.line}: samplers are not supported in vertex shaders')
				}
				Storage.uniform_s
			}
			.none_q {
				return error('line ${g.line}: "${g.name}" needs a storage qualifier')
			}
		}
		c.globals[g.name] = Sym{
			ty:      g.ty
			storage: storage
		}
	}
	if stage == .vertex {
		c.globals['gl_Position'] = Sym{
			ty:      .vec4
			storage: .position_s
		}
	} else {
		c.globals['gl_FragColor'] = Sym{
			ty:      .vec4
			storage: .frag_color_s
		}
	}
	mut main_found := false
	for f in unit.funcs {
		if f.name in c.funcs {
			return error('line ${f.line}: function "${f.name}" is declared twice')
		}
		if f.ret == .sampler2d {
			return error('line ${f.line}: functions cannot return samplers')
		}
		if f.name == 'main' {
			main_found = true
			if f.ret != .void_t || f.params.len != 0 {
				return error('line ${f.line}: main must be declared as void main()')
			}
		}
		mut ptys := []Ty{}
		for p in f.params {
			ptys << p.ty
		}
		c.funcs[f.name] = FuncSig{
			ret:    f.ret
			params: ptys
		}
	}
	if !main_found {
		return error('the shader has no main function')
	}
	for f in unit.funcs {
		c.check_func(f)!
		c.done[f.name] = true
	}
	unit.used = c.used.clone()
}

fn (mut c Checker) check_func(f Func) ! {
	c.ret = f.ret
	c.scopes = [map[string]Sym{}]
	for p in f.params {
		if p.ty == .void_t {
			return error('line ${f.line}: parameter "${p.name}" cannot be void')
		}
		if p.ty == .sampler2d {
			return error('line ${f.line}: sampler parameters are not supported')
		}
		if p.name in c.scopes[0] {
			return error('line ${f.line}: parameter "${p.name}" is declared twice')
		}
		c.scopes[0][p.name] = Sym{
			ty:      p.ty
			storage: .local_s
		}
	}
	c.stmts(f.body)!
	c.scopes = []
}

fn (c &Checker) resolve(name string) ?Sym {
	for i := c.scopes.len - 1; i >= 0; i-- {
		if name in c.scopes[i] {
			return c.scopes[i][name]
		}
	}
	if name in c.globals {
		return c.globals[name]
	}
	return none
}

fn (mut c Checker) push() {
	c.scopes << map[string]Sym{}
}

fn (mut c Checker) pop() {
	c.scopes.delete_last()
}

fn (mut c Checker) stmts(list []Stmt) ! {
	for s in list {
		c.stmt(s)!
	}
}

fn (mut c Checker) stmt(s Stmt) ! {
	match s.kind {
		.decl_s {
			if s.ty == .sampler2d {
				return error('line ${s.line}: sampler variables must be uniforms')
			}
			if s.name in c.scopes[c.scopes.len - 1] {
				return error('line ${s.line}: "${s.name}" is declared twice in one scope')
			}
			if !isnil(s.rhs) {
				t := c.expr(s.rhs)!
				if t != s.ty {
					return error('line ${s.line}: cannot initialize ${s.ty.msl()} with ${t.msl()}')
				}
			}
			c.scopes[c.scopes.len - 1][s.name] = Sym{
				ty:      s.ty
				storage: .local_s
			}
		}
		.assign_s {
			lt := c.expr(s.lhs)!
			c.assignable(s.lhs)!
			if s.op == '++' || s.op == '--' {
				if lt != .int_t && lt != .float_t {
					return error('line ${s.line}: ${s.op} needs an int or float variable')
				}
				return
			}
			rt := c.expr(s.rhs)!
			if s.op == '=' {
				if lt != rt {
					return error('line ${s.line}: cannot assign ${rt.msl()} to ${lt.msl()}')
				}
			} else {
				res := binop_type(s.op[..1], lt, rt) or {
					return error('line ${s.line}: "${s.op}" does not apply to ${lt.msl()} and ${rt.msl()}')
				}
				if res != lt {
					return error('line ${s.line}: "${s.op}" changes the type of ${lt.msl()}')
				}
			}
		}
		.expr_s {
			c.expr(s.rhs)!
		}
		.ret_s {
			if isnil(s.rhs) {
				if c.ret != .void_t {
					return error('line ${s.line}: return needs a value of type ${c.ret.msl()}')
				}
				return
			}
			t := c.expr(s.rhs)!
			if t != c.ret {
				return error('line ${s.line}: return type ${t.msl()} does not match ${c.ret.msl()}')
			}
		}
		.if_s {
			if c.expr(s.cond)! != .bool_t {
				return error('line ${s.line}: if condition must be bool')
			}
			c.push()
			c.stmts(s.body)!
			c.pop()
			c.push()
			c.stmts(s.alt)!
			c.pop()
		}
		.for_s {
			c.push()
			for init in s.for_init {
				c.stmt(init)!
			}
			if !isnil(s.cond) && c.expr(s.cond)! != .bool_t {
				return error('line ${s.line}: for condition must be bool')
			}
			for step in s.for_step {
				c.stmt(step)!
			}
			c.loops++
			c.push()
			c.stmts(s.body)!
			c.pop()
			c.loops--
			c.pop()
		}
		.block_s {
			c.push()
			c.stmts(s.body)!
			c.pop()
		}
		.break_s, .cont_s {
			if c.loops == 0 {
				return error('line ${s.line}: break and continue are only valid inside a loop')
			}
		}
	}
}

// assignable accepts local variables, the stage's output, and swizzles of
// them. Attributes, uniforms, and fragment varyings are read-only.
fn (mut c Checker) assignable(e &Expr) ! {
	match e.kind {
		.ident {
			match e.storage {
				.local_s {}
				.position_s {}
				.frag_color_s {}
				.varying_s {
					if c.stage == .fragment {
						return error('line ${e.line}: "${e.text}" is read-only in a fragment shader')
					}
				}
				.uniform_s {
					return error('line ${e.line}: uniform "${e.text}" cannot be assigned')
				}
				.attr_s {
					return error('line ${e.line}: attribute "${e.text}" cannot be assigned')
				}
				.unset_s {
					return error('line ${e.line}: "${e.text}" is not assignable')
				}
			}
		}
		.field {
			c.assignable(e.args[0])!
			if _ := swizzle_indices(e.text) {
				mut seen := map[int]bool{}
				for idx in swizzle_indices(e.text) or { []int{} } {
					if seen[idx] {
						return error('line ${e.line}: swizzle "${e.text}" repeats a component')
					}
					seen[idx] = true
				}
			}
		}
		else {
			return error('line ${e.line}: the left side of an assignment must be a variable')
		}
	}
}

// expr checks an expression, records its type on the node, and returns it.
fn (mut c Checker) expr(e &Expr) !Ty {
	t := c.expr_type(e)!
	// The checker annotates the AST nodes it was handed; they are not shared.
	unsafe {
		e.ty = t
	}
	return t
}

fn (mut c Checker) expr_type(e &Expr) !Ty {
	match e.kind {
		.lit {
			return match e.lit_type {
				'float' { Ty.float_t }
				'int' { Ty.int_t }
				else { Ty.bool_t }
			}
		}
		.ident {
			sym := c.resolve(e.text) or {
				return error('line ${e.line}: undeclared identifier "${e.text}"')
			}
			unsafe {
				e.storage = sym.storage
			}
			c.used[e.text] = true
			return sym.ty
		}
		.unary {
			t := c.expr(e.args[0])!
			if e.text == '!' {
				if t != .bool_t {
					return error('line ${e.line}: "!" needs a bool operand')
				}
				return t
			}
			if t == .bool_t || t == .void_t || t == .sampler2d {
				return error('line ${e.line}: "${e.text}" needs a numeric operand')
			}
			return t
		}
		.binary {
			a := c.expr(e.args[0])!
			b := c.expr(e.args[1])!
			if (e.text == '==' || e.text == '!=') && a.mat_n() > 0 {
				return error('line ${e.line}: matrices cannot be compared with "${e.text}"')
			}
			return binop_type(e.text, a, b) or {
				error('line ${e.line}: "${e.text}" does not apply to ${a.msl()} and ${b.msl()}')
			}
		}
		.ternary {
			if c.expr(e.args[0])! != .bool_t {
				return error('line ${e.line}: the condition of ?: must be bool')
			}
			a := c.expr(e.args[1])!
			b := c.expr(e.args[2])!
			if a != b {
				return error('line ${e.line}: ?: branches have types ${a.msl()} and ${b.msl()}')
			}
			return a
		}
		.call {
			mut tys := []Ty{}
			for a in e.args {
				tys << c.expr(a)!
			}
			if target := ty_from_name(e.text) {
				if target == .sampler2d {
					return error('line ${e.line}: samplers cannot be constructed')
				}
				if !ctor_ok(target, tys) {
					return error('line ${e.line}: no constructor ${target.msl()} takes these arguments')
				}
				return target
			}
			if e.text in c.funcs {
				if e.text !in c.done {
					return error('line ${e.line}: "${e.text}" must be defined before it is called, and recursion is not allowed')
				}
				sig := c.funcs[e.text]
				if sig.params.len != tys.len {
					return error('line ${e.line}: "${e.text}" takes ${sig.params.len} arguments')
				}
				for i, pt in sig.params {
					if pt != tys[i] {
						return error('line ${e.line}: argument ${i + 1} of "${e.text}" must be ${pt.msl()}')
					}
				}
				return sig.ret
			}
			if e.text == 'texture2D' {
				if c.stage == .vertex {
					return error('line ${e.line}: texture2D is only available in fragment shaders')
				}
				if tys.len != 2 || tys[0] != .sampler2d || tys[1] != .vec2 {
					return error('line ${e.line}: texture2D takes a sampler2D and a vec2')
				}
				return Ty.vec4
			}
			return builtin_type(e.text, tys) or {
				error('line ${e.line}: no function "${e.text}" matches these arguments')
			}
		}
		.field {
			base := c.expr(e.args[0])!
			n := base.vec_len()
			if n == 0 {
				return error('line ${e.line}: "." needs a vector, not ${base.msl()}')
			}
			idx := swizzle_indices(e.text) or {
				return error('line ${e.line}: "${e.text}" is not a valid swizzle')
			}
			for i in idx {
				if i >= n {
					return error('line ${e.line}: swizzle "${e.text}" is out of range for ${base.msl()}')
				}
			}
			return match idx.len {
				1 { Ty.float_t }
				2 { Ty.vec2 }
				3 { Ty.vec3 }
				else { Ty.vec4 }
			}
		}
	}
}

// swizzle_indices maps xyzw, rgba, or stpq component names to indices. A
// swizzle must draw all its letters from one set.
fn swizzle_indices(s string) ?[]int {
	if s.len == 0 || s.len > 4 {
		return none
	}
	sets := ['xyzw', 'rgba', 'stpq']
	mut out := []int{}
	for set in sets {
		if s[0] in set.bytes() {
			for ch in s.bytes() {
				pos := set.index_u8(ch)
				if pos < 0 {
					return none
				}
				out << pos
			}
			return out
		}
	}
	return none
}

// ctor_ok applies GLSL's constructor rules. Scalars take one argument; vectors
// and matrices take one scalar or enough components across their arguments.
fn ctor_ok(target Ty, args []Ty) bool {
	if args.len == 0 || args.any(it == .void_t) {
		return false
	}
	if target.is_scalar() {
		return args.len == 1
	}
	if args.len == 1 {
		a := args[0]
		if a.is_scalar() {
			return true
		}
		if target.mat_n() > 0 {
			return a == target
		}
		return a.vec_len() >= target.vec_len()
	}
	mut total := 0
	for a in args {
		if a.mat_n() > 0 {
			return false
		}
		total += if a.is_scalar() { 1 } else { a.vec_len() }
	}
	return total >= target.comps()
}

// binop_type returns the result type of a binary operator, or none when the
// operand types do not match GLSL ES 1.00 rules.
fn binop_type(op string, a Ty, b Ty) ?Ty {
	if a == .sampler2d || b == .sampler2d {
		return none
	}
	match op {
		'&&', '||' {
			if a == .bool_t && b == .bool_t {
				return Ty.bool_t
			}
		}
		'==', '!=' {
			if a == b && a != .void_t {
				return Ty.bool_t
			}
		}
		'<', '>', '<=', '>=' {
			if a == b && (a == .int_t || a == .float_t) {
				return Ty.bool_t
			}
		}
		'+', '-', '/' {
			if a == b && a != .bool_t && a != .void_t {
				return a
			}
			if a.is_float_based() && b == .float_t {
				return a
			}
			if b.is_float_based() && a == .float_t {
				return b
			}
		}
		'*' {
			if a == b && a != .bool_t && a != .void_t {
				return a
			}
			if a == .float_t && b.is_float_based() {
				return b
			}
			if b == .float_t && a.is_float_based() {
				return a
			}
			if a.mat_n() > 0 && b.vec_len() == a.mat_n() {
				return b
			}
			if a.vec_len() > 0 && b.mat_n() == a.vec_len() {
				return a
			}
		}
		else {}
	}
	return none
}

const unary_gen_builtins = ['abs', 'sign', 'floor', 'ceil', 'fract', 'sqrt', 'inversesqrt', 'sin',
	'cos', 'tan', 'asin', 'acos', 'exp', 'log', 'exp2', 'log2', 'normalize', 'radians', 'degrees']

// builtin_type gives the result type of a supported GLSL built-in call.
fn builtin_type(name string, args []Ty) ?Ty {
	if args.len == 1 && name in unary_gen_builtins {
		if args[0].is_gen() {
			return args[0]
		}
		return none
	}
	match name {
		'atan' {
			if args.len == 1 && args[0].is_gen() {
				return args[0]
			}
			if args.len == 2 && args[0] == args[1] && args[0].is_gen() {
				return args[0]
			}
		}
		'min', 'max', 'mod', 'pow' {
			if args.len != 2 {
				return none
			}
			a := args[0]
			b := args[1]
			if a.is_gen() && (a == b || (name != 'pow' && b == .float_t)) {
				return a
			}
		}
		'step' {
			if args.len == 2 && args[1].is_gen() && (args[0] == args[1] || args[0] == .float_t) {
				return args[1]
			}
		}
		'clamp' {
			if args.len == 3 && args[0].is_gen() {
				for a in args[1..] {
					if a != args[0] && a != .float_t {
						return none
					}
				}
				return args[0]
			}
		}
		'mix' {
			if args.len == 3 && args[0].is_gen() && args[0] == args[1] {
				if args[2] == args[0] || args[2] == .float_t {
					return args[0]
				}
			}
		}
		'dot' {
			if args.len == 2 && args[0].vec_len() > 0 && args[0] == args[1] {
				return Ty.float_t
			}
		}
		'length' {
			if args.len == 1 && args[0].vec_len() > 0 {
				return Ty.float_t
			}
		}
		'distance' {
			if args.len == 2 && args[0].vec_len() > 0 && args[0] == args[1] {
				return Ty.float_t
			}
		}
		'cross' {
			if args.len == 2 && args[0] == .vec3 && args[1] == .vec3 {
				return Ty.vec3
			}
		}
		else {}
	}
	return none
}
