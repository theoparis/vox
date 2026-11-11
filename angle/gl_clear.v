// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Clears that a Metal load action cannot express: a scissor rectangle, a
// partial color write mask or a partial stencil write mask. They are drawn as a
// full-target quad instead, so the usual per-pixel rules apply. The quad
// writes the clear color, the clear depth as its depth, and the clear stencil
// value with a REPLACE operation under the stencil write mask.

const clear_source = '#include <metal_stdlib>
using namespace metal;
struct ClearVertex { float4 position [[position]]; };
vertex ClearVertex clear_vs(uint vid [[vertex_id]], constant float &depth [[buffer(1)]]) {
	float2 corners[4] = { float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0, 1.0), float2(1.0, 1.0) };
	ClearVertex out;
	out.position = float4(corners[vid], depth, 1.0);
	return out;
}
fragment float4 clear_fs(constant float4 &color [[buffer(0)]]) {
	return color;
}
'

fn (mut c Context) release_clear_pipelines() {
	for _, p in c.clear_pipelines {
		c.display.backend.release_object(p)
	}
	c.clear_pipelines = map[string]u32{}
	if c.clear_library != 0 {
		c.display.backend.release_object(c.clear_library)
		c.clear_library = 0
	}
}

fn (mut c Context) clear_pipeline(color_mask i32, has_depth bool) ?u32 {
	if c.clear_library == 0 {
		c.clear_library = c.display.backend.compile_library(clear_source) or { return none }
	}
	key := '${color_mask}:${has_depth}'
	if key in c.clear_pipelines {
		return c.clear_pipelines[key]
	}
	p := c.display.backend.create_pipeline(PipelineDesc{
		vs_lib:     c.clear_library
		vs_fn:      'clear_vs'
		fs_lib:     c.clear_library
		fs_fn:      'clear_fs'
		write_mask: color_mask
		has_depth:  has_depth
	}) or { return none }
	c.clear_pipelines[key] = p
	return p
}

// clear_with_quad performs a clear of the selected planes through the scissor
// rectangle and write masks. An empty scissor clears nothing.
fn (mut c Context) clear_with_quad(target RenderTarget, color bool, depth bool, stencil bool) {
	mut rect := [i32(0), 0, i32(target.width), i32(target.height)]
	if c.scissor_test {
		x0 := max_int(c.scissor_rect[0], 0)
		y0 := max_int(c.scissor_rect[1], 0)
		x1 := min_int(c.scissor_rect[0] + c.scissor_rect[2], target.width)
		y1 := min_int(c.scissor_rect[1] + c.scissor_rect[3], target.height)
		if x1 <= x0 || y1 <= y0 {
			return
		}
		rect = [i32(x0), i32(y0), i32(x1 - x0), i32(y1 - y0)]
	}
	mask := if color { c.mask_bits() } else { i32(0) }
	has_depth := target.depth != 0
	pipeline := c.clear_pipeline(mask, has_depth) or {
		c.set_error(gl_out_of_memory)
		return
	}
	mut stencil_codes := []i32{}
	if stencil {
		face := [i32(7), i32(c.misc.clear_stencil & 0xFF), 0xFF, i32(c.stencil.front.write & 0xFF), 2,
			2, 2]
		stencil_codes << face
		stencil_codes << face
	}
	mut color_bytes := []u8{cap: 16}
	for v in c.clear_color {
		color_bytes << f32_bytes_of([v])
	}
	c.display.backend.draw(DrawDesc{
		target:        target.handle
		pipeline:      pipeline
		primitive:     4
		start:         0
		count:         4
		uniforms:      [color_bytes, f32_bytes_of([c.depth.clear_value])]
		viewport:      [i32(0), 0, i32(target.width), i32(target.height)]
		scissor:       rect
		blend_color:   [f32(0), 0, 0, 0]
		instances:     1
		depth_texture: if has_depth { target.depth } else { u32(0) }
		depth_func:    if depth { i32(7) } else { i32(-1) }
		depth_write:   depth
		depth_range:   [f32(0), 1]
		depth_bias:    [f32(0), 0]
		stencil:       stencil_codes
	}) or { c.set_error(gl_invalid_operation) }
}
