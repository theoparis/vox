// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Shader and program lifetime. GL defers deleting an object that is still in
// use: an attached shader, or the current program, lives until released.

fn (c &Context) shader_attached(name u32) bool {
	for _, p in c.programs {
		if p.vertex == name || p.fragment == name {
			return true
		}
	}
	return false
}

// reap_shader frees a deleted shader once no program holds it.
fn (mut c Context) reap_shader(name u32) {
	if name == 0 || name !in c.shaders {
		return
	}
	if c.shaders[name].deleted && !c.shader_attached(name) {
		c.shaders.delete(name)
	}
}

// free_program releases a program's Metal libraries and pipelines and drops
// the references it held on its shaders.
fn (mut c Context) free_program(name u32) {
	mut p := c.programs[name]
	c.release_program_libraries(mut p)
	vertex := p.vertex
	fragment := p.fragment
	c.programs.delete(name)
	c.reap_shader(vertex)
	c.reap_shader(fragment)
}

pub fn (mut c Context) delete_shader(name u32) {
	if name == 0 {
		return
	}
	if name !in c.shaders {
		c.set_error(gl_invalid_value)
		return
	}
	if c.shader_attached(name) {
		mut s := c.shaders[name]
		s.deleted = true
		return
	}
	c.shaders.delete(name)
}

pub fn (mut c Context) delete_program(name u32) {
	if name == 0 {
		return
	}
	if name !in c.programs {
		c.set_error(gl_invalid_value)
		return
	}
	if c.current_program == name {
		mut p := c.programs[name]
		p.deleted = true
		return
	}
	c.free_program(name)
}

pub fn (mut c Context) detach_shader(prog u32, shader u32) {
	if prog !in c.programs || shader !in c.shaders {
		c.set_error(gl_invalid_value)
		return
	}
	mut p := c.programs[prog]
	if p.vertex == shader {
		p.vertex = 0
	} else if p.fragment == shader {
		p.fragment = 0
	} else {
		c.set_error(gl_invalid_operation)
		return
	}
	c.reap_shader(shader)
}

// use_program installs a program, then frees the previous one when it was
// deleted while current.
pub fn (mut c Context) use_program(prog u32) {
	previous := c.current_program
	c.use_program_raw(prog)
	if previous != 0 && previous != c.current_program && previous in c.programs
		&& c.programs[previous].deleted {
		c.free_program(previous)
	}
}

// ---- glIs* ---------------------------------------------------------------
// Buffers, textures and framebuffers exist from generation here, whereas GL
// reports them only after their first bind; callers that care (WebGL) track
// that themselves.

pub fn (c &Context) is_buffer(name u32) bool {
	return name != 0 && name in c.buffers
}

pub fn (c &Context) is_texture(name u32) bool {
	return name != 0 && name in c.textures
}

pub fn (c &Context) is_framebuffer(name u32) bool {
	return name != 0 && name in c.framebuffers
}

pub fn (c &Context) is_shader(name u32) bool {
	return name != 0 && name in c.shaders
}

pub fn (c &Context) is_program(name u32) bool {
	return name != 0 && name in c.programs
}

pub fn (c &Context) is_enabled(cap u32) bool {
	return (cap == gl_scissor_test && c.scissor_test) || (cap == gl_blend && c.blend_enabled)
		|| (cap == gl_depth_test && c.depth.test) || (cap == gl_cull_face_cap && c.depth.cull)
		|| c.extra_capability(cap)
}
