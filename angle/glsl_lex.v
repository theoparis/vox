// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// TokKind classifies the tokens of the GLSL ES 1.00 subset.
enum TokKind {
	ident
	int_lit
	float_lit
	op
	eof
}

struct Token {
	kind TokKind
	text string
	line int
}

const glsl_two_char_ops = ['<=', '>=', '==', '!=', '&&', '||', '++', '--', '+=', '-=', '*=', '/=']
const glsl_one_char_ops = ['+', '-', '*', '/', '<', '>', '=', '!', '(', ')', '{', '}', '[', ']', ';',
	',', '.', '?', ':']

fn is_digit(c u8) bool {
	return c >= `0` && c <= `9`
}

fn is_ident_start(c u8) bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_`
}

fn is_ident_char(c u8) bool {
	return is_ident_start(c) || is_digit(c)
}

// glsl_lex tokenizes the GLSL ES 1.00 subset. The only preprocessor line
// accepted is `#version 100`. Other directives are rejected rather than
// ignored, because macros would change the meaning of the shader silently.
fn glsl_lex(src string) ![]Token {
	mut toks := []Token{}
	mut i := 0
	mut line := 1
	for i < src.len {
		c := src[i]
		if c == `\n` {
			line++
			i++
		} else if c == ` ` || c == `\t` || c == `\r` {
			i++
		} else if c == `/` && i + 1 < src.len && src[i + 1] == `/` {
			for i < src.len && src[i] != `\n` {
				i++
			}
		} else if c == `/` && i + 1 < src.len && src[i + 1] == `*` {
			i += 2
			for {
				if i + 1 >= src.len {
					return error('line ${line}: unterminated comment')
				}
				if src[i] == `*` && src[i + 1] == `/` {
					i += 2
					break
				}
				if src[i] == `\n` {
					line++
				}
				i++
			}
		} else if c == `#` {
			start := i
			for i < src.len && src[i] != `\n` {
				i++
			}
			directive := src[start..i].trim_space()
			if directive != '#version 100' {
				return error('line ${line}: unsupported directive "${directive}"')
			}
		} else if is_ident_start(c) {
			start := i
			for i < src.len && is_ident_char(src[i]) {
				i++
			}
			toks << Token{.ident, src[start..i], line}
		} else if is_digit(c) || (c == `.` && i + 1 < src.len && is_digit(src[i + 1])) {
			start := i
			mut is_float := false
			for i < src.len && is_digit(src[i]) {
				i++
			}
			if i < src.len && src[i] == `.` {
				is_float = true
				i++
				for i < src.len && is_digit(src[i]) {
					i++
				}
			}
			if i < src.len && (src[i] == `e` || src[i] == `E`) {
				is_float = true
				i++
				if i < src.len && (src[i] == `+` || src[i] == `-`) {
					i++
				}
				if i >= src.len || !is_digit(src[i]) {
					return error('line ${line}: malformed float exponent')
				}
				for i < src.len && is_digit(src[i]) {
					i++
				}
			}
			kind := if is_float { TokKind.float_lit } else { TokKind.int_lit }
			toks << Token{kind, src[start..i], line}
		} else {
			two := if i + 1 < src.len { src[i..i + 2] } else { '' }
			one := src[i..i + 1]
			if two in glsl_two_char_ops {
				toks << Token{.op, two, line}
				i += 2
			} else if one in glsl_one_char_ops {
				toks << Token{.op, one, line}
				i++
			} else {
				return error('line ${line}: unexpected character "${one}"')
			}
		}
	}
	toks << Token{.eof, '', line}
	return toks
}
