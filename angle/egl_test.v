// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

fn test_vulkan_backend_is_reported_unavailable() {
	if _ := new_backend(.vulkan) {
		assert false, 'Vulkan must not report a working backend before it is implemented'
	} else {
		assert err.msg().contains('Vulkan')
	}
}

fn test_egl_context_and_surface_lifecycle() {
	$if !macos {
		return
	}
	mut display := initialize_display(.metal) or { panic(err.msg()) }
	defer {
		display.terminate()
	}
	config := display.choose_config(egl_opengl_es3_bit) or { panic(err.msg()) }
	mut surface := display.create_pbuffer_surface(4, 3) or { panic(err.msg()) }
	mut context := display.create_context(config, 3) or { panic(err.msg()) }
	display.make_current(mut surface, mut context) or { panic(err.msg()) }
	assert voidptr(display.current()) == voidptr(context)
	assert display.get_error() == egl_success

	display.unbind()
	assert display.current() == unsafe { nil }
	display.destroy_context(mut context)
	display.destroy_surface(mut surface)
}

fn test_egl_rejects_invalid_requests_with_egl_codes() {
	$if !macos {
		return
	}
	mut display := initialize_display(.metal) or { panic(err.msg()) }
	defer {
		display.terminate()
	}
	config := display.choose_config(egl_opengl_es3_bit) or { panic(err.msg()) }

	display.create_context(config, 1) or {
		assert err.code() == egl_bad_attribute
		assert display.get_error() == egl_bad_attribute
		assert display.get_error() == egl_success
		return
	}
	assert false, 'OpenGL ES 1 must not be created'
}

fn test_egl_config_must_include_requested_version() {
	$if !macos {
		return
	}
	mut display := initialize_display(.metal) or { panic(err.msg()) }
	defer {
		display.terminate()
	}
	es2_only := Config{
		renderable_type: egl_opengl_es2_bit
	}
	display.create_context(es2_only, 3) or {
		assert err.code() == egl_bad_config
		return
	}
	assert false, 'an ES2-only config must not create an ES3 context'
}

fn test_egl_make_current_rejects_destroyed_objects() {
	$if !macos {
		return
	}
	mut display := initialize_display(.metal) or { panic(err.msg()) }
	defer {
		display.terminate()
	}
	config := display.choose_config(egl_opengl_es2_bit) or { panic(err.msg()) }
	mut surface := display.create_pbuffer_surface(2, 2) or { panic(err.msg()) }
	mut context := display.create_context(config, 2) or { panic(err.msg()) }
	display.destroy_context(mut context)
	display.make_current(mut surface, mut context) or {
		assert err.code() == egl_bad_context
		display.destroy_surface(mut surface)
		return
	}
	assert false, 'a destroyed context must not become current'
}

fn test_egl_terminated_display_rejects_new_objects() {
	$if !macos {
		return
	}
	mut display := initialize_display(.metal) or { panic(err.msg()) }
	display.terminate()
	display.create_pbuffer_surface(2, 2) or {
		assert err.code() == egl_not_initialized
		return
	}
	assert false, 'a terminated display must not create surfaces'
}
