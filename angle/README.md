# angle: EGL and GLES on V, translating to Metal

A V replacement for the ANGLE layer that WebGL uses. It implements EGL 1.5
contexts and surfaces, a GLES 2 subset, and a GLSL ES 1.00 to Metal Shading
Language translator. A backend interface keeps Vulkan possible later.

## Layers

- `egl.v`: displays, configs, pbuffer surfaces, contexts, `make_current`
  (including the surfaceless form WebGL uses), termination, EGL error codes.
- `gl.v`, `gl_state.v`, `gl_objects.v`, `gl_query.v`: GLES state. First-error
  semantics, buffers, RGBA8 textures, color-attachment framebuffers, clears,
  `read_pixels`, viewport, scissor, enable/disable, shader and program lifetime,
  and the `glGet*` and `glIs*` queries.
- `gl_vao.v`: vertex array objects; the bound array's pointers live in the
  context so draws read them directly, and binding swaps the stored copy.
- `gl_misc.v`, `gl_introspect.v`: hints, line width, polygon offset, pixel
  storage, stencil state, generic (constant) vertex attributes, program and
  shader parameters, active attribute/uniform queries, `glBindAttribLocation`
  and the parameter getters.
- `gl_depth.v`: depth buffer and test, `glDepthRange`, face culling, and depth
  renderbuffers. Surfaces and framebuffers with a depth renderbuffer carry a
  32-bit float depth texture.
- `gl_blend.v`: blend function, equation, constant color and color write mask,
  baked into the Metal pipeline and its cache key.
- `gl_texture.v`: texture units, sampler parameters, `glTexSubImage2D`, texture
  completeness, and the per-draw resolution of `sampler2D` uniforms.
- `gl_shader.v`: shader and program objects, uniforms, vertex attributes,
  `draw_arrays`, and a per-program pipeline cache.
- `glsl_*.v`: GLSL ES 1.00 lexer, parser, checker, MSL emitter and link planner.
  `plan_link` is pure, so it is tested without a GPU.
- `backend.v`: the `Backend` interface. The GL and EGL state machines validate
  every call; a backend only executes validated work. `new_backend(.vulkan)`
  reports not implemented.
- `metal.v`, `metal_shader.v`, `metal_bridge_darwin.m`: the Metal backend. The
  Objective-C file only issues GPU calls; no GL state lives there.
- `capi.v`, `capi_shader.v`, `capi_state.v`, `capi_shim.h`: the C ABI for the
  shared library (see below).

## Status

Implemented: EGL contexts and pbuffers; GLES 2 buffers, RGBA8 textures,
framebuffers, clears, read-back, viewport, scissor; blending and color mask; depth test, face culling and depth
renderbuffers; instanced draws and vertex arrays; mipmaps; `glDrawElements` with 8/16/32-bit indices;
eight texture units with
filter and wrap parameters; GLSL ES 1.00 shaders with attributes, uniforms,
varyings, float/vector/matrix types, and `sampler2D` with `texture2D` in
fragment shaders; `GL_TRIANGLES`
and `GL_TRIANGLE_STRIP` draws.

## Limits

- Shaders: samplers are fragment-stage uniforms only (no vertex texture fetch,
  sampler locals, parameters or arrays), no `texture2DProj`/`Lod`, no
  `out`/`inout` parameters, no `discard`, no arrays, no preprocessor directives other than `#version 100`,
  no matrix attributes. ES 3.0 is refused at `#version` and at context creation.
- Textures: RGBA8 2D textures. Only level 0 can be defined; `glGenerateMipmap`
  builds the chain (power-of-two sizes only, as in GLES 2) by reallocating the
  texture with levels. A mipmap minification filter without a chain, or on a
  non-power-of-two texture, makes the texture incomplete: it samples as opaque
  black, as does a non-power-of-two texture that is not clamped. Redefining
  level 0 discards the chain. Sampling
  the texture being rendered to is `INVALID_OPERATION`. `glTexSubImage2D` reads
  back and re-uploads the whole image until the backend gains a region upload.
- Stencil: there is no stencil buffer. `glStencil*` validate their enums and
  `GL_STENCIL_TEST` can be enabled, but nothing is stored or applied: with no
  stencil buffer the test passes, as GL specifies. The config reports stencil size 0,
  clearing the stencil bit is a no-op, and stencil or DEPTH_STENCIL renderbuffer
  formats and attachments return `INVALID_OPERATION`. Color renderbuffers and
  depth textures are not implemented either.
- `glLineWidth` stores the width, but Metal draws one-pixel lines, which is
  also the reported range. Sample coverage and dither are tracked, not applied.
- Integer and bool uniform vectors do not exist in the shader subset, so
  `glUniform{2,3,4}i[v]` always report `INVALID_OPERATION`. `glCopyTexImage2D`
  reads the framebuffer through the CPU; compressed formats are `INVALID_ENUM`.
- Draws: float attributes only; no non-RGBA formats, transform feedback, queries or sync objects.
- Clear with the scissor test enabled (or a partial color mask for a color
  clear) returns `INVALID_OPERATION`: a Metal load-action clear ignores both, and a masked fill
  does not exist yet.
- `glEnable`/`glDisable` accept `GL_SCISSOR_TEST`, `GL_BLEND`, `GL_DEPTH_TEST`
  and `GL_CULL_FACE`. `GL_CULL_FACE` with `FRONT_AND_BACK` skips triangle draws.
- Clip z is remapped from GL's [-w, w] to Metal's [0, w] in the vertex wrapper,
  and `glDepthRange` is the Metal viewport's depth range.
- 8-bit indices are widened to 16 bits per draw (Metal has no 8-bit type);
  32-bit indices are accepted without an extension check, which a WebGL layer
  must gate. Index buffers are scanned on the CPU to bounds-check attributes.
- `glIsBuffer`, `glIsTexture` and `glIsFramebuffer` report true from generation,
  not from first bind. WebGL tracks that itself.
- The Metal shader bridge functions are compiled only on macOS; other hosts
  return errors.

## Conventions

- Handles are nonzero and never reused within a backend.
- GL keeps the first pending error; EGL keeps the last code until read.
- Row order matches `glReadPixels`: row y of the window is memory row y. The
  emitted vertex wrapper negates `gl_Position.y`, so NDC +1 lands on the last
  memory row. Metal's row 0 is not the top of the texture, so no other flip is
  needed for either FBO textures or the default surface.
- Unsupported-but-valid GL requests return `GL_INVALID_OPERATION` with a comment
  at the site, never a silent partial result.

## C ABI (shared library)

`capi*.v` exports the core as `libEGL`/`libGLESv2`-style C symbols: 161 of the
241 that `webgl/angle_dispatch_darwin.h` lists. Build and check with

    sh tools/test_angle_capi.sh

which builds `-d vox_angle_capi -shared` with the C backend (`fastc` cannot build
shared libraries) and runs `capi_smoke.c`, a `dlopen` client. It creates a
surfaceless context, compiles and links GLSL, draws a triangle into a framebuffer
texture, reads the pixels back, and checks a shader info log.

Notes:

- EGL handles are small integers; GL acts on one process-wide current context.
- V's export wrappers mishandle more than eight parameters, so `glTexImage2D`
  is a small C shim (`capi_shim.h`) forwarding to an 8-parameter V export.
- **WebGL still uses ANGLE.** `webgl/angle_dispatch_darwin.h` requires all 241
  symbols to resolve, and the remaining 80 (queries, sync, transform feedback,
  instancing, ES 3 entry points, and the ANGLE extensions) are not exported yet,
  so this library cannot be selected there.
