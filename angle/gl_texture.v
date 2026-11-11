// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Texture units, sampler parameters, sub-image updates, and the texture
// resolution a draw performs for sampler2D uniforms.

pub fn (mut c Context) active_texture(unit u32) {
	if unit < gl_texture0 || unit >= gl_texture0 + u32(max_texture_units) {
		c.set_error(gl_invalid_enum)
		return
	}
	c.active_unit = int(unit - gl_texture0)
}

fn is_min_filter(v u32) bool {
	return v == gl_nearest || v == gl_linear || v == gl_nearest_mipmap_nearest
		|| v == gl_linear_mipmap_nearest || v == gl_nearest_mipmap_linear
		|| v == gl_linear_mipmap_linear
}

fn is_wrap_mode(v u32) bool {
	return v == gl_repeat || v == gl_clamp_to_edge || v == gl_mirrored_repeat
}

// tex_parameteri sets a sampler parameter on the texture bound to the active
// unit. Mipmap minification filters are accepted and stored; because level 0
// is the only level, a texture using one is incomplete and samples as black,
// exactly as GL specifies for a texture without its mipmap chain.
pub fn (mut c Context) tex_parameteri(target u32, pname u32, value int) {
	if target != gl_texture_2d {
		c.set_error(gl_invalid_enum)
		return
	}
	if pname != gl_texture_min_filter && pname != gl_texture_mag_filter
		&& pname != gl_texture_wrap_s && pname != gl_texture_wrap_t {
		c.set_error(gl_invalid_enum)
		return
	}
	name := c.texture_units[c.active_unit]
	if name == 0 {
		c.set_error(gl_invalid_operation)
		return
	}
	v := u32(value)
	valid := match pname {
		gl_texture_min_filter { is_min_filter(v) }
		gl_texture_mag_filter { v == gl_nearest || v == gl_linear }
		else { is_wrap_mode(v) }
	}
	if !valid {
		c.set_error(gl_invalid_enum)
		return
	}
	mut t := c.textures[name]
	match pname {
		gl_texture_min_filter { t.min_filter = v }
		gl_texture_mag_filter { t.mag_filter = v }
		gl_texture_wrap_s { t.wrap_s = v }
		else { t.wrap_t = v }
	}
	c.textures[name] = t
}

// tex_sub_image_2d replaces a rectangle of level 0 of the bound texture. The
// backend has no region upload yet, so the whole image is read back, patched,
// and uploaded again.
pub fn (mut c Context) tex_sub_image_2d(target u32, level int, x int, y int, width int, height int, format u32, typ u32, pixels []u8) {
	if target != gl_texture_2d {
		c.set_error(gl_invalid_enum)
		return
	}
	if format != gl_rgba || typ != gl_unsigned_byte {
		c.set_error(gl_invalid_operation)
		return
	}
	name := c.texture_units[c.active_unit]
	if name == 0 {
		c.set_error(gl_invalid_operation)
		return
	}
	t := c.textures[name]
	if level != 0 || x < 0 || y < 0 || width < 0 || height < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	if t.handle == 0 {
		// Level 0 is undefined, so any rectangle lies outside it.
		if width == 0 || height == 0 {
			return
		}
		c.set_error(gl_invalid_value)
		return
	}
	if x + width > t.width || y + height > t.height || pixels.len != width * height * 4 {
		c.set_error(gl_invalid_value)
		return
	}
	if width == 0 || height == 0 {
		return
	}
	mut image := c.display.backend.read_texture(t.handle, t.width, t.height) or {
		c.set_error(gl_out_of_memory)
		return
	}
	for row in 0 .. height {
		dst := ((y + row) * t.width + x) * 4
		src := row * width * 4
		for i in 0 .. width * 4 {
			image[dst + i] = pixels[src + i]
		}
	}
	c.display.backend.upload_texture(t.handle, t.width, t.height, image) or {
		c.set_error(gl_out_of_memory)
	}
}

fn (t &GLTexture) is_pot() bool {
	return t.width > 0 && t.height > 0 && (t.width & (t.width - 1)) == 0
		&& (t.height & (t.height - 1)) == 0
}

fn is_mipmap_filter(v u32) bool {
	return v != gl_nearest && v != gl_linear
}

// is_complete follows the GLES 2 sampling rules for a texture with only
// level 0: it needs storage, a non-mipmap minification filter, and, when its
// size is not a power of two, clamp-to-edge wrapping.
fn (t &GLTexture) is_complete() bool {
	if t.handle == 0 || is_mipmap_filter(t.min_filter) {
		return false
	}
	if !t.is_pot() && (t.wrap_s != gl_clamp_to_edge || t.wrap_t != gl_clamp_to_edge) {
		return false
	}
	return true
}

fn sampler_filter(v u32) i32 {
	return if v == gl_nearest || v == gl_nearest_mipmap_nearest || v == gl_nearest_mipmap_linear {
		0
	} else {
		1
	}
}

fn sampler_wrap(v u32) i32 {
	return match v {
		gl_clamp_to_edge { 1 }
		gl_mirrored_repeat { 2 }
		else { 0 }
	}
}

// black_handle lazily creates the opaque black texture that stands in for an
// incomplete texture.
fn (mut c Context) black_handle() ?u32 {
	if c.black_texture == 0 {
		h := c.display.backend.create_texture(1, 1) or { return none }
		c.display.backend.upload_texture(h, 1, 1, [u8(0), 0, 0, 255]) or {
			c.display.backend.destroy_texture(h)
			return none
		}
		c.black_texture = h
	}
	return c.black_texture
}

// sampler_bindings resolves every sampler2D uniform of the program to a
// backend texture and sampler state, indexed by uniform slot. Slots that are
// not samplers hold texture 0. It reports false after recording the GL error
// when a draw is invalid, such as sampling the texture being rendered to.
fn (mut c Context) sampler_bindings(p &Program, target RenderTarget) ?([]u32, []i32) {
	mut textures := []u32{len: p.uniforms.len}
	mut params := []i32{len: p.uniforms.len * 4}
	for i, u in p.uniforms {
		if u.ty != .sampler2d {
			continue
		}
		unit := int(get_u32(p.uniform_data[i], 0))
		if unit < 0 || unit >= max_texture_units {
			c.set_error(gl_invalid_operation)
			return none
		}
		name := c.texture_units[unit]
		t := if name != 0 { c.textures[name] } else { GLTexture{} }
		if t.handle != 0 && t.handle == target.handle {
			c.set_error(gl_invalid_operation)
			return none
		}
		if t.is_complete() {
			textures[i] = t.handle
			params[i * 4] = sampler_filter(t.min_filter)
			params[i * 4 + 1] = sampler_filter(t.mag_filter)
			params[i * 4 + 2] = sampler_wrap(t.wrap_s)
			params[i * 4 + 3] = sampler_wrap(t.wrap_t)
		} else {
			black := c.black_handle() or {
				c.set_error(gl_out_of_memory)
				return none
			}
			textures[i] = black
			params[i * 4 + 1] = 0
			params[i * 4 + 2] = 1
			params[i * 4 + 3] = 1
		}
	}
	return textures, params
}

// read_region copies a width x height rectangle of the read framebuffer's color
// attachment. Pixels outside the framebuffer read as transparent black.
fn (mut c Context) read_region(x int, y int, width int, height int) ?[]u8 {
	target := c.resolve_target() or {
		c.set_error(gl_invalid_framebuffer_operation)
		return none
	}
	full := c.display.backend.read_texture(target.handle, target.width, target.height) or {
		c.set_error(gl_out_of_memory)
		return none
	}
	mut out := []u8{len: width * height * 4}
	for row in 0 .. height {
		sy := y + row
		if sy < 0 || sy >= target.height {
			continue
		}
		for col in 0 .. width {
			sx := x + col
			if sx < 0 || sx >= target.width {
				continue
			}
			for i in 0 .. 4 {
				out[(row * width + col) * 4 + i] = full[(sy * target.width + sx) * 4 + i]
			}
		}
	}
	return out
}

// copy_tex_image_2d defines level 0 of the bound texture from the read
// framebuffer. The framebuffer is read through the CPU.
pub fn (mut c Context) copy_tex_image_2d(target u32, level int, internal_format u32, x int, y int, width int, height int, border int) {
	if target != gl_texture_2d {
		c.set_error(gl_invalid_enum)
		return
	}
	if level < 0 || width < 0 || height < 0 || border != 0 {
		c.set_error(gl_invalid_value)
		return
	}
	if level != 0 || internal_format != gl_rgba {
		c.set_error(gl_invalid_operation)
		return
	}
	pixels := c.read_region(x, y, width, height) or { return }
	c.tex_image_2d(target, level, internal_format, width, height, gl_rgba, gl_unsigned_byte,
		pixels)
}

pub fn (mut c Context) copy_tex_sub_image_2d(target u32, level int, xoffset int, yoffset int, x int, y int, width int, height int) {
	if target != gl_texture_2d {
		c.set_error(gl_invalid_enum)
		return
	}
	if width < 0 || height < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	pixels := c.read_region(x, y, width, height) or { return }
	c.tex_sub_image_2d(target, level, xoffset, yoffset, width, height, gl_rgba, gl_unsigned_byte,
		pixels)
}

// compressed_tex_image_2d: no compressed format is supported, so every format
// is an invalid enum, as in a context that exposes no compression extension.
pub fn (mut c Context) compressed_tex_image_2d(target u32, level int, format u32) {
	c.set_error(gl_invalid_enum)
}
