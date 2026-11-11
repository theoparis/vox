// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

$if macos {
	#flag darwin -framework Foundation -framework Metal
	#flag darwin @DIR/metal_bridge_darwin.m
	// The header is the one declaration both sides of the bridge compile against.
	#include "@DIR/metal_bridge.h"
}

fn C.vox_angle_mtl_context_create() voidptr
fn C.vox_angle_mtl_context_destroy(voidptr)
fn C.vox_angle_mtl_device_name(voidptr) &char
fn C.vox_angle_mtl_release(voidptr, u32)
fn C.vox_angle_mtl_buffer_create(voidptr, i64) u32
fn C.vox_angle_mtl_buffer_write(voidptr, u32, i64, voidptr, i64) int
fn C.vox_angle_mtl_buffer_read(voidptr, u32, i64, voidptr, i64) int
fn C.vox_angle_mtl_texture_create(voidptr, int, int) u32
fn C.vox_angle_mtl_texture_clear(voidptr, u32, f32, f32, f32, f32) int
fn C.vox_angle_mtl_texture_upload(voidptr, u32, int, int, voidptr) int
fn C.vox_angle_mtl_texture_read(voidptr, u32, int, int, voidptr) int

// MetalBackend translates validated GL resource operations to Metal on the
// system default device. Its shader and pipeline work is added separately.
pub struct MetalBackend {
mut:
	context voidptr
}

// new_metal_backend fails on hosts without a Metal device, so callers can
// report WebGL unavailable instead of entering a partial state.
pub fn new_metal_backend() !&MetalBackend {
	$if macos {
		context := C.vox_angle_mtl_context_create()
		if context == unsafe { nil } {
			return error('no Metal device is available')
		}
		return &MetalBackend{
			context: context
		}
	} $else {
		return error('the Metal backend requires macOS')
	}
}

pub fn (b &MetalBackend) name() string {
	$if macos {
		return 'metal:' + unsafe { cstring_to_vstring(C.vox_angle_mtl_device_name(b.context)) }
	} $else {
		return 'metal:unavailable'
	}
}

pub fn (mut b MetalBackend) create_texture(width int, height int) !u32 {
	$if macos {
		if width <= 0 || height <= 0 {
			return error('texture dimensions must be positive')
		}
		handle := C.vox_angle_mtl_texture_create(b.context, width, height)
		if handle == 0 {
			return error('Metal texture allocation failed')
		}
		return handle
	} $else {
		return error('the Metal backend requires macOS')
	}
}

pub fn (mut b MetalBackend) upload_texture(texture u32, width int, height int, pixels []u8) ! {
	$if macos {
		if pixels.len != width * height * 4 {
			return error('texture upload has the wrong byte count')
		}
		if C.vox_angle_mtl_texture_upload(b.context, texture, width, height, pixels.data) == 0 {
			return error('Metal texture upload failed')
		}
	} $else {
		return error('the Metal backend requires macOS')
	}
}

pub fn (mut b MetalBackend) clear_texture(texture u32, r f32, g f32, b_ f32, a f32) ! {
	$if macos {
		if C.vox_angle_mtl_texture_clear(b.context, texture, r, g, b_, a) == 0 {
			return error('Metal clear failed')
		}
	} $else {
		return error('the Metal backend requires macOS')
	}
}

pub fn (mut b MetalBackend) read_texture(texture u32, width int, height int) ![]u8 {
	$if macos {
		mut pixels := []u8{len: width * height * 4}
		if C.vox_angle_mtl_texture_read(b.context, texture, width, height, pixels.data) == 0 {
			return error('Metal texture readback failed')
		}
		return pixels
	} $else {
		return error('the Metal backend requires macOS')
	}
}

pub fn (mut b MetalBackend) destroy_texture(texture u32) {
	$if macos {
		C.vox_angle_mtl_release(b.context, texture)
	}
}

pub fn (mut b MetalBackend) create_buffer(size int) !u32 {
	$if macos {
		if size < 0 {
			return error('buffer size must not be negative')
		}
		handle := C.vox_angle_mtl_buffer_create(b.context, i64(size))
		if handle == 0 {
			return error('Metal buffer allocation failed')
		}
		return handle
	} $else {
		return error('the Metal backend requires macOS')
	}
}

pub fn (mut b MetalBackend) write_buffer(buffer u32, offset int, data []u8) ! {
	$if macos {
		if data.len == 0 {
			return
		}
		if C.vox_angle_mtl_buffer_write(b.context, buffer, i64(offset), data.data, i64(data.len)) == 0 {
			return error('Metal buffer write is out of range')
		}
	} $else {
		return error('the Metal backend requires macOS')
	}
}

pub fn (mut b MetalBackend) read_buffer(buffer u32, offset int, size int) ![]u8 {
	$if macos {
		mut data := []u8{len: size}
		if size > 0 && C.vox_angle_mtl_buffer_read(b.context, buffer, i64(offset), data.data, i64(size)) == 0 {
			return error('Metal buffer read is out of range')
		}
		return data
	} $else {
		return error('the Metal backend requires macOS')
	}
}

pub fn (mut b MetalBackend) destroy_buffer(buffer u32) {
	$if macos {
		C.vox_angle_mtl_release(b.context, buffer)
	}
}

pub fn (mut b MetalBackend) close() {
	$if macos {
		if b.context != unsafe { nil } {
			C.vox_angle_mtl_context_destroy(b.context)
			b.context = unsafe { nil }
		}
	}
}
