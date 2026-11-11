/* Copyright (c) 2026, Ladybird contributors
 * SPDX-License-Identifier: BSD-2-Clause
 * C interface of the Metal GPU bridge (metal_bridge_darwin.m). Handles are
 * opaque: a context pointer and nonzero resource ids that are never reused.
 */
#ifndef VOX_ANGLE_METAL_BRIDGE_H
#define VOX_ANGLE_METAL_BRIDGE_H

void *vox_angle_mtl_context_create(void);
void vox_angle_mtl_context_destroy(void *context);
const char *vox_angle_mtl_device_name(void *context);
void vox_angle_mtl_release(void *context, unsigned resource);
unsigned vox_angle_mtl_buffer_create(void *context, long long size);
int vox_angle_mtl_buffer_write(void *context, unsigned buffer, long long offset, const void *bytes, long long size);
int vox_angle_mtl_buffer_read(void *context, unsigned buffer, long long offset, void *bytes, long long size);
unsigned vox_angle_mtl_texture_create(void *context, int width, int height);
int vox_angle_mtl_texture_clear(void *context, unsigned texture, float r, float g, float b, float a);
int vox_angle_mtl_texture_upload(void *context, unsigned texture, int width, int height, const void *pixels);
int vox_angle_mtl_texture_read(void *context, unsigned texture, int width, int height, void *pixels);

/* Shader libraries are compiled from MSL source; log receives the compiler message on failure. */
unsigned vox_angle_mtl_library_create(void *context, const char *source, char *log, int log_size);
/* Attribute i uses vertex buffer slot 16 + i; components is 1 to 4 floats. */
unsigned vox_angle_mtl_pipeline_create(void *context, unsigned vs_library, const char *vs_entry,
                                       unsigned fs_library, const char *fs_entry, int attr_count,
                                       const int *components, const unsigned *strides, char *log, int log_size);
/* textures[i] (0 for none) is bound to fragment texture and sampler slot i; sampler_params holds
 * four ints per slot: min filter, mag filter (0 nearest, 1 linear), wrap S, wrap T (0 repeat,
 * 1 clamp to edge, 2 mirrored repeat).
 * Uniform i is bound to buffer index i in both stages; uniform_bytes holds them back to back.
 * viewport and scissor are {x, y, width, height} in GL window coordinates; row y of the
 * GL window is row y of the texture, so they pass through unchanged. */
int vox_angle_mtl_draw(void *context, unsigned target, unsigned pipeline, int primitive, unsigned start,
                       unsigned count, int attr_count, const unsigned *buffers, const unsigned *offsets,
                       int uniform_count, const unsigned *uniform_sizes, const unsigned char *uniform_bytes,
                       const int *viewport, const int *scissor, int texture_count,
                       const unsigned *textures, const int *sampler_params);

#endif
