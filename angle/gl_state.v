// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// Viewport and scissor state. Rectangles use GL window coordinates, with y = 0
// at the bottom of the draw target. Row y of the target is memory row y, so
// these rectangles need no conversion before they reach Metal.

// gl_scissor_test is the capability enabled by glEnable(GL_SCISSOR_TEST).
pub const gl_scissor_test = u32(0x0C11)

// viewport sets the viewport rectangle used by subsequent draws.
pub fn (mut c Context) viewport(x int, y int, width int, height int) {
	if width < 0 || height < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	c.viewport[0] = x
	c.viewport[1] = y
	c.viewport[2] = width
	c.viewport[3] = height
}

// scissor sets the scissor rectangle. It takes effect only with the scissor
// test enabled, but a negative size is an error either way.
pub fn (mut c Context) scissor(x int, y int, width int, height int) {
	if width < 0 || height < 0 {
		c.set_error(gl_invalid_value)
		return
	}
	c.scissor_rect[0] = x
	c.scissor_rect[1] = y
	c.scissor_rect[2] = width
	c.scissor_rect[3] = height
}

// enable turns on a capability. The scissor test and blending are supported.
pub fn (mut c Context) enable(cap u32) {
	c.set_capability(cap, true)
}

// disable turns off a capability.
pub fn (mut c Context) disable(cap u32) {
	c.set_capability(cap, false)
}

fn (mut c Context) set_capability(cap u32, on bool) {
	match cap {
		gl_scissor_test { c.scissor_test = on }
		gl_blend { c.blend_enabled = on }
		else { c.set_error(gl_invalid_enum) }
	}
}

// reset_surface_state gives a context its initial viewport and scissor, which
// cover the whole surface. GL sets these once, when the context first becomes
// current; later rebinding keeps the values the application set.
fn (mut c Context) reset_surface_state(width int, height int) {
	if c.default_state_set {
		return
	}
	c.default_state_set = true
	c.viewport = [0, 0, width, height]!
	c.scissor_rect = [0, 0, width, height]!
}

// draw_rect returns the viewport and the effective scissor rectangle for a
// draw into target, both clipped as the GPU requires. ok is false when the
// draw cannot cover any pixel, so the caller skips it without error.
fn (c &Context) draw_rect(target RenderTarget) ([]i32, []i32, bool) {
	vx, vy, vw, vh := c.viewport[0], c.viewport[1], c.viewport[2], c.viewport[3]
	if vw == 0 || vh == 0 {
		return []i32{}, []i32{}, false
	}
	mut sx := 0
	mut sy := 0
	mut sw := target.width
	mut sh := target.height
	if c.scissor_test {
		x0 := max_int(c.scissor_rect[0], 0)
		y0 := max_int(c.scissor_rect[1], 0)
		x1 := min_int(c.scissor_rect[0] + c.scissor_rect[2], target.width)
		y1 := min_int(c.scissor_rect[1] + c.scissor_rect[3], target.height)
		if x1 <= x0 || y1 <= y0 {
			return []i32{}, []i32{}, false
		}
		sx = x0
		sy = y0
		sw = x1 - x0
		sh = y1 - y0
	}
	mut view := []i32{len: 4}
	view[0] = i32(vx)
	view[1] = i32(vy)
	view[2] = i32(vw)
	view[3] = i32(vh)
	mut scis := []i32{len: 4}
	scis[0] = i32(sx)
	scis[1] = i32(sy)
	scis[2] = i32(sw)
	scis[3] = i32(sh)
	return view, scis, true
}

fn max_int(a int, b int) int {
	return if a > b { a } else { b }
}

fn min_int(a int, b int) int {
	return if a < b { a } else { b }
}
