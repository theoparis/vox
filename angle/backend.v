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
	// create_depth_texture makes a 32-bit float depth attachment; destroy it
	// with destroy_texture.
	create_depth_texture(width int, height int) !u32
	clear_depth(texture u32, depth f32) !
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
	// attr_constant[i] is 1 when attribute i reads one constant value instead of
	// advancing per vertex.
	attr_constant []i32
	// blend is empty when blending is off, otherwise six values: source and
	// destination factor for RGB then alpha (0 zero, 1 one, 2 src color, 3 one
	// minus src color, 4 dst color, 5 one minus dst color, 6 src alpha, 7 one
	// minus src alpha, 8 dst alpha, 9 one minus dst alpha, 10 constant color,
	// 11 one minus constant color, 12 constant alpha, 13 one minus constant
	// alpha, 14 src alpha saturate), then the RGB and alpha equations (0 add,
	// 1 subtract, 2 reverse subtract).
	blend []i32
	// write_mask has R=1, G=2, B=4, A=8.
	write_mask i32 = 15
	// has_depth is true when the draw target has a depth attachment.
	has_depth bool
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
	// textures holds, per uniform slot, the texture a sampler2D reads (0 for
	// non-samplers); samplers holds four values per slot: minification and
	// magnification filter (0 nearest, 1 linear), then S and T wrap (0 repeat,
	// 1 clamp to edge, 2 mirrored repeat).
	textures []u32
	samplers []i32
	// blend_color is the constant blend color {r, g, b, a}.
	blend_color []f32
	// index_buffer is 0 for a plain draw. Otherwise count indices of
	// index_type (1 for 16-bit, 2 for 32-bit) are read from it at index_offset
	// bytes, and start is ignored.
	index_buffer u32
	index_type   i32
	index_offset u32
	// depth_texture is 0 without a depth attachment. depth_func is -1 with the
	// depth test off, else a comparison (0 never, 1 less, 2 equal, 3 less or
	// equal, 4 greater, 5 not equal, 6 greater or equal, 7 always).
	depth_texture u32
	depth_func    i32 = -1
	depth_write   bool
	// depth_range is {near, far} for the viewport transform of window z.
	depth_range []f32
	// cull is 0 none, 1 front, 2 back; front_ccw says counter-clockwise
	// triangles (in GL window coordinates, y up) are front-facing.
	cull      i32
	front_ccw bool
	// depth_bias is {units, slope factor} from glPolygonOffset, or {0, 0}.
	depth_bias []f32
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
