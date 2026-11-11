// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Parser is a recursive-descent parser over the token stream.
struct Parser {
mut:
	toks []Token
	pos  int
}

fn (p &Parser) cur() Token {
	return p.toks[p.pos]
}

fn (p &Parser) at(offset int) Token {
	idx := p.pos + offset
	if idx < p.toks.len {
		return p.toks[idx]
	}
	return p.toks[p.toks.len - 1]
}

fn (p &Parser) where() string {
	return 'line ${p.cur().line}: '
}

fn (mut p Parser) advance() Token {
	t := p.toks[p.pos]
	if p.pos < p.toks.len - 1 {
		p.pos++
	}
	return t
}

fn (p &Parser) is_op(s string) bool {
	t := p.cur()
	return t.kind == .op && t.text == s
}

fn (p &Parser) is_word(s string) bool {
	t := p.cur()
	return t.kind == .ident && t.text == s
}

fn (mut p Parser) expect(s string) ! {
	if !p.is_op(s) {
		return error('${p.where()}expected "${s}" but found "${p.cur().text}"')
	}
	p.pos++
}

fn (mut p Parser) ident() !string {
	t := p.cur()
	if t.kind != .ident {
		return error('${p.where()}expected a name but found "${t.text}"')
	}
	if t.text.starts_with('gl_') {
		return error('${p.where()}"${t.text}" uses the reserved gl_ prefix')
	}
	p.pos++
	return t.text
}

fn (mut p Parser) type_name() !Ty {
	t := p.cur()
	if t.kind != .ident {
		return error('${p.where()}expected a type but found "${t.text}"')
	}
	ty := ty_from_name(t.text) or {
		return error('${p.where()}"${t.text}" is not a supported type')
	}
	p.pos++
	return ty
}

// is_precision_word reports qualifiers that have no effect on the Metal
// translation; they are accepted and dropped.
fn is_precision_word(s string) bool {
	return s == 'lowp' || s == 'mediump' || s == 'highp'
}

// glsl_parse parses one GLSL ES 1.00 shader into a Unit. It does not check
// types or scoping; check_unit does that for the stage.
pub fn glsl_parse(src string) !Unit {
	toks := glsl_lex(src)!
	mut p := Parser{
		toks: toks
	}
	mut unit := Unit{}
	for p.cur().kind != .eof {
		if p.is_word('precision') {
			for !p.is_op(';') {
				if p.cur().kind == .eof {
					return error('${p.where()}unterminated precision statement')
				}
				p.pos++
			}
			p.pos++
			continue
		}
		line := p.cur().line
		qual, is_const := p.qualifiers()
		if is_const {
			return error('line ${line}: const globals are not supported')
		}
		ty := p.type_name()!
		name := p.ident()!
		if p.is_op('(') {
			if qual != .none_q {
				return error('line ${line}: functions cannot be attribute, varying, or uniform')
			}
			unit.funcs << p.function(ty, name, line)!
			continue
		}
		if qual == .none_q {
			return error('line ${line}: global variables must be attribute, varying, or uniform')
		}
		mut names := [name]
		for p.is_op(',') {
			p.pos++
			names << p.ident()!
		}
		if p.is_op('[') {
			return error('${p.where()}arrays are not supported')
		}
		if p.is_op('=') {
			return error('${p.where()}global initializers are not supported')
		}
		p.expect(';')!
		for n in names {
			unit.globals << Global{
				name: n
				qual: qual
				ty:   ty
				line: line
			}
		}
	}
	return unit
}

// qualifiers consumes storage and precision qualifiers and reports const.
fn (mut p Parser) qualifiers() (Qual, bool) {
	mut qual := Qual.none_q
	mut is_const := false
	for p.cur().kind == .ident {
		word := p.cur().text
		if word == 'attribute' {
			qual = .attribute
		} else if word == 'varying' {
			qual = .varying
		} else if word == 'uniform' {
			qual = .uniform
		} else if word == 'const' {
			is_const = true
		} else if !is_precision_word(word) {
			break
		}
		p.pos++
	}
	return qual, is_const
}

fn (mut p Parser) function(ret Ty, name string, line int) !Func {
	p.expect('(')!
	mut params := []Param{}
	if p.is_word('void') && p.at(1).kind == .op && p.at(1).text == ')' {
		p.pos++
	} else if !p.is_op(')') {
		for {
			for p.is_word('const') || p.is_word('in') || is_precision_word(p.cur().text) {
				p.pos++
			}
			if p.is_word('out') || p.is_word('inout') {
				return error('${p.where()}out and inout parameters are not supported')
			}
			ty := p.type_name()!
			pname := p.ident()!
			params << Param{
				name: pname
				ty:   ty
			}
			if !p.is_op(',') {
				break
			}
			p.pos++
		}
	}
	p.expect(')')!
	if p.is_op(';') {
		return error('${p.where()}function prototypes are not supported')
	}
	body := p.block()!
	return Func{
		name:   name
		ret:    ret
		params: params
		body:   body
		line:   line
	}
}

fn (mut p Parser) block() ![]Stmt {
	p.expect('{')!
	mut out := []Stmt{}
	for !p.is_op('}') {
		if p.cur().kind == .eof {
			return error('${p.where()}unexpected end of file inside a block')
		}
		p.statement(mut out)!
	}
	p.pos++
	return out
}

// body parses the statement of an if, else, or for: a block or one statement.
fn (mut p Parser) body() ![]Stmt {
	if p.is_op('{') {
		return p.block()
	}
	mut out := []Stmt{}
	p.statement(mut out)!
	return out
}

fn (p &Parser) starts_decl() bool {
	if p.is_word('const') {
		return true
	}
	t := p.cur()
	if t.kind != .ident || p.at(1).kind != .ident {
		return false
	}
	ty_from_name(t.text) or { return false }
	return true
}

// local_decl parses `[const] type name [= expr] {, name [= expr]}` without
// the terminating semicolon, so for-loop initializers can reuse it.
fn (mut p Parser) local_decl() ![]Stmt {
	line := p.cur().line
	for p.is_word('const') || is_precision_word(p.cur().text) {
		p.pos++
	}
	ty := p.type_name()!
	if ty == .void_t {
		return error('line ${line}: void variables are not allowed')
	}
	mut out := []Stmt{}
	for {
		name := p.ident()!
		if p.is_op('[') {
			return error('${p.where()}arrays are not supported')
		}
		mut rhs := no_expr()
		if p.is_op('=') {
			p.pos++
			rhs = p.expr()!
		}
		out << Stmt{
			kind: .decl_s
			name: name
			ty:   ty
			rhs:  rhs
			line: line
		}
		if !p.is_op(',') {
			break
		}
		p.pos++
	}
	return out
}

fn (mut p Parser) statement(mut out []Stmt) ! {
	line := p.cur().line
	if p.is_op('{') {
		out << Stmt{
			kind: .block_s
			body: p.block()!
			line: line
		}
		return
	}
	if p.is_word('if') {
		p.pos++
		p.expect('(')!
		cond := p.expr()!
		p.expect(')')!
		then_body := p.body()!
		mut alt := []Stmt{}
		if p.is_word('else') {
			p.pos++
			alt = p.body()!
		}
		out << Stmt{
			kind: .if_s
			cond: cond
			body: then_body
			alt:  alt
			line: line
		}
		return
	}
	if p.is_word('for') {
		out << p.for_loop()!
		return
	}
	if p.is_word('return') {
		p.pos++
		mut value := no_expr()
		if !p.is_op(';') {
			value = p.expr()!
		}
		p.expect(';')!
		out << Stmt{
			kind: .ret_s
			rhs:  value
			line: line
		}
		return
	}
	if p.is_word('break') || p.is_word('continue') {
		kind := if p.is_word('break') { StmtKind.break_s } else { StmtKind.cont_s }
		p.pos++
		p.expect(';')!
		out << Stmt{
			kind: kind
			line: line
		}
		return
	}
	if p.is_word('discard') {
		return error('${p.where()}discard is not supported yet')
	}
	if p.starts_decl() {
		decls := p.local_decl()!
		p.expect(';')!
		out << decls
		return
	}
	lhs := p.expr()!
	if p.cur().kind == .op && p.cur().text in ['=', '+=', '-=', '*=', '/='] {
		op := p.advance().text
		rhs := p.expr()!
		p.expect(';')!
		out << Stmt{
			kind: .assign_s
			op:   op
			lhs:  lhs
			rhs:  rhs
			line: line
		}
		return
	}
	if p.is_op('++') || p.is_op('--') {
		op := p.advance().text
		p.expect(';')!
		out << Stmt{
			kind: .assign_s
			op:   op
			lhs:  lhs
			line: line
		}
		return
	}
	p.expect(';')!
	out << Stmt{
		kind: .expr_s
		rhs:  lhs
		line: line
	}
}

// for_loop accepts `for (decl; cond; step) body`, where step is an
// assignment or ++/--. Other forms are not part of the subset.
fn (mut p Parser) for_loop() !Stmt {
	line := p.cur().line
	p.pos++
	p.expect('(')!
	mut init := []Stmt{}
	if !p.is_op(';') {
		init = p.local_decl()!
	}
	p.expect(';')!
	mut cond := no_expr()
	if !p.is_op(';') {
		cond = p.expr()!
	}
	p.expect(';')!
	mut step := []Stmt{}
	if !p.is_op(')') {
		lhs := p.expr()!
		if p.is_op('++') || p.is_op('--') {
			op := p.advance().text
			step << Stmt{
				kind: .assign_s
				op:   op
				lhs:  lhs
				line: line
			}
		} else if p.cur().kind == .op && p.cur().text in ['=', '+=', '-=', '*=', '/='] {
			op := p.advance().text
			rhs := p.expr()!
			step << Stmt{
				kind: .assign_s
				op:   op
				lhs:  lhs
				rhs:  rhs
				line: line
			}
		} else {
			return error('${p.where()}for step must be an assignment or ++/--')
		}
	}
	p.expect(')')!
	body := p.body()!
	return Stmt{
		kind:     .for_s
		cond:     cond
		body:     body
		for_init: init
		for_step: step
		line:     line
	}
}

fn (mut p Parser) expr() !&Expr {
	cond := p.binary(0)!
	if p.is_op('?') {
		line := p.cur().line
		p.pos++
		a := p.expr()!
		p.expect(':')!
		b := p.expr()!
		return &Expr{
			kind: .ternary
			args: [cond, a, b]
			line: line
		}
	}
	return cond
}

// binary_levels lists binary operators from loosest to tightest binding.
const binary_levels = [['||'], ['&&'], ['==', '!='], ['<', '>', '<=', '>='], ['+', '-'],
	['*', '/']]

fn (mut p Parser) binary(level int) !&Expr {
	if level == binary_levels.len {
		return p.unary()
	}
	mut left := p.binary(level + 1)!
	for p.cur().kind == .op && p.cur().text in binary_levels[level] {
		line := p.cur().line
		op := p.advance().text
		right := p.binary(level + 1)!
		left = &Expr{
			kind: .binary
			text: op
			args: [left, right]
			line: line
		}
	}
	return left
}

fn (mut p Parser) unary() !&Expr {
	if p.is_op('-') || p.is_op('+') || p.is_op('!') {
		t := p.advance()
		operand := p.unary()!
		if t.text == '+' {
			return operand
		}
		return &Expr{
			kind: .unary
			text: t.text
			args: [operand]
			line: t.line
		}
	}
	return p.postfix()
}

fn (mut p Parser) postfix() !&Expr {
	mut e := p.primary()!
	for p.is_op('.') {
		p.pos++
		name := p.cur().text
		if p.cur().kind != .ident {
			return error('${p.where()}expected a field after "."')
		}
		p.pos++
		e = &Expr{
			kind: .field
			text: name
			args: [e]
			line: e.line
		}
	}
	if p.is_op('[') {
		return error('${p.where()}array indexing is not supported')
	}
	return e
}

fn (mut p Parser) primary() !&Expr {
	t := p.cur()
	match t.kind {
		.int_lit {
			p.pos++
			return &Expr{
				kind:     .lit
				text:     t.text
				lit_type: 'int'
				line:     t.line
			}
		}
		.float_lit {
			p.pos++
			return &Expr{
				kind:     .lit
				text:     t.text
				lit_type: 'float'
				line:     t.line
			}
		}
		.ident {
			p.pos++
			if t.text == 'true' || t.text == 'false' {
				return &Expr{
					kind:     .lit
					text:     t.text
					lit_type: 'bool'
					line:     t.line
				}
			}
			if p.is_op('(') {
				p.pos++
				mut args := []&Expr{}
				if !p.is_op(')') {
					for {
						args << p.expr()!
						if !p.is_op(',') {
							break
						}
						p.pos++
					}
				}
				p.expect(')')!
				return &Expr{
					kind: .call
					text: t.text
					args: args
					line: t.line
				}
			}
			return &Expr{
				kind: .ident
				text: t.text
				line: t.line
			}
		}
		.op {
			if t.text == '(' {
				p.pos++
				e := p.expr()!
				p.expect(')')!
				return e
			}
		}
		else {}
	}
	return error('${p.where()}unexpected "${t.text}"')
}
