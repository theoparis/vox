/* Entry points whose C signature V cannot export directly. Included once into
 * the generated C of the angle module. */
#if defined(CUSTOM_DEFINE_vox_angle_capi) && !defined(VOX_ANGLE_CAPI_SHIM_H)
#define VOX_ANGLE_CAPI_SHIM_H
#include <stdint.h>

extern void vox_angle_tex_image_2d(unsigned target, int level, int internal_format, int width, int height,
                                   int border, uint64_t format_type, void *pixels);

__attribute__((visibility("default")))
void glTexImage2D(unsigned target, int level, int internal_format, int width, int height, int border,
                  unsigned format, unsigned type, const void *pixels)
{
    vox_angle_tex_image_2d(target, level, internal_format, width, height, border,
                           ((uint64_t)format << 32) | type, (void *)pixels);
}

#endif
