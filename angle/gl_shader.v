// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

pub const gl_vertex_shader = u32(0x8b31)
pub const gl_fragment_shader = u32(0x8b30)
pub const gl_float = u32(0x1406)
pub const gl_points = u32(0)
pub const gl_lines = u32(1)
pub const gl_line_loop = u32(2)
pub const gl_line_strip = u32(3)
pub const gl_triangles = u32(4)
pub const gl_triangle_strip = u32(5)
pub const gl_triangle_fan = u32(6)

// AttribPointer is the state set by vertex_attrib_pointer for one attribute.
pub struct AttribPointer {
pub mut:
	enabled bool
	buffer  u32
	size    int
	typ     u32
	stride  int
	offset  int
}

// ---- Shader and program objects -------------------------------------------

pub fn (mut c Context) create_shader(kind u32) u32 {
	k := if kind == gl_vertex_shader {
		ShaderKind.vertex
	} else if kind == gl_fragment_shader {
		ShaderKind.fragment
	} else {
		c.set_error(gl_invalid_enum)
		return 0
	}
	name := c.new_name()
	c.shaders[name] = &Shader{
		kind: k
	}
	return name
}

pub fn (mut c Context) shader_source(name u32, source string) {
	if name !in c.shaders {
		c.set_error(gl_invalid_value)
		return
	}
	mut s := c.shaders[name]
	s.source = source
}

// compile_shader parses and checks the source. The result is available from
// shader_compiled and shader_log.
pub fn (mut c Context) compile_shader(name u32) bool {
	if name !in c.shaders {
		c.set_error(gl_invalid_value)
		return false
	}
	mut s := c.shaders[name]
	s.compile()
	return s.ok
}

pub fn (c &Context) shader_compiled(name u32) bool {
	return name in c.shaders && c.shaders[name].ok
}

pub fn (c &Context) shader_log(name u32) string {
	if name !in c.shaders {
		return ''
	}
	return c.shaders[name].log
}

pub fn (mut c Context) create_program() u32 {
	name := c.new_name()
	c.programs[name] = &Program{}
	return name
}

pub fn (mut c Context) attach_shader(prog u32, shader u32) {
	if prog !in c.programs || shader !in c.shaders {
		c.set_error(gl_invalid_value)
		return
	}
	mut p := c.programs[prog]
	kind := c.shaders[shader].kind
	if kind == .vertex {
		if p.vertex != 0 {
			c.set_error(gl_invalid_operation)
			return
		}
		p.vertex = shader
	} else {
		if p.fragment != 0 {
			c.set_error(gl_invalid_operation)
			return
		}
		p.fragment = shader
	}
}

// link_program links the attached shaders into Metal libraries. Failures
// leave the program unlinked and set its log, as GLES does.
pub fn (mut c Context) link_program(prog u32) bool {
	if prog !in c.programs {
		c.set_error(gl_invalid_value)
		return false
	}
	mut p := c.programs[prog]
	p.linked = false
	p.log = ''
	if p.vertex == 0 || p.fragment == 0 {
		p.log = 'a program needs one vertex shader and one fragment shader'
		return false
	}
	vs := c.shaders[p.vertex]
	fs := c.shaders[p.fragment]
	if !vs.ok {
		p.log = 'vertex shader: ${vs.log}'
		return false
	}
	if !fs.ok {
		p.log = 'fragment shader: ${fs.log}'
		return false
	}
	plan := plan_link(&vs.unit, &fs.unit) or {
		p.log = err.msg()
		return false
	}
	vs_src := emit_msl(&vs.unit, .vertex, plan.vs_layout)
	fs_src := emit_msl(&fs.unit, .fragment, plan.fs_layout)
	vs_lib := c.display.backend.compile_library(vs_src) or {
		p.log = 'vertex shader translation: ${err.msg()}'
		return false
	}
	fs_lib := c.display.backend.compile_library(fs_src) or {
		c.display.backend.release_object(vs_lib)
		p.log = 'fragment shader translation: ${err.msg()}'
		return false
	}
	c.release_program_libraries(mut p)
	p.vs_lib = vs_lib
	p.fs_lib = fs_lib
	p.attrs = plan.vs_layout.attrs
	p.uniforms = plan.uniforms
	p.uniform_data = [][]u8{}
	for u in plan.uniforms {
		p.uniform_data << []u8{len: u.ty.msl_size()}
	}
	p.pipelines = map[string]u32{}
	p.linked = true
	return true
}

// release_program_libraries frees a program's Metal objects. Pipelines are
// released with the libraries they were built from.
fn (mut c Context) release_program_libraries(mut p Program) {
	for _, handle in p.pipelines {
		c.display.backend.release_object(handle)
	}
	if p.vs_lib != 0 {
		c.display.backend.release_object(p.vs_lib)
	}
	if p.fs_lib != 0 {
		c.display.backend.release_object(p.fs_lib)
	}
	p.vs_lib = 0
	p.fs_lib = 0
	p.pipelines = map[string]u32{}
}

pub fn (c &Context) program_linked(prog u32) bool {
	return prog in c.programs && c.programs[prog].linked
}

pub fn (c &Context) program_log(prog u32) string {
	if prog !in c.programs {
		return ''
	}
	return c.programs[prog].log
}

fn (mut c Context) use_program_raw(prog u32) {
	if prog == 0 {
		c.current_program = 0
		return
	}
	if prog !in c.programs {
		c.set_error(gl_invalid_value)
		return
	}
	if !c.programs[prog].linked {
		c.set_error(gl_invalid_operation)
		return
	}
	c.current_program = prog
}

// attrib_location returns the attribute slot, or -1 when the name is not an
// active attribute of the program.
pub fn (c &Context) attrib_location(prog u32, name string) int {
	if prog !in c.programs {
		return -1
	}
	for a in c.programs[prog].attrs {
		if a.name == name {
			return a.loc
		}
	}
	return -1
}

pub fn (c &Context) uniform_location(prog u32, name string) int {
	if prog !in c.programs {
		return -1
	}
	for u in c.programs[prog].uniforms {
		if u.name == name {
			return u.loc
		}
	}
	return -1
}

// ---- Vertex attributes ----------------------------------------------------

// vertex_attrib_pointer binds attribute index to the array buffer currently
// bound to GL_ARRAY_BUFFER. Only float attributes are supported.
pub fn (mut c Context) vertex_attrib_pointer(index int, size int, typ u32, stride int, offset int) {
	if index < 0 || index >= max_attribs || size < 1 || size > 4 {
		c.set_error(gl_invalid_value)
		return
	}
	if stride < 0 || offset < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	if typ != gl_float {
		c.set_error(gl_invalid_operation)
		return
	}
	buffer := c.bound_buffers[gl_array_buffer] or { 0 }
	c.attribs[index] = AttribPointer{
		enabled: c.attribs[index].enabled
		buffer:  buffer
		size:    size
		typ:     typ
		stride:  stride
		offset:  offset
	}
}

pub fn (mut c Context) enable_vertex_attrib(index int, on bool) {
	if index < 0 || index >= max_attribs {
		c.set_error(gl_invalid_value)
		return
	}
	c.attribs[index].enabled = on
}

// ---- Uniforms -------------------------------------------------------------

// current_linked returns the program in use, or an error when none is.
fn (c &Context) current_linked() ?&Program {
	if c.current_program == 0 || c.current_program !in c.programs {
		return none
	}
	p := c.programs[c.current_program]
	if !p.linked {
		return none
	}
	return p
}

fn f32_bits(v f32) u32 {
	return unsafe { *(&u32(&v)) }
}

fn get_u32(data []u8, at int) u32 {
	return u32(data[at]) | (u32(data[at + 1]) << 8) | (u32(data[at + 2]) << 16) | (u32(data[at + 3]) << 24)
}

fn put_u32(mut out []u8, at int, bits u32) {
	out[at] = u8(bits)
	out[at + 1] = u8(bits >> 8)
	out[at + 2] = u8(bits >> 16)
	out[at + 3] = u8(bits >> 24)
}

// pack_floats lays values out the way the Metal constant buffer reads them:
// matrix columns and float3 vectors are padded to 16 bytes.
fn pack_floats(ty Ty, values []f32) []u8 {
	mut out := []u8{len: ty.msl_size()}
	mut cols := 1
	mut rows := ty.comps()
	mut col_stride := ty.msl_size()
	if ty.mat_n() > 0 {
		cols = ty.mat_n()
		rows = cols
		col_stride = if cols == 2 { 8 } else { 16 }
	}
	for c in 0 .. cols {
		for r in 0 .. rows {
			put_u32(mut out, c * col_stride + r * 4, f32_bits(values[c * rows + r]))
		}
	}
	return out
}

pub fn (mut c Context) uniform_floats(loc int, values []f32) {
	mut p := c.current_linked() or {
		c.set_error(gl_invalid_operation)
		return
	}
	if loc == -1 {
		return
	}
	if loc < 0 || loc >= p.uniforms.len {
		c.set_error(gl_invalid_operation)
		return
	}
	ty := p.uniforms[loc].ty
	if !ty.is_float_based() {
		c.set_error(gl_invalid_operation)
		return
	}
	if values.len != ty.comps() {
		c.set_error(gl_invalid_value)
		return
	}
	p.uniform_data[loc] = pack_floats(ty, values)
}

pub fn (mut c Context) uniform_ints(loc int, values []int) {
	mut p := c.current_linked() or {
		c.set_error(gl_invalid_operation)
		return
	}
	if loc == -1 {
		return
	}
	if loc < 0 || loc >= p.uniforms.len
		|| (p.uniforms[loc].ty != .int_t && p.uniforms[loc].ty != .sampler2d) {
		c.set_error(gl_invalid_operation)
		return
	}
	if values.len != 1 {
		c.set_error(gl_invalid_value)
		return
	}
	// A sampler names a texture unit, which must exist.
	if p.uniforms[loc].ty == .sampler2d && (values[0] < 0 || values[0] >= max_texture_units) {
		c.set_error(gl_invalid_value)
		return
	}
	mut out := []u8{len: 4}
	put_u32(mut out, 0, u32(i32(values[0])))
	p.uniform_data[loc] = out
}

// uniform_matrix sets a float matrix uniform. GLES 2 requires transpose to be
// false, so a transposed upload is rejected.
pub fn (mut c Context) uniform_matrix(loc int, transpose bool, values []f32) {
	if transpose {
		c.set_error(gl_invalid_value)
		return
	}
	mut p := c.current_linked() or {
		c.set_error(gl_invalid_operation)
		return
	}
	if loc == -1 {
		return
	}
	if loc < 0 || loc >= p.uniforms.len || p.uniforms[loc].ty.mat_n() == 0 {
		c.set_error(gl_invalid_operation)
		return
	}
	ty := p.uniforms[loc].ty
	if values.len != ty.comps() {
		c.set_error(gl_invalid_value)
		return
	}
	p.uniform_data[loc] = pack_floats(ty, values)
}

// ---- Drawing --------------------------------------------------------------

// gl_primitive maps supported GL modes to MTLPrimitiveType values. Triangle
// fans and line loops have no Metal primitive and are rejected by the caller.
fn gl_primitive(mode u32) ?i32 {
	if mode == gl_points {
		return 0
	}
	if mode == gl_lines {
		return 1
	}
	if mode == gl_line_strip {
		return 2
	}
	if mode == gl_triangles {
		return 3
	}
	if mode == gl_triangle_strip {
		return 4
	}
	return none
}

pub const gl_unsigned_short = u32(0x1403)
pub const gl_unsigned_int = u32(0x1405)

// draw_arrays draws into the draw framebuffer with the current program. Each
// active attribute must be enabled and bound to a buffer large enough for the
// range; otherwise the call records GL_INVALID_OPERATION and draws nothing.
pub fn (mut c Context) draw_arrays(mode u32, first int, count int) {
	if first < 0 || count < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	c.draw_impl(mode, first, count, 0, 0)
}

// draw_elements draws count indices read from the bound ELEMENT_ARRAY_BUFFER
// starting offset bytes in. 8-bit indices are widened to 16 bits because Metal
// has no 8-bit index type; 32-bit indices are accepted as OES_element_index_uint
// would allow, and a WebGL layer is expected to gate them.
pub fn (mut c Context) draw_elements(mode u32, count int, typ u32, offset int) {
	if typ != gl_unsigned_byte && typ != gl_unsigned_short && typ != gl_unsigned_int {
		c.set_error(gl_invalid_enum)
		return
	}
	if count < 0 || offset < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	c.draw_impl(mode, 0, count, typ, offset)
}

fn index_size(typ u32) int {
	return match typ {
		gl_unsigned_byte { 1 }
		gl_unsigned_short { 2 }
		else { 4 }
	}
}

// draw_impl is the shared draw path; index_type 0 means a non-indexed draw.
fn (mut c Context) draw_impl(mode u32, first int, count int, index_type u32, index_offset int) {
	prim := gl_primitive(mode) or {
		if mode == gl_triangle_fan || mode == gl_line_loop {
			c.set_error(gl_invalid_operation)
		} else {
			c.set_error(gl_invalid_enum)
		}
		return
	}
	isz := if index_type == 0 { 0 } else { index_size(index_type) }
	if isz > 0 && index_offset % isz != 0 {
		c.set_error(gl_invalid_operation)
		return
	}
	mut p := c.current_linked() or {
		c.set_error(gl_invalid_operation)
		return
	}
	if count == 0 {
		return
	}
	target := c.resolve_target() or {
		c.set_error(gl_invalid_framebuffer_operation)
		return
	}
	// vertex_end is one past the highest vertex any attribute must supply.
	mut vertex_end := first + count
	mut index_handle := u32(0)
	mut temp_index := u32(0)
	if isz > 0 {
		name := c.bound_buffers[gl_element_array_buffer] or { 0 }
		if name == 0 || name !in c.buffers {
			c.set_error(gl_invalid_operation)
			return
		}
		ebo := c.buffers[name]
		if ebo.handle == 0 || index_offset + count * isz > ebo.size {
			c.set_error(gl_invalid_operation)
			return
		}
		raw := c.display.backend.read_buffer(ebo.handle, index_offset, count * isz) or {
			c.set_error(gl_out_of_memory)
			return
		}
		mut highest := u32(0)
		for i in 0 .. count {
			mut v := u32(0)
			for b in 0 .. isz {
				v |= u32(raw[i * isz + b]) << (8 * b)
			}
			if v > highest {
				highest = v
			}
		}
		vertex_end = int(highest) + 1
		if index_type == gl_unsigned_byte {
			mut wide := []u8{len: count * 2}
			for i in 0 .. count {
				wide[i * 2] = raw[i]
			}
			temp_index = c.display.backend.create_buffer(count * 2) or {
				c.set_error(gl_out_of_memory)
				return
			}
			c.display.backend.write_buffer(temp_index, 0, wide) or {
				c.display.backend.destroy_buffer(temp_index)
				c.set_error(gl_out_of_memory)
				return
			}
			index_handle = temp_index
		} else {
			index_handle = ebo.handle
		}
	}
	mut buffers := []u32{}
	mut offsets := []u32{}
	mut comps := []i32{}
	mut strides := []u32{}
	for a in p.attrs {
		ptr := c.attribs[a.loc]
		if !ptr.enabled || ptr.buffer == 0 || ptr.size != a.ty.comps() || ptr.buffer !in c.buffers {
			c.set_error(gl_invalid_operation)
			c.release_temp_index(temp_index)
			return
		}
		buf := c.buffers[ptr.buffer]
		stride := if ptr.stride == 0 { ptr.size * 4 } else { ptr.stride }
		need := ptr.offset + (vertex_end - 1) * stride + ptr.size * 4
		if buf.handle == 0 || need > buf.size {
			c.set_error(gl_invalid_operation)
			c.release_temp_index(temp_index)
			return
		}
		buffers << buf.handle
		offsets << u32(ptr.offset)
		comps << i32(a.ty.comps())
		strides << u32(stride)
	}
	mut key := c.blend_key() + '|'
	for i, n in comps {
		stride := strides[i]
		key += '${n}:${stride},'
	}
	pipeline := if key in p.pipelines {
		p.pipelines[key]
	} else {
		h := c.display.backend.create_pipeline(PipelineDesc{
			vs_lib:          p.vs_lib
			vs_fn:           'vs_entry'
			fs_lib:          p.fs_lib
			fs_fn:           'fs_entry'
			attr_components: comps
			attr_strides:    strides
			blend:           c.blend_codes()
			write_mask:      c.mask_bits()
		}) or {
			c.set_error(gl_invalid_operation)
			c.release_temp_index(temp_index)
			return
		}
		p.pipelines[key] = h
		h
	}
	// An empty viewport or scissor covers no pixel, so the draw has no effect.
	view, scis, visible := c.draw_rect(target)
	if !visible {
		c.release_temp_index(temp_index)
		return
	}
	textures, samplers := c.sampler_bindings(p, target) or {
		c.release_temp_index(temp_index)
		return
	}
	// A failed GPU submission has no closer GL error than INVALID_OPERATION.
	c.display.backend.draw(DrawDesc{
		target:       target.handle
		pipeline:     pipeline
		primitive:    prim
		start:        u32(first)
		count:        u32(count)
		buffers:      buffers
		offsets:      offsets
		uniforms:     p.uniform_data
		viewport:     view
		scissor:      scis
		textures:     textures
		samplers:     samplers
		blend_color:  [c.blend.color[0], c.blend.color[1], c.blend.color[2], c.blend.color[3]]
		index_buffer: index_handle
		index_type:   if isz == 4 { 2 } else if isz > 0 { 1 } else { 0 }
		index_offset: if index_type == gl_unsigned_byte { u32(0) } else { u32(index_offset) }
	}) or { c.set_error(gl_invalid_operation) }
	c.release_temp_index(temp_index)
}

fn (mut c Context) release_temp_index(handle u32) {
	if handle != 0 {
		c.display.backend.destroy_buffer(handle)
	}
}
