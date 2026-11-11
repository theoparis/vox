// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// GLES 2/3 enums and error codes used by the implemented subset.
pub const gl_no_error = u32(0)
pub const gl_invalid_enum = u32(0x0500)
pub const gl_invalid_value = u32(0x0501)
pub const gl_invalid_operation = u32(0x0502)
pub const gl_out_of_memory = u32(0x0505)
pub const gl_invalid_framebuffer_operation = u32(0x0506)
pub const gl_depth_buffer_bit = u32(0x0100)
pub const gl_stencil_buffer_bit = u32(0x0400)
pub const gl_color_buffer_bit = u32(0x4000)
pub const gl_texture_2d = u32(0x0de1)
pub const gl_rgba = u32(0x1908)
pub const gl_texture0 = u32(0x84c0)
pub const gl_active_texture = u32(0x84e0)
pub const gl_texture_mag_filter = u32(0x2800)
pub const gl_texture_min_filter = u32(0x2801)
pub const gl_texture_wrap_s = u32(0x2802)
pub const gl_texture_wrap_t = u32(0x2803)
pub const gl_nearest = u32(0x2600)
pub const gl_linear = u32(0x2601)
pub const gl_nearest_mipmap_nearest = u32(0x2700)
pub const gl_linear_mipmap_nearest = u32(0x2701)
pub const gl_nearest_mipmap_linear = u32(0x2702)
pub const gl_linear_mipmap_linear = u32(0x2703)
pub const gl_repeat = u32(0x2901)
pub const gl_clamp_to_edge = u32(0x812f)
pub const gl_mirrored_repeat = u32(0x8370)

// Texture units a fragment shader can sample. Vertex texture fetch is not
// supported, so MAX_VERTEX_TEXTURE_IMAGE_UNITS is 0.
pub const max_texture_units = 8
pub const gl_unsigned_byte = u32(0x1401)
pub const gl_array_buffer = u32(0x8892)
pub const gl_element_array_buffer = u32(0x8893)
pub const gl_stream_draw = u32(0x88e0)
pub const gl_static_draw = u32(0x88e4)
pub const gl_dynamic_draw = u32(0x88e8)
pub const gl_framebuffer = u32(0x8d40)
pub const gl_read_framebuffer = u32(0x8ca8)
pub const gl_draw_framebuffer = u32(0x8ca9)
pub const gl_color_attachment0 = u32(0x8ce0)
pub const gl_framebuffer_complete = u32(0x8cd5)
pub const gl_framebuffer_incomplete_attachment = u32(0x8cd6)
pub const gl_framebuffer_incomplete_missing_attachment = u32(0x8cd7)
pub const gl_framebuffer_incomplete_dimensions = u32(0x8cd9)
pub const gl_framebuffer_unsupported = u32(0x8cdd)

// GLBuffer and GLTexture pair a GL name with its backend resource. A zero
// handle means the name exists but has no storage allocated yet.
struct GLBuffer {
mut:
	handle u32
	size   int
	usage  u32 = gl_static_draw
}

struct GLTexture {
mut:
	handle u32
	width  int
	height int
	// Sampler parameters live on the texture object and survive redefinition.
	min_filter u32 = gl_nearest_mipmap_linear
	mag_filter u32 = gl_linear
	wrap_s     u32 = gl_repeat
	wrap_t     u32 = gl_repeat
	// mipmapped is true when glGenerateMipmap built a chain for the current
	// level 0. Redefining level 0 discards it.
	mipmapped bool
}

struct GLFramebuffer {
mut:
	color_texture u32
	depth_rb      u32
	stencil_rb    u32
}

// GLRenderbuffer is a depth buffer; handle is 0 until storage is allocated.
struct GLRenderbuffer {
mut:
	handle u32
	width  int
	height int
	format u32 = gl_depth_component16
}

// has_depth and has_stencil say which planes the format provides.
fn (r &GLRenderbuffer) has_depth() bool {
	return r.format != gl_stencil_index8
}

fn (r &GLRenderbuffer) has_stencil() bool {
	return r.format == gl_stencil_index8 || r.format == gl_depth24_stencil8 || r.format == gl_depth_stencil_format
}

// Context is one OpenGL ES context. It owns the GL object namespace and the
// bindings; backend resources are released through its display.
@[heap]
pub struct Context {
pub:
	version int
mut:
	display            &Display = unsafe { nil }
	surface            &Surface = unsafe { nil }
	destroyed          bool
	error              u32
	next_name          u32 = 1
	clear_color        [4]f32
	buffers            map[u32]GLBuffer
	textures           map[u32]GLTexture
	framebuffers       map[u32]GLFramebuffer
	renderbuffers      map[u32]GLRenderbuffer
	bound_renderbuffer u32
	depth              DepthState
	misc               MiscState
	stencil            StencilState
	attrib_consts      [16]AttribConst
	vaos               map[u32]VertexArray
	default_vao        VertexArray
	bound_vao          u32
	bound_buffers      map[u32]u32
	texture_units      [8]u32
	active_unit        int
	// black_texture is the 1x1 texture an incomplete sampled texture reads as.
	black_texture     u32
	bound_framebuffer u32
	shaders           map[u32]&Shader
	programs          map[u32]&Program
	current_program   u32
	attribs           [16]AttribPointer
	viewport          [4]int
	scissor_rect      [4]int
	scissor_test      bool
	blend_enabled     bool
	blend             BlendState
	default_state_set bool
}

// RenderTarget is the resolved color attachment of the draw framebuffer.
struct RenderTarget {
	handle u32
	width  int
	height int
	// depth is the combined depth/stencil texture, or 0 when the target has
	// neither plane; has_depth and has_stencil say which planes exist.
	depth       u32
	has_depth   bool
	has_stencil bool
}

// set_error keeps only the first pending error, as GL does.
fn (mut c Context) set_error(code u32) {
	if c.error == gl_no_error {
		c.error = code
	}
}

// get_error returns the pending error and clears it.
pub fn (mut c Context) get_error() u32 {
	code := c.error
	c.error = gl_no_error
	return code
}

fn (mut c Context) new_name() u32 {
	name := c.next_name
	c.next_name++
	return name
}

// release_all frees every backend resource this context created. Surfaces
// belong to the display and are released by destroy_surface.
fn (mut c Context) release_all() {
	for _, buffer in c.buffers {
		if buffer.handle != 0 {
			c.display.backend.destroy_buffer(buffer.handle)
		}
	}
	for _, texture in c.textures {
		if texture.handle != 0 {
			c.display.backend.destroy_texture(texture.handle)
		}
	}
	for name, _ in c.programs {
		mut p := c.programs[name] or { continue }
		c.release_program_libraries(mut p)
	}
	c.shaders = map[u32]&Shader{}
	c.programs = map[u32]&Program{}
	c.current_program = 0
	c.buffers = map[u32]GLBuffer{}
	c.textures = map[u32]GLTexture{}
	for _, rb in c.renderbuffers {
		if rb.handle != 0 {
			c.display.backend.destroy_texture(rb.handle)
		}
	}
	c.vaos = map[u32]VertexArray{}
	c.default_vao = VertexArray{}
	c.bound_vao = 0
	c.renderbuffers = map[u32]GLRenderbuffer{}
	c.bound_renderbuffer = 0
	c.framebuffers = map[u32]GLFramebuffer{}
	c.bound_buffers = map[u32]u32{}
	if c.black_texture != 0 {
		c.display.backend.destroy_texture(c.black_texture)
		c.black_texture = 0
	}
	c.texture_units = [8]u32{}
	c.active_unit = 0
	c.bound_framebuffer = 0
}

// ---- Buffers -------------------------------------------------------------

pub fn (mut c Context) gen_buffer() u32 {
	name := c.new_name()
	c.buffers[name] = GLBuffer{}
	return name
}

// bind_buffer binds a buffer name; an unseen nonzero name creates the object.
pub fn (mut c Context) bind_buffer(target u32, name u32) {
	if target != gl_array_buffer && target != gl_element_array_buffer {
		c.set_error(gl_invalid_enum)
		return
	}
	if name != 0 && name !in c.buffers {
		c.buffers[name] = GLBuffer{}
	}
	c.bound_buffers[target] = name
}

// bound_buffer resolves the named buffer bound to target, with GL's error
// when the target is invalid or unbound.
fn (mut c Context) bound_buffer(target u32) ?u32 {
	if target != gl_array_buffer && target != gl_element_array_buffer {
		c.set_error(gl_invalid_enum)
		return none
	}
	name := c.bound_buffers[target] or { 0 }
	if name == 0 {
		c.set_error(gl_invalid_operation)
		return none
	}
	return name
}

// buffer_data replaces the bound buffer's storage. An empty data slice means
// no initial data; the contents are then zero rather than undefined.
pub fn (mut c Context) buffer_data(target u32, size int, data []u8, usage u32) {
	if usage != gl_stream_draw && usage != gl_static_draw && usage != gl_dynamic_draw {
		c.set_error(gl_invalid_enum)
		return
	}
	if size < 0 || (data.len != 0 && data.len != size) {
		c.set_error(gl_invalid_value)
		return
	}
	name := c.bound_buffer(target) or { return }
	mut buffer := c.buffers[name]
	if buffer.handle != 0 {
		c.display.backend.destroy_buffer(buffer.handle)
		buffer.handle = 0
	}
	handle := c.display.backend.create_buffer(size) or {
		c.set_error(gl_out_of_memory)
		c.buffers[name] = GLBuffer{}
		return
	}
	if size > 0 {
		payload := if data.len == 0 { []u8{len: size} } else { data }
		c.display.backend.write_buffer(handle, 0, payload) or {
			c.display.backend.destroy_buffer(handle)
			c.set_error(gl_out_of_memory)
			c.buffers[name] = GLBuffer{}
			return
		}
	}
	c.buffers[name] = GLBuffer{
		handle: handle
		size:   size
		usage:  usage
	}
}

pub fn (mut c Context) buffer_sub_data(target u32, offset int, data []u8) {
	name := c.bound_buffer(target) or { return }
	buffer := c.buffers[name]
	if offset < 0 || offset + data.len > buffer.size {
		c.set_error(gl_invalid_value)
		return
	}
	if data.len == 0 {
		return
	}
	c.display.backend.write_buffer(buffer.handle, offset, data) or {
		c.set_error(gl_out_of_memory)
		return
	}
}

// get_buffer_sub_data reads a byte range of the bound buffer. Errors return
// an empty slice and record the GL error.
pub fn (mut c Context) get_buffer_sub_data(target u32, offset int, size int) []u8 {
	name := c.bound_buffer(target) or { return []u8{} }
	buffer := c.buffers[name]
	if offset < 0 || size < 0 || offset + size > buffer.size {
		c.set_error(gl_invalid_value)
		return []u8{}
	}
	return c.display.backend.read_buffer(buffer.handle, offset, size) or {
		c.set_error(gl_out_of_memory)
		return []u8{}
	}
}

pub fn (mut c Context) delete_buffer(name u32) {
	if name == 0 || name !in c.buffers {
		return
	}
	buffer := c.buffers[name]
	if buffer.handle != 0 {
		c.display.backend.destroy_buffer(buffer.handle)
	}
	c.buffers.delete(name)
	for target, bound in c.bound_buffers {
		if bound == name {
			c.bound_buffers[target] = 0
		}
	}
}

// ---- Textures ------------------------------------------------------------

pub fn (mut c Context) gen_texture() u32 {
	name := c.new_name()
	c.textures[name] = GLTexture{}
	return name
}

pub fn (mut c Context) bind_texture(target u32, name u32) {
	if target != gl_texture_2d {
		c.set_error(gl_invalid_enum)
		return
	}
	if name != 0 && name !in c.textures {
		c.textures[name] = GLTexture{}
	}
	c.texture_units[c.active_unit] = name
}

// tex_image_2d defines level 0 of the bound 2D texture. Only RGBA with
// unsigned bytes is implemented; other formats report INVALID_OPERATION.
pub fn (mut c Context) tex_image_2d(target u32, level int, internal_format u32, width int, height int, format u32, typ u32, pixels []u8) {
	if target != gl_texture_2d {
		c.set_error(gl_invalid_enum)
		return
	}
	if level < 0 || width < 0 || height < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	if level != 0 || internal_format != gl_rgba || format != gl_rgba || typ != gl_unsigned_byte {
		c.set_error(gl_invalid_operation)
		return
	}
	expected := width * height * 4
	if pixels.len != 0 && pixels.len != expected {
		c.set_error(gl_invalid_value)
		return
	}
	name := c.texture_units[c.active_unit]
	if name == 0 {
		c.set_error(gl_invalid_operation)
		return
	}
	mut texture := c.textures[name]
	if texture.handle != 0 {
		c.display.backend.destroy_texture(texture.handle)
	}
	texture.handle = 0
	texture.width = 0
	texture.height = 0
	texture.mipmapped = false
	c.textures[name] = texture
	if width == 0 || height == 0 {
		return
	}
	handle := c.display.backend.create_texture(width, height) or {
		c.set_error(gl_out_of_memory)
		return
	}
	payload := if pixels.len == 0 { []u8{len: expected} } else { pixels }
	c.display.backend.upload_texture(handle, width, height, payload) or {
		c.display.backend.destroy_texture(handle)
		c.set_error(gl_out_of_memory)
		return
	}
	texture.handle = handle
	texture.width = width
	texture.height = height
	c.textures[name] = texture
}

pub fn (mut c Context) delete_texture(name u32) {
	if name == 0 || name !in c.textures {
		return
	}
	texture := c.textures[name]
	if texture.handle != 0 {
		c.display.backend.destroy_texture(texture.handle)
	}
	c.textures.delete(name)
	for unit in 0 .. max_texture_units {
		if c.texture_units[unit] == name {
			c.texture_units[unit] = 0
		}
	}
}

// ---- Framebuffers --------------------------------------------------------

pub fn (mut c Context) gen_framebuffer() u32 {
	name := c.new_name()
	c.framebuffers[name] = GLFramebuffer{}
	return name
}

pub fn (mut c Context) bind_framebuffer(target u32, name u32) {
	if target != gl_framebuffer && target != gl_read_framebuffer && target != gl_draw_framebuffer {
		c.set_error(gl_invalid_enum)
		return
	}
	if name != 0 && name !in c.framebuffers {
		c.framebuffers[name] = GLFramebuffer{}
	}
	c.bound_framebuffer = name
}

// framebuffer_texture_2d attaches a texture to COLOR_ATTACHMENT0 of the bound
// framebuffer. Other attachments are not implemented yet.
pub fn (mut c Context) framebuffer_texture_2d(target u32, attachment u32, textarget u32, texture u32, level int) {
	if target != gl_framebuffer && target != gl_read_framebuffer && target != gl_draw_framebuffer {
		c.set_error(gl_invalid_enum)
		return
	}
	if textarget != gl_texture_2d {
		c.set_error(gl_invalid_enum)
		return
	}
	if c.bound_framebuffer == 0 {
		c.set_error(gl_invalid_operation)
		return
	}
	if attachment != gl_color_attachment0 {
		c.set_error(gl_invalid_operation)
		return
	}
	if level != 0 {
		c.set_error(gl_invalid_value)
		return
	}
	if texture != 0 && texture !in c.textures {
		c.set_error(gl_invalid_operation)
		return
	}
	mut framebuffer := c.framebuffers[c.bound_framebuffer]
	framebuffer.color_texture = texture
	c.framebuffers[c.bound_framebuffer] = framebuffer
}

pub fn (mut c Context) delete_framebuffer(name u32) {
	if name == 0 || name !in c.framebuffers {
		return
	}
	c.framebuffers.delete(name)
	if c.bound_framebuffer == name {
		c.bound_framebuffer = 0
	}
}

// resolve_target returns the color attachment that clear and readback use.
// The default framebuffer is the current surface's color buffer.
fn (mut c Context) resolve_target() ?RenderTarget {
	if c.bound_framebuffer == 0 {
		if c.surface == unsafe { nil } || c.surface.destroyed {
			return none
		}
		return RenderTarget{
			handle:      c.surface.texture
			width:       c.surface.width
			height:      c.surface.height
			depth:       c.surface.depth
			has_depth:   true
			has_stencil: true
		}
	}
	framebuffer := c.framebuffers[c.bound_framebuffer] or { return none }
	if framebuffer.color_texture == 0 {
		return none
	}
	texture := c.textures[framebuffer.color_texture] or { return none }
	if texture.handle == 0 {
		return none
	}
	mut depth := u32(0)
	mut has_depth := false
	mut has_stencil := false
	if framebuffer.depth_rb != 0 {
		rb := c.renderbuffers[framebuffer.depth_rb] or { return none }
		if rb.handle == 0 || rb.width != texture.width || rb.height != texture.height
			|| !rb.has_depth() {
			return none
		}
		depth = rb.handle
		has_depth = true
		has_stencil = framebuffer.stencil_rb == framebuffer.depth_rb
	}
	if framebuffer.stencil_rb != 0 && framebuffer.stencil_rb != framebuffer.depth_rb {
		// A separate stencil renderbuffer is only usable without a depth one.
		if framebuffer.depth_rb != 0 {
			return none
		}
		rb := c.renderbuffers[framebuffer.stencil_rb] or { return none }
		if rb.handle == 0 || rb.width != texture.width || rb.height != texture.height
			|| !rb.has_stencil() {
			return none
		}
		depth = rb.handle
		has_stencil = true
	}
	return RenderTarget{
		handle:      texture.handle
		width:       texture.width
		height:      texture.height
		depth:       depth
		has_depth:   has_depth
		has_stencil: has_stencil
	}
}

// check_framebuffer_status reports the completeness of the bound framebuffer.
pub fn (mut c Context) check_framebuffer_status(target u32) u32 {
	if target != gl_framebuffer && target != gl_read_framebuffer && target != gl_draw_framebuffer {
		c.set_error(gl_invalid_enum)
		return 0
	}
	if c.bound_framebuffer == 0 {
		if c.surface == unsafe { nil } || c.surface.destroyed {
			return gl_framebuffer_incomplete_missing_attachment
		}
		return gl_framebuffer_complete
	}
	framebuffer := c.framebuffers[c.bound_framebuffer] or {
		return gl_framebuffer_incomplete_missing_attachment
	}
	if framebuffer.color_texture == 0 {
		return gl_framebuffer_incomplete_missing_attachment
	}
	texture := c.textures[framebuffer.color_texture] or {
		return gl_framebuffer_incomplete_missing_attachment
	}
	if texture.handle == 0 {
		return gl_framebuffer_incomplete_attachment
	}
	if framebuffer.depth_rb != 0 {
		rb := c.renderbuffers[framebuffer.depth_rb] or { return gl_framebuffer_incomplete_attachment }
		if rb.handle == 0 || !rb.has_depth() {
			return gl_framebuffer_incomplete_attachment
		}
		if rb.width != texture.width || rb.height != texture.height {
			return gl_framebuffer_incomplete_dimensions
		}
	}
	if framebuffer.stencil_rb != 0 {
		rb := c.renderbuffers[framebuffer.stencil_rb] or { return gl_framebuffer_incomplete_attachment }
		if rb.handle == 0 || !rb.has_stencil() {
			return gl_framebuffer_incomplete_attachment
		}
		if rb.width != texture.width || rb.height != texture.height {
			return gl_framebuffer_incomplete_dimensions
		}
		// One texture backs both planes, so depth and stencil must share it.
		if framebuffer.depth_rb != 0 && framebuffer.depth_rb != framebuffer.stencil_rb {
			return gl_framebuffer_unsupported
		}
	}
	return gl_framebuffer_complete
}

// ---- Clears and readback -------------------------------------------------

pub fn (mut c Context) set_clear_color(r f32, g f32, b f32, a f32) {
	c.clear_color = [r, g, b, a]!
}

// clear fills the whole color and/or depth attachment. A Metal load-action
// clear ignores the scissor rectangle and the color mask, so such a clear is
// refused as a whole until a masked fill exists; refusing is explicit, never
// partial. The default framebuffer has no stencil buffer, and clearing a
// buffer that does not exist is a no-op in GL, so the stencil bit is accepted.
pub fn (mut c Context) clear(mask u32) {
	known := gl_color_buffer_bit | gl_depth_buffer_bit | gl_stencil_buffer_bit
	if mask & ~known != 0 {
		c.set_error(gl_invalid_value)
		return
	}
	want_color := mask & gl_color_buffer_bit != 0
	want_depth := mask & gl_depth_buffer_bit != 0
	want_stencil := mask & gl_stencil_buffer_bit != 0
	if !want_color && !want_depth && !want_stencil {
		return
	}
	target := c.resolve_target() or {
		c.set_error(gl_invalid_framebuffer_operation)
		return
	}
	// A plane the target lacks is ignored. A stencil clear honors the write
	// mask, which a load-action clear cannot do for a partial mask.
	do_depth := want_depth && target.has_depth && c.depth.write_enabled()
	front_mask := c.stencil.front.write & 0xFF
	do_stencil := want_stencil && target.has_stencil && front_mask != 0
	partial_stencil := do_stencil && front_mask != 0xFF
	if c.scissor_test || (want_color && !c.blend.full_mask()) || partial_stencil {
		c.set_error(gl_invalid_operation)
		return
	}
	if want_color {
		c.display.backend.clear_texture(target.handle, c.clear_color[0], c.clear_color[1],
			c.clear_color[2], c.clear_color[3]) or {
			c.set_error(gl_out_of_memory)
			return
		}
	}
	planes := (if do_depth { 1 } else { 0 }) | (if do_stencil { 2 } else { 0 })
	if planes != 0 {
		c.display.backend.clear_depth_stencil(target.depth, c.depth.clear_value, u8(c.misc.clear_stencil & 0xFF),
			planes) or {
			c.set_error(gl_out_of_memory)
			return
		}
	}
}

// read_pixels returns RGBA8 rows starting at y, in GL window order. Rows are
// stored in the same order as the texture's memory, so no vertical flip is
// applied here; the caller's origin matches glReadPixels.
pub fn (mut c Context) read_pixels(x int, y int, width int, height int, format u32, typ u32) []u8 {
	if format != gl_rgba || typ != gl_unsigned_byte {
		c.set_error(gl_invalid_operation)
		return []u8{}
	}
	if width < 0 || height < 0 {
		c.set_error(gl_invalid_value)
		return []u8{}
	}
	target := c.resolve_target() or {
		c.set_error(gl_invalid_framebuffer_operation)
		return []u8{}
	}
	if x < 0 || y < 0 || x + width > target.width || y + height > target.height {
		c.set_error(gl_invalid_value)
		return []u8{}
	}
	full := c.display.backend.read_texture(target.handle, target.width, target.height) or {
		c.set_error(gl_out_of_memory)
		return []u8{}
	}
	mut out := []u8{cap: width * height * 4}
	row_bytes := target.width * 4
	for row in y .. y + height {
		start := row * row_bytes + x * 4
		out << full[start..start + width * 4]
	}
	return out
}

// new_context creates the GL state for an EGL context. Each context starts
// with the default framebuffer bound and no GL objects.
fn new_context(display &Display, version int) &Context {
	return &Context{
		version:  version
		display:  display
		shaders:  map[u32]&Shader{}
		programs: map[u32]&Program{}
	}
}
