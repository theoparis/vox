// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Backend is the only boundary to native GPU resources. The EGL and GLES
// state machines validate every call before reaching it, so a backend only
// has to execute already-validated work. Handles are nonzero and opaque.
pub interface Backend {
	name() string
mut:
	create_texture(width int, height int) !u32
	upload_texture(texture u32, width int, height int, pixels []u8) !
	clear_texture(texture u32, r f32, g f32, b f32, a f32) !
	read_texture(texture u32, width int, height int) ![]u8
	destroy_texture(texture u32)
	create_buffer(size int) !u32
	write_buffer(buffer u32, offset int, data []u8) !
	read_buffer(buffer u32, offset int, size int) ![]u8
	destroy_buffer(buffer u32)
	// compile_library builds a shader library from translated source. The
	// error carries the native compiler's message.
	compile_library(source string) !u32
	// create_pipeline builds a render pipeline. Attribute i reads from its
	// own vertex buffer slot with the given component count and stride.
	create_pipeline(desc PipelineDesc) !u32
	// draw renders triangles or lines into a texture without blending.
	draw(desc DrawDesc) !
	// release_object frees a library or pipeline created by this backend.
	release_object(handle u32)
	close()
}

// PipelineDesc names two entry points and the vertex layout they consume.
pub struct PipelineDesc {
pub:
	vs_lib          u32
	vs_fn           string
	fs_lib          u32
	fs_fn           string
	attr_components []i32
	attr_strides    []u32
}

// DrawDesc is one validated draw. primitive uses the Metal MTLPrimitiveType
// numbering. uniforms are passed to both stages at their buffer index.
pub struct DrawDesc {
pub:
	target    u32
	pipeline  u32
	primitive i32
	start     u32
	count     u32
	buffers   []u32
	offsets   []u32
	uniforms  [][]u8
	// viewport and scissor are {x, y, width, height} in GL window coordinates,
	// already clipped to the target. The scissor always covers the draw.
	viewport []i32
	scissor  []i32
}

pub enum BackendKind {
	metal
	vulkan
}

// new_backend selects a translation target. Vulkan is reserved for the
// future backend and is reported as unavailable until it is implemented.
pub fn new_backend(kind BackendKind) !Backend {
	return match kind {
		.metal { new_metal_backend()! }
		.vulkan { return error('the Vulkan backend is not implemented yet') }
	}
}
