/* Drives webgl/native_egl.h unmodified against libvoxangle (selected with
 * VOX_WEBGL_ANGLE_V): the same create / surface / draw / readback path the
 * WebGL package uses. Build flags: -I<khronos headers> -I webgl. */
#include <stdio.h>
#include "native_egl.h"

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s (gl error 0x%x)\n", __LINE__, #c, glGetError()); return 1; } } while (0)

int main(void)
{
    VoxEGLContext *ctx = vox_egl_create(2);
    CHECK(ctx);
    CHECK(vox_egl_make_current(ctx));
    CHECK(vox_egl_allocate_surface(ctx, 8, 8, 1, 0));
    CHECK(glGetError() == 0);
    glClearColor(0.0f, 1.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    unsigned char pixels[8 * 8 * 4];
    CHECK(vox_egl_copy_drawing_buffer(ctx, 8, 8, pixels));
    CHECK(pixels[0] == 0 && pixels[1] == 255 && pixels[2] == 0 && pixels[3] == 255);
    CHECK(glGetError() == 0);
    /* The default-values clear restores the client's clear color afterwards. */
    vox_egl_clear_drawing_buffer(ctx);
    CHECK(vox_egl_copy_drawing_buffer(ctx, 8, 8, pixels));
    CHECK(pixels[0] == 0 && pixels[1] == 0 && pixels[2] == 0 && pixels[3] == 0);
    GLfloat color[4];
    glGetFloatv(GL_COLOR_CLEAR_VALUE, color);
    CHECK(color[0] == 0.0f && color[1] == 1.0f && color[2] == 0.0f && color[3] == 1.0f);
    /* A shader draw into the drawing buffer, read back through the CPU copy. */
    const char *vs_source = "attribute vec2 p; void main() { gl_Position = vec4(p, 0.0, 1.0); }";
    const char *fs_source = "precision mediump float; void main() { gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0); }";
    GLuint vs = glCreateShader(GL_VERTEX_SHADER), fs = glCreateShader(GL_FRAGMENT_SHADER), prog = glCreateProgram();
    glShaderSource(vs, 1, &vs_source, NULL);
    glShaderSource(fs, 1, &fs_source, NULL);
    glCompileShader(vs);
    glCompileShader(fs);
    glAttachShader(prog, vs);
    glAttachShader(prog, fs);
    glBindAttribLocation(prog, 0, "p");
    glLinkProgram(prog);
    GLint linked = 0;
    glGetProgramiv(prog, GL_LINK_STATUS, &linked);
    CHECK(linked);
    glUseProgram(prog);
    float quad[] = { -1, -1, 1, -1, -1, 1, 1, 1 };
    GLuint buffer;
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof quad, quad, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, NULL);
    glBindFramebuffer(GL_FRAMEBUFFER, ctx->framebuffer);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    CHECK(glGetError() == 0);
    CHECK(vox_egl_copy_drawing_buffer(ctx, 8, 8, pixels));
    CHECK(pixels[0] == 255 && pixels[1] == 0 && pixels[3] == 255);
    CHECK(pixels[(7 * 8 + 7) * 4] == 255);
    /* A depth+stencil drawing buffer: native_egl.h asks for DEPTH24_STENCIL8 as a
     * DEPTH_STENCIL_ATTACHMENT. */
    CHECK(vox_egl_allocate_surface(ctx, 8, 8, 1, 1));
    GLint stencil_bits = 0;
    glGetIntegerv(GL_STENCIL_BITS, &stencil_bits);
    CHECK(stencil_bits == 8);
    glBindFramebuffer(GL_FRAMEBUFFER, ctx->framebuffer);
    glClearColor(0, 0, 0, 1);
    glClearStencil(0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    glEnable(GL_STENCIL_TEST);
    glStencilFunc(GL_ALWAYS, 1, 0xff);
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
    float left[] = { -1, -1, 0, -1, -1, 1, 0, 1 };
    glBufferData(GL_ARRAY_BUFFER, sizeof left, left, GL_STATIC_DRAW);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glClear(GL_COLOR_BUFFER_BIT);
    glStencilFunc(GL_EQUAL, 1, 0xff);
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
    glBufferData(GL_ARRAY_BUFFER, sizeof quad, quad, GL_STATIC_DRAW);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    CHECK(glGetError() == 0);
    CHECK(vox_egl_copy_drawing_buffer(ctx, 8, 8, pixels));
    CHECK(pixels[(4 * 8 + 1) * 4] == 255 && pixels[(4 * 8 + 6) * 4] == 0);
    printf("webgl glue ok: %s\n", (const char *)glGetString(GL_RENDERER));
    return 0;
}
