/* Copyright (c) 2026, Ladybird contributors
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * ES 3 and ANGLE entry points that do not exist on an ES 2 context. Each records
 * GL_INVALID_OPERATION (GL_INVALID_ENUM for compressed formats, which are not
 * supported) and returns a failure value. Included once into the generated C of
 * the angle module for the shared-library build; V cannot export entry points
 * with more than eight parameters, and these need only their C signature. */
#if defined(CUSTOM_DEFINE_vox_angle_capi) && !defined(VOX_ANGLE_CAPI_ES3_SHIM_H)
#define VOX_ANGLE_CAPI_ES3_SHIM_H

extern void vox_angle_unsupported(void);
extern void vox_angle_invalid_enum(void);

__attribute__((visibility("default")))
void glBeginQuery(unsigned target, unsigned id)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glEndQuery(unsigned target)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glGenQueries(int n, unsigned *ids)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glDeleteQueries(int n, const unsigned *ids)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glGetQueryObjectuivRobustANGLE(unsigned id, unsigned pname, int buf_size, int *length, unsigned *params)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glBeginTransformFeedback(unsigned mode)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glEndTransformFeedback(void)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glPauseTransformFeedback(void)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glResumeTransformFeedback(void)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glGenTransformFeedbacks(int n, unsigned *ids)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glDeleteTransformFeedbacks(int n, const unsigned *ids)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glBindTransformFeedback(unsigned target, unsigned id)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glTransformFeedbackVaryings(unsigned program, int count, const char *const *varyings, unsigned mode)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glBindBufferBase(unsigned target, unsigned index, unsigned buffer)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glBindBufferRange(unsigned target, unsigned index, unsigned buffer, long offset, long size)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glBindSampler(unsigned unit, unsigned sampler)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glGenSamplers(int n, unsigned *samplers)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glDeleteSamplers(int n, const unsigned *samplers)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glSamplerParameterf(unsigned sampler, unsigned pname, float param)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glSamplerParameteri(unsigned sampler, unsigned pname, int param)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glGetSamplerParameterfvRobustANGLE(unsigned sampler, unsigned pname, int buf_size, int *length, float *params)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void * glFenceSync(unsigned condition, unsigned flags)
{
    vox_angle_unsupported();
    return 0;
}

__attribute__((visibility("default")))
unsigned glClientWaitSync(void *sync, unsigned flags, unsigned long long timeout)
{
    vox_angle_unsupported();
    return 0x911D;
}

__attribute__((visibility("default")))
void glDeleteSync(void *sync)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glWaitSync(void *sync, unsigned flags, unsigned long long timeout)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glGetSynciv(void *sync, unsigned pname, int count, int *length, int *values)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glClearBufferfi(unsigned buffer, int drawbuffer, float depth, int stencil)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glClearBufferfv(unsigned buffer, int drawbuffer, const float *value)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glClearBufferiv(unsigned buffer, int drawbuffer, const int *value)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glClearBufferuiv(unsigned buffer, int drawbuffer, const unsigned *value)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glBlitFramebuffer(int sx0, int sy0, int sx1, int sy1, int dx0, int dy0, int dx1, int dy1, unsigned mask, unsigned filter)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glFramebufferTextureLayer(unsigned target, unsigned attachment, unsigned texture, int level, int layer)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glTexStorage2D(unsigned target, int levels, unsigned internal_format, int width, int height)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glTexStorage3D(unsigned target, int levels, unsigned internal_format, int width, int height, int depth)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glTexImage3DRobustANGLE(unsigned target, int level, int internal_format, int width, int height, int depth, int border, unsigned format, unsigned type, int buf_size, const void *pixels)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glTexSubImage3DRobustANGLE(unsigned target, int level, int xoffset, int yoffset, int zoffset, int width, int height, int depth, unsigned format, unsigned type, int buf_size, const void *pixels)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glCompressedTexImage3D(unsigned target, int level, unsigned internal_format, int width, int height, int depth, int border, int image_size, const void *data)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glCompressedTexSubImage3D(unsigned target, int level, int xoffset, int yoffset, int zoffset, int width, int height, int depth, unsigned format, int image_size, const void *data)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glCompressedTexSubImage2D(unsigned target, int level, int xoffset, int yoffset, int width, int height, unsigned format, int image_size, const void *data)
{
    vox_angle_invalid_enum();
}

__attribute__((visibility("default")))
void glCopyBufferSubData(unsigned read_target, unsigned write_target, long read_offset, long write_offset, long size)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void * glMapBufferRange(unsigned target, long offset, long length, unsigned access)
{
    vox_angle_unsupported();
    return 0;
}

__attribute__((visibility("default")))
unsigned char glUnmapBuffer(unsigned target)
{
    vox_angle_unsupported();
    return 0;
}

__attribute__((visibility("default")))
void glUniform1ui(int location, unsigned v0)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniform2ui(int location, unsigned v0, unsigned v1)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniform3ui(int location, unsigned v0, unsigned v1, unsigned v2)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniform4ui(int location, unsigned v0, unsigned v1, unsigned v2, unsigned v3)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniform1uiv(int location, int count, const unsigned *value)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniform2uiv(int location, int count, const unsigned *value)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniform3uiv(int location, int count, const unsigned *value)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniform4uiv(int location, int count, const unsigned *value)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniformMatrix2x3fv(int location, int count, unsigned char transpose, const float *value)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniformMatrix2x4fv(int location, int count, unsigned char transpose, const float *value)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniformMatrix3x2fv(int location, int count, unsigned char transpose, const float *value)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniformMatrix3x4fv(int location, int count, unsigned char transpose, const float *value)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniformMatrix4x2fv(int location, int count, unsigned char transpose, const float *value)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniformMatrix4x3fv(int location, int count, unsigned char transpose, const float *value)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glUniformBlockBinding(unsigned program, unsigned index, unsigned binding)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
unsigned glGetUniformBlockIndex(unsigned program, const char *name)
{
    vox_angle_unsupported();
    return 0xFFFFFFFFu;
}

__attribute__((visibility("default")))
void glGetActiveUniformBlockName(unsigned program, unsigned index, int buf_size, int *length, char *name)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glGetActiveUniformBlockivRobustANGLE(unsigned program, unsigned index, unsigned pname, int buf_size, int *length, int *params)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glGetUniformIndices(unsigned program, int count, const char *const *names, unsigned *indices)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glGetActiveUniformsiv(unsigned program, int count, const unsigned *indices, unsigned pname, int *params)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glGetUniformuiv(unsigned program, int location, unsigned *params)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glVertexAttribI4i(unsigned index, int x, int y, int z, int w)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glVertexAttribI4iv(unsigned index, const int *v)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glVertexAttribI4ui(unsigned index, unsigned x, unsigned y, unsigned z, unsigned w)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glVertexAttribI4uiv(unsigned index, const unsigned *v)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glVertexAttribIPointer(unsigned index, int size, unsigned type, int stride, const void *pointer)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glGetVertexAttribIiv(unsigned index, unsigned pname, int *params)
{
    vox_angle_unsupported();
}

__attribute__((visibility("default")))
void glGetVertexAttribIuiv(unsigned index, unsigned pname, unsigned *params)
{
    vox_angle_unsupported();
}

#endif
