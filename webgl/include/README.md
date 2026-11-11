# Vendored EGL/GLES headers

Declarations only; the macOS build loads the libraries at run time
(`angle_dispatch_darwin.h`).

- `EGL/egl.h`, `EGL/eglext.h`, `EGL/eglplatform.h`, `GLES2/gl2.h`,
  `GLES2/gl2ext.h`, `GLES2/gl2platform.h`, `GLES3/gl3.h`, `GLES3/gl3platform.h`,
  `KHR/khrplatform.h`: Khronos registries (EGL-Registry and OpenGL-Registry,
  `api/`), Apache-2.0.
- `EGL/eglext_angle.h`, `GLES2/gl2ext_angle.h`: ANGLE `include/`, BSD-style
  license in `../ANGLE_LICENSE`.
