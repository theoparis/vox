/* Entry points whose C signature V cannot export directly. Included once into
 * the generated C of the angle module. */
#if defined(CUSTOM_DEFINE_vox_angle_capi) && !defined(VOX_ANGLE_CAPI_SHIM_H)
#define VOX_ANGLE_CAPI_SHIM_H
#include <stdint.h>

extern void vox_angle_tex_image_2d(unsigned target, int level, int internal_format, int width, int height,
                                   int border, uint64_t format_type, void *pixels);

extern void vox_angle_tex_sub_image_2d(unsigned target, int level, int x, int y, int width, int height,
                                       uint64_t format_type, void *pixels);

__attribute__((visibility("default")))
void glTexSubImage2D(unsigned target, int level, int x, int y, int width, int height, unsigned format,
                     unsigned type, const void *pixels)
{
    vox_angle_tex_sub_image_2d(target, level, x, y, width, height, ((uint64_t)format << 32) | type,
                               (void *)pixels);
}

__attribute__((visibility("default")))
void glTexImage2D(unsigned target, int level, int internal_format, int width, int height, int border,
                  unsigned format, unsigned type, const void *pixels)
{
    vox_angle_tex_image_2d(target, level, internal_format, width, height, border,
                           ((uint64_t)format << 32) | type, (void *)pixels);
}


extern void vox_angle_tex_image_2d_robust(unsigned target, int level, int internal_format, int width, int height,
                                          uint64_t border_buf, uint64_t format_type, void *pixels);
extern void vox_angle_tex_sub_image_2d_robust(uint64_t target_level, int x, int y, int width, int height,
                                              uint64_t format_type, int buf_size, void *pixels);
extern void vox_angle_read_pixels_robust(int x, int y, int width, int height, uint64_t format_type, int buf_size,
                                         void **outs);

__attribute__((visibility("default")))
void glTexImage2DRobustANGLE(unsigned target, int level, int internal_format, int width, int height, int border,
                             unsigned format, unsigned type, int buf_size, const void *pixels)
{
    vox_angle_tex_image_2d_robust(target, level, internal_format, width, height,
                                  ((uint64_t)(unsigned)buf_size << 32) | (unsigned)border,
                                  ((uint64_t)format << 32) | type, (void *)pixels);
}

__attribute__((visibility("default")))
void glTexSubImage2DRobustANGLE(unsigned target, int level, int x, int y, int width, int height, unsigned format,
                                unsigned type, int buf_size, const void *pixels)
{
    vox_angle_tex_sub_image_2d_robust(((uint64_t)target << 32) | (unsigned)level, x, y, width, height,
                                      ((uint64_t)format << 32) | type, buf_size, (void *)pixels);
}

__attribute__((visibility("default")))
void glReadPixelsRobustANGLE(int x, int y, int width, int height, unsigned format, unsigned type, int buf_size,
                             int *length, int *columns, int *rows, void *pixels)
{
    void *outs[4] = { length, columns, rows, pixels };
    vox_angle_read_pixels_robust(x, y, width, height, ((uint64_t)format << 32) | type, buf_size, outs);
}

#endif
