// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// C ABI for GLES 2 state setters, uniform and attribute introspection, and the
// parameter getters, including the ANGLE "Robust" forms that take a buffer
// size and report the number of values written.

@[export: 'glHint']
pub fn capi_gl_hint(target u32, mode u32) {
	mut c := capi_ctx() or { return }
	c.hint(target, mode)
}

@[export: 'glLineWidth']
pub fn capi_gl_line_width(w f32) {
	mut c := capi_ctx() or { return }
	c.line_width(w)
}

@[export: 'glPolygonOffset']
pub fn capi_gl_polygon_offset(factor f32, units f32) {
	mut c := capi_ctx() or { return }
	c.polygon_offset(factor, units)
}

@[export: 'glSampleCoverage']
pub fn capi_gl_sample_coverage(value f32, invert u8) {
	mut c := capi_ctx() or { return }
	c.sample_coverage(value, invert != 0)
}

@[export: 'glPixelStorei']
pub fn capi_gl_pixel_storei(pname u32, param i32) {
	mut c := capi_ctx() or { return }
	c.pixel_store(pname, int(param))
}

@[export: 'glClearStencil']
pub fn capi_gl_clear_stencil(s i32) {
	mut c := capi_ctx() or { return }
	c.clear_stencil(int(s))
}

@[export: 'glStencilFunc']
pub fn capi_gl_stencil_func(func u32, ref i32, mask u32) {
	mut c := capi_ctx() or { return }
	c.stencil_func(func, int(ref), mask)
}

@[export: 'glStencilFuncSeparate']
pub fn capi_gl_stencil_func_separate(face u32, func u32, ref i32, mask u32) {
	mut c := capi_ctx() or { return }
	c.stencil_func_separate(face, func, int(ref), mask)
}

@[export: 'glStencilMask']
pub fn capi_gl_stencil_mask(mask u32) {
	mut c := capi_ctx() or { return }
	c.stencil_mask(mask)
}

@[export: 'glStencilMaskSeparate']
pub fn capi_gl_stencil_mask_separate(face u32, mask u32) {
	mut c := capi_ctx() or { return }
	c.stencil_mask_separate(face, mask)
}

@[export: 'glStencilOp']
pub fn capi_gl_stencil_op(fail u32, zfail u32, zpass u32) {
	mut c := capi_ctx() or { return }
	c.stencil_op(fail, zfail, zpass)
}

@[export: 'glStencilOpSeparate']
pub fn capi_gl_stencil_op_separate(face u32, fail u32, zfail u32, zpass u32) {
	mut c := capi_ctx() or { return }
	c.stencil_op_separate(face, fail, zfail, zpass)
}

@[export: 'glDrawBuffers']
pub fn capi_gl_draw_buffers(n i32, bufs &u32) {
	mut c := capi_ctx() or { return }
	if n < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	mut list := []u32{}
	for i in 0 .. int(n) {
		list << unsafe { bufs[i] }
	}
	c.draw_buffers(list)
}

@[export: 'glDrawBuffersEXT']
pub fn capi_gl_draw_buffers_ext(n i32, bufs &u32) {
	capi_gl_draw_buffers(n, bufs)
}

@[export: 'glReadBuffer']
pub fn capi_gl_read_buffer(src u32) {
	mut c := capi_ctx() or { return }
	c.read_buffer(src)
}

@[export: 'glValidateProgram']
pub fn capi_gl_validate_program(prog u32) {
	mut c := capi_ctx() or { return }
	c.validate_program(prog)
}

@[export: 'glBindAttribLocation']
pub fn capi_gl_bind_attrib_location(prog u32, index u32, name voidptr) {
	mut c := capi_ctx() or { return }
	c.bind_attrib_location(prog, int(index), capi_string(name, -1))
}

@[export: 'glVertexAttrib1f']
pub fn capi_gl_vertex_attrib1f(i u32, x f32) {
	mut c := capi_ctx() or { return }
	c.vertex_attrib_const(int(i), x, 0, 0, 1)
}

@[export: 'glVertexAttrib2f']
pub fn capi_gl_vertex_attrib2f(i u32, x f32, y f32) {
	mut c := capi_ctx() or { return }
	c.vertex_attrib_const(int(i), x, y, 0, 1)
}

@[export: 'glVertexAttrib3f']
pub fn capi_gl_vertex_attrib3f(i u32, x f32, y f32, z f32) {
	mut c := capi_ctx() or { return }
	c.vertex_attrib_const(int(i), x, y, z, 1)
}

@[export: 'glVertexAttrib4f']
pub fn capi_gl_vertex_attrib4f(i u32, x f32, y f32, z f32, w f32) {
	mut c := capi_ctx() or { return }
	c.vertex_attrib_const(int(i), x, y, z, w)
}

@[export: 'glVertexAttrib1fv']
pub fn capi_gl_vertex_attrib1fv(i u32, v &f32) {
	capi_gl_vertex_attrib1f(i, unsafe { v[0] })
}

@[export: 'glVertexAttrib2fv']
pub fn capi_gl_vertex_attrib2fv(i u32, v &f32) {
	capi_gl_vertex_attrib2f(i, unsafe { v[0] }, unsafe { v[1] })
}

@[export: 'glVertexAttrib3fv']
pub fn capi_gl_vertex_attrib3fv(i u32, v &f32) {
	capi_gl_vertex_attrib3f(i, unsafe { v[0] }, unsafe { v[1] }, unsafe { v[2] })
}

@[export: 'glVertexAttrib4fv']
pub fn capi_gl_vertex_attrib4fv(i u32, v &f32) {
	capi_gl_vertex_attrib4f(i, unsafe { v[0] }, unsafe { v[1] }, unsafe { v[2] }, unsafe { v[3] })
}

// Integer uniforms: the subset has no integer vectors, so only the one-value
// forms can match a uniform; the others record INVALID_OPERATION.
@[export: 'glUniform2i']
pub fn capi_gl_uniform2i(loc i32, x i32, y i32) {
	mut c := capi_ctx() or { return }
	c.uniform_ints(int(loc), [int(x), int(y)])
}

@[export: 'glUniform3i']
pub fn capi_gl_uniform3i(loc i32, x i32, y i32, z i32) {
	mut c := capi_ctx() or { return }
	c.uniform_ints(int(loc), [int(x), int(y), int(z)])
}

@[export: 'glUniform4i']
pub fn capi_gl_uniform4i(loc i32, x i32, y i32, z i32, w i32) {
	mut c := capi_ctx() or { return }
	c.uniform_ints(int(loc), [int(x), int(y), int(z), int(w)])
}

fn capi_uniform_ints(n int, loc i32, count i32, v &i32) {
	mut c := capi_ctx() or { return }
	if count < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	if count != 1 || v == unsafe { nil } {
		c.set_error(gl_invalid_operation)
		return
	}
	mut values := []int{}
	for i in 0 .. n {
		values << int(unsafe { v[i] })
	}
	c.uniform_ints(int(loc), values)
}

@[export: 'glUniform1iv']
pub fn capi_gl_uniform1iv(loc i32, count i32, v &i32) {
	capi_uniform_ints(1, loc, count, v)
}

@[export: 'glUniform2iv']
pub fn capi_gl_uniform2iv(loc i32, count i32, v &i32) {
	capi_uniform_ints(2, loc, count, v)
}

@[export: 'glUniform3iv']
pub fn capi_gl_uniform3iv(loc i32, count i32, v &i32) {
	capi_uniform_ints(3, loc, count, v)
}

@[export: 'glUniform4iv']
pub fn capi_gl_uniform4iv(loc i32, count i32, v &i32) {
	capi_uniform_ints(4, loc, count, v)
}

fn capi_copy_name(name string, size i32, length &i32, out voidptr) {
	capi_write_log(name, size, length, out)
}

@[export: 'glGetActiveAttrib']
pub fn capi_gl_get_active_attrib(prog u32, index u32, size i32, length &i32, asize &i32, typ &u32, name voidptr) {
	mut c := capi_ctx() or { return }
	info := c.active_attrib(prog, int(index)) or { return }
	unsafe {
		if asize != nil {
			*asize = i32(info.size)
		}
		if typ != nil {
			*typ = info.typ
		}
	}
	capi_copy_name(info.name, size, length, name)
}

@[export: 'glGetActiveUniform']
pub fn capi_gl_get_active_uniform(prog u32, index u32, size i32, length &i32, asize &i32, typ &u32, name voidptr) {
	mut c := capi_ctx() or { return }
	info := c.active_uniform(prog, int(index)) or { return }
	unsafe {
		if asize != nil {
			*asize = i32(info.size)
		}
		if typ != nil {
			*typ = info.typ
		}
	}
	capi_copy_name(info.name, size, length, name)
}

@[export: 'glGetUniformfv']
pub fn capi_gl_get_uniformfv(prog u32, loc i32, out &f32) {
	mut c := capi_ctx() or { return }
	values := c.get_uniform(prog, int(loc)) or { return }
	for i, v in values {
		unsafe {
			out[i] = f32(v)
		}
	}
}

@[export: 'glGetUniformiv']
pub fn capi_gl_get_uniformiv(prog u32, loc i32, out &i32) {
	mut c := capi_ctx() or { return }
	values := c.get_uniform(prog, int(loc)) or { return }
	for i, v in values {
		unsafe {
			out[i] = i32(v)
		}
	}
}

// capi_put_ints stores up to buf_size values as integers and reports the count,
// which is what every Robust getter does; a negative buffer size is an error.
fn capi_put_ints(c &Context, values []f64, buf_size i32, length &i32, out &i32) bool {
	return capi_put_values(c, values, buf_size, length, fn (v f64, out voidptr, i int) {
		unsafe {
			(&i32(out))[i] = i32(v)
		}
	}, out)
}

fn capi_put_values(c &Context, values []f64, buf_size i32, length &i32, store fn (f64, voidptr, int), out voidptr) bool {
	if buf_size < 0 || int(buf_size) < values.len {
		return false
	}
	for i, v in values {
		store(v, out, i)
	}
	if length != unsafe { nil } {
		unsafe {
			*length = i32(values.len)
		}
	}
	return true
}

fn capi_robust_ints(mut c Context, values []f64, buf_size i32, length &i32, out &i32) {
	if !capi_put_ints(c, values, buf_size, length, out) {
		c.set_error(gl_invalid_operation)
	}
}

fn capi_robust_floats(mut c Context, values []f64, buf_size i32, length &i32, out &f32) {
	ok := capi_put_values(c, values, buf_size, length, fn (v f64, out voidptr, i int) {
		unsafe {
			(&f32(out))[i] = f32(v)
		}
	}, out)
	if !ok {
		c.set_error(gl_invalid_operation)
	}
}

@[export: 'glGetIntegervRobustANGLE']
pub fn capi_gl_get_integerv_robust(pname u32, buf_size i32, length &i32, out &i32) {
	mut c := capi_ctx() or { return }
	values := c.get_integers(pname)
	if values.len == 0 {
		return
	}
	mut doubles := []f64{}
	for v in values {
		doubles << f64(v)
	}
	capi_robust_ints(mut c, doubles, buf_size, length, out)
}

@[export: 'glGetFloatvRobustANGLE']
pub fn capi_gl_get_floatv_robust(pname u32, buf_size i32, length &i32, out &f32) {
	mut c := capi_ctx() or { return }
	values := c.get_floats(pname)
	if values.len == 0 {
		return
	}
	mut doubles := []f64{}
	for v in values {
		doubles << f64(v)
	}
	capi_robust_floats(mut c, doubles, buf_size, length, out)
}

@[export: 'glGetBooleanvRobustANGLE']
pub fn capi_gl_get_booleanv_robust(pname u32, buf_size i32, length &i32, out &u8) {
	mut c := capi_ctx() or { return }
	values := c.get_integers(pname)
	if values.len == 0 {
		return
	}
	if buf_size < 0 || int(buf_size) < values.len {
		c.set_error(gl_invalid_operation)
		return
	}
	for i, v in values {
		unsafe {
			out[i] = if v != 0 { u8(1) } else { u8(0) }
		}
	}
	if length != unsafe { nil } {
		unsafe {
			*length = i32(values.len)
		}
	}
}

@[export: 'glGetInteger64vRobustANGLE']
pub fn capi_gl_get_integer64v_robust(pname u32, buf_size i32, length &i32, out &i64) {
	mut c := capi_ctx() or { return }
	values := c.get_integers(pname)
	if values.len == 0 {
		return
	}
	if buf_size < 0 || int(buf_size) < values.len {
		c.set_error(gl_invalid_operation)
		return
	}
	for i, v in values {
		unsafe {
			out[i] = i64(v)
		}
	}
	if length != unsafe { nil } {
		unsafe {
			*length = i32(values.len)
		}
	}
}

@[export: 'glGetProgramivRobustANGLE']
pub fn capi_gl_get_programiv_robust(prog u32, pname u32, buf_size i32, length &i32, out &i32) {
	mut c := capi_ctx() or { return }
	v := c.program_param(prog, pname) or { return }
	capi_robust_ints(mut c, [v], buf_size, length, out)
}

@[export: 'glGetShaderivRobustANGLE']
pub fn capi_gl_get_shaderiv_robust(shader u32, pname u32, buf_size i32, length &i32, out &i32) {
	mut c := capi_ctx() or { return }
	v := c.shader_param(shader, pname) or { return }
	capi_robust_ints(mut c, [v], buf_size, length, out)
}

@[export: 'glGetTexParameterivRobustANGLE']
pub fn capi_gl_get_tex_parameteriv_robust(target u32, pname u32, buf_size i32, length &i32, out &i32) {
	mut c := capi_ctx() or { return }
	v := c.tex_parameter_value(target, pname) or { return }
	capi_robust_ints(mut c, [v], buf_size, length, out)
}

@[export: 'glGetTexParameterfvRobustANGLE']
pub fn capi_gl_get_tex_parameterfv_robust(target u32, pname u32, buf_size i32, length &i32, out &f32) {
	mut c := capi_ctx() or { return }
	v := c.tex_parameter_value(target, pname) or { return }
	capi_robust_floats(mut c, [v], buf_size, length, out)
}

@[export: 'glGetBufferParameterivRobustANGLE']
pub fn capi_gl_get_buffer_parameteriv_robust(target u32, pname u32, buf_size i32, length &i32, out &i32) {
	mut c := capi_ctx() or { return }
	v := c.buffer_parameter(target, pname) or { return }
	capi_robust_ints(mut c, [v], buf_size, length, out)
}

@[export: 'glGetRenderbufferParameterivRobustANGLE']
pub fn capi_gl_get_renderbuffer_parameteriv_robust(target u32, pname u32, buf_size i32, length &i32, out &i32) {
	mut c := capi_ctx() or { return }
	v := c.renderbuffer_parameter(target, pname) or { return }
	capi_robust_ints(mut c, [v], buf_size, length, out)
}

@[export: 'glGetVertexAttribivRobustANGLE']
pub fn capi_gl_get_vertex_attribiv_robust(index u32, pname u32, buf_size i32, length &i32, out &i32) {
	mut c := capi_ctx() or { return }
	values := c.vertex_attrib_param(int(index), pname) or { return }
	capi_robust_ints(mut c, values, buf_size, length, out)
}

@[export: 'glGetVertexAttribfvRobustANGLE']
pub fn capi_gl_get_vertex_attribfv_robust(index u32, pname u32, buf_size i32, length &i32, out &f32) {
	mut c := capi_ctx() or { return }
	values := c.vertex_attrib_param(int(index), pname) or { return }
	capi_robust_floats(mut c, values, buf_size, length, out)
}

@[export: 'glCopyTexImage2D']
pub fn capi_gl_copy_tex_image_2d(target u32, level i32, internal_format u32, x i32, y i32, w i32, h i32, border i32) {
	mut c := capi_ctx() or { return }
	c.copy_tex_image_2d(target, int(level), internal_format, int(x), int(y), int(w), int(h),
		int(border))
}

@[export: 'glCopyTexSubImage2D']
pub fn capi_gl_copy_tex_sub_image_2d(target u32, level i32, xoff i32, yoff i32, x i32, y i32, w i32, h i32) {
	mut c := capi_ctx() or { return }
	c.copy_tex_sub_image_2d(target, int(level), int(xoff), int(yoff), int(x), int(y), int(w), int(h))
}

@[export: 'glCompressedTexImage2D']
pub fn capi_gl_compressed_tex_image_2d(target u32, level i32, format u32, w i32, h i32, border i32, size i32, data voidptr) {
	mut c := capi_ctx() or { return }
	c.compressed_tex_image_2d(target, int(level), format)
}
