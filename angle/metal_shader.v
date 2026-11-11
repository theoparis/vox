// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

$if macos {
	fn C.vox_angle_mtl_library_create(voidptr, voidptr, voidptr, i32) u32
	fn C.vox_angle_mtl_pipeline_create(voidptr, u32, voidptr, u32, voidptr, i32, voidptr, voidptr, i32, voidptr, i32, i32, voidptr, i32) u32
	fn C.vox_angle_mtl_draw(voidptr, u32, u32, i32, u32, u32, i32, voidptr, voidptr, i32, voidptr, voidptr, voidptr, voidptr, i32, voidptr, voidptr, voidptr, u32, i32, u32, u32, i32, i32, voidptr, i32, i32) i32
}

// bridge_log turns a fixed-size bridge log buffer into a message.
fn bridge_log(buf []u8) string {
	return unsafe { cstring_to_vstring(&char(buf.data)) }
}

pub fn (mut b MetalBackend) compile_library(source string) !u32 {
	$if macos {
		mut log := []u8{len: 1024}
		handle := C.vox_angle_mtl_library_create(b.context, source.str, log.data, 1024)
		if handle == 0 {
			msg := bridge_log(log)
			if msg.len == 0 {
				return error('Metal rejected the shader')
			}
			return error(msg)
		}
		return handle
	} $else {
		return error('the Metal backend requires macOS')
	}
}

pub fn (mut b MetalBackend) create_pipeline(desc PipelineDesc) !u32 {
	$if macos {
		mut log := []u8{len: 1024}
		handle := C.vox_angle_mtl_pipeline_create(b.context, desc.vs_lib, desc.vs_fn.str, desc.fs_lib,
			desc.fs_fn.str, i32(desc.attr_components.len), desc.attr_components.data, desc.attr_strides.data,
			i32(desc.blend.len), desc.blend.data, desc.write_mask, i32(desc.has_depth), log.data, 1024)
		if handle == 0 {
			msg := bridge_log(log)
			if msg.len == 0 {
				return error('Metal could not create the pipeline')
			}
			return error(msg)
		}
		return handle
	} $else {
		return error('the Metal backend requires macOS')
	}
}

pub fn (mut b MetalBackend) draw(desc DrawDesc) ! {
	$if macos {
		mut sizes := []u32{}
		mut bytes := []u8{}
		for u in desc.uniforms {
			sizes << u32(u.len)
			for x in u {
				bytes << x
			}
		}
		ok := C.vox_angle_mtl_draw(b.context, desc.target, desc.pipeline, desc.primitive, desc.start,
			desc.count, i32(desc.buffers.len), desc.buffers.data, desc.offsets.data, i32(sizes.len),
			sizes.data, bytes.data, desc.viewport.data, desc.scissor.data, i32(desc.textures.len),
			desc.textures.data, desc.samplers.data, desc.blend_color.data, desc.index_buffer,
			desc.index_type, desc.index_offset, desc.depth_texture, desc.depth_func, i32(desc.depth_write),
			desc.depth_range.data, desc.cull, i32(desc.front_ccw))
		if ok == 0 {
			return error('Metal draw failed')
		}
	} $else {
		return error('the Metal backend requires macOS')
	}
}

pub fn (mut b MetalBackend) release_object(handle u32) {
	$if macos {
		C.vox_angle_mtl_release(b.context, handle)
	}
}
