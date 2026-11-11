/* Exercises libvoxangle through dlopen, the way webgl/angle_dispatch_darwin.h
 * loads libEGL/libGLESv2: surfaceless context, FBO-backed texture, shader draw,
 * queries and read-back. */
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

#define CHECK(cond) do { if (!(cond)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #cond); return 1; } } while (0)

/* Prototypes of the entry points under test. The library is reached only via dlsym. */
void *eglGetPlatformDisplay(unsigned, void *, const void *);
unsigned eglInitialize(void *, int *, int *);
unsigned eglChooseConfig(void *, const int *, void **, int, int *);
void *eglCreateContext(void *, void *, void *, const int *);
unsigned eglMakeCurrent(void *, void *, void *, void *);
unsigned eglDestroyContext(void *, void *);
void glGenTextures(int, unsigned *);
void glBindTexture(unsigned, unsigned);
void glTexImage2D(unsigned, int, int, int, int, int, unsigned, unsigned, const void *);
void glGenFramebuffers(int, unsigned *);
void glBindFramebuffer(unsigned, unsigned);
void glFramebufferTexture2D(unsigned, unsigned, unsigned, unsigned, int);
unsigned glCheckFramebufferStatus(unsigned);
void glClearColor(float, float, float, float);
void glClear(unsigned);
void glReadPixels(int, int, int, int, unsigned, unsigned, void *);
unsigned glGetError(void);
unsigned glCreateShader(unsigned);
void glShaderSource(unsigned, int, const char *const *, const int *);
void glCompileShader(unsigned);
void glGetShaderiv(unsigned, unsigned, int *);
void glGetShaderInfoLog(unsigned, int, int *, char *);
unsigned glCreateProgram(void);
void glAttachShader(unsigned, unsigned);
void glLinkProgram(unsigned);
void glGetProgramiv(unsigned, unsigned, int *);
void glUseProgram(unsigned);
int glGetAttribLocation(unsigned, const char *);
int glGetUniformLocation(unsigned, const char *);
void glGenBuffers(int, unsigned *);
void glBindBuffer(unsigned, unsigned);
void glBufferData(unsigned, long, const void *, unsigned);
void glVertexAttribPointer(unsigned, int, unsigned, unsigned char, int, const void *);
void glEnableVertexAttribArray(unsigned);
void glUniform4f(int, float, float, float, float);
void glUniform2fv(int, int, const float *);
void glViewport(int, int, int, int);
void glDrawArrays(unsigned, int, int);
const unsigned char *glGetString(unsigned);
void glGetIntegerv(unsigned, int *);
unsigned char glIsProgram(unsigned);
unsigned char glIsShader(unsigned);
void glDeleteProgram(unsigned);
void glDeleteShader(unsigned);
void glActiveTexture(unsigned);
void glTexParameteri(unsigned, unsigned, int);
void glTexSubImage2D(unsigned, int, int, int, int, int, unsigned, unsigned, const void *);
void glUniform1i(int, int);
void glBlendFunc(unsigned, unsigned);
void glBlendEquation(unsigned);
void glBlendColor(float, float, float, float);
void glColorMask(unsigned char, unsigned char, unsigned char, unsigned char);
void glDrawElements(unsigned, int, unsigned, const void *);
void glEnable(unsigned);
void glDisable(unsigned);
unsigned char glIsEnabled(unsigned);
void glDepthFunc(unsigned);
void glDepthMask(unsigned char);
void glClearDepthf(float);
void glDepthRangef(float, float);
void glCullFace(unsigned);
void glFrontFace(unsigned);
void glGenRenderbuffers(int, unsigned *);
void glBindRenderbuffer(unsigned, unsigned);
void glRenderbufferStorage(unsigned, unsigned, int, int);
void glFramebufferRenderbuffer(unsigned, unsigned, unsigned, unsigned);
void glDeleteRenderbuffers(int, const unsigned *);
unsigned char glIsRenderbuffer(unsigned);
void glHint(unsigned, unsigned);
void glLineWidth(float);
void glPixelStorei(unsigned, int);
void glVertexAttrib4f(unsigned, float, float, float, float);
void glBindAttribLocation(unsigned, unsigned, const char *);
void glGetActiveUniform(unsigned, unsigned, int, int *, int *, unsigned *, char *);
void glGetUniformfv(unsigned, int, float *);
void glGetIntegervRobustANGLE(unsigned, int, int *, int *);
void glStencilFunc(unsigned, int, unsigned);
void glCopyTexImage2D(unsigned, int, unsigned, int, int, int, int, int);
void glFlush(void);
void glFinish(void);

#define SYM(name) __typeof__(&name) name##_fn = (__typeof__(&name))dlsym(lib, #name); CHECK(name##_fn)

int main(int argc, char **argv)
{
    void *lib = dlopen(argc > 1 ? argv[1] : "libvoxangle.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!lib) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 1; }
    SYM(eglGetPlatformDisplay);
    SYM(eglInitialize);
    SYM(eglChooseConfig);
    SYM(eglCreateContext);
    SYM(eglMakeCurrent);
    SYM(eglDestroyContext);
    SYM(glGenTextures);
    SYM(glBindTexture);
    SYM(glTexImage2D);
    SYM(glGenFramebuffers);
    SYM(glBindFramebuffer);
    SYM(glFramebufferTexture2D);
    SYM(glCheckFramebufferStatus);
    SYM(glClearColor);
    SYM(glClear);
    SYM(glReadPixels);
    SYM(glGetError);
    SYM(glCreateShader);
    SYM(glShaderSource);
    SYM(glCompileShader);
    SYM(glGetShaderiv);
    SYM(glGetShaderInfoLog);
    SYM(glCreateProgram);
    SYM(glAttachShader);
    SYM(glLinkProgram);
    SYM(glGetProgramiv);
    SYM(glUseProgram);
    SYM(glGetAttribLocation);
    SYM(glGetUniformLocation);
    SYM(glGenBuffers);
    SYM(glBindBuffer);
    SYM(glBufferData);
    SYM(glVertexAttribPointer);
    SYM(glEnableVertexAttribArray);
    SYM(glUniform4f);
    SYM(glUniform2fv);
    SYM(glViewport);
    SYM(glDrawArrays);
    SYM(glGetString);
    SYM(glGetIntegerv);
    SYM(glIsProgram);
    SYM(glIsShader);
    SYM(glDeleteProgram);
    SYM(glDeleteShader);
    SYM(glActiveTexture);
    SYM(glTexParameteri);
    SYM(glTexSubImage2D);
    SYM(glUniform1i);
    SYM(glBlendFunc);
    SYM(glBlendEquation);
    SYM(glBlendColor);
    SYM(glColorMask);
    SYM(glDrawElements);
    SYM(glEnable);
    SYM(glDisable);
    SYM(glIsEnabled);
    SYM(glDepthFunc);
    SYM(glDepthMask);
    SYM(glClearDepthf);
    SYM(glDepthRangef);
    SYM(glCullFace);
    SYM(glFrontFace);
    SYM(glGenRenderbuffers);
    SYM(glBindRenderbuffer);
    SYM(glRenderbufferStorage);
    SYM(glFramebufferRenderbuffer);
    SYM(glDeleteRenderbuffers);
    SYM(glIsRenderbuffer);
    SYM(glHint);
    SYM(glLineWidth);
    SYM(glPixelStorei);
    SYM(glVertexAttrib4f);
    SYM(glBindAttribLocation);
    SYM(glGetActiveUniform);
    SYM(glGetUniformfv);
    SYM(glGetIntegervRobustANGLE);
    SYM(glStencilFunc);
    SYM(glCopyTexImage2D);
    SYM(glFlush);
    SYM(glFinish);

    void *display = eglGetPlatformDisplay_fn(0x3202, NULL, NULL);
    CHECK(display);
    int major = 0, minor = 0;
    CHECK(eglInitialize_fn(display, &major, &minor) && major == 1);
    const int config_attribs[] = { 0x3040, 0x0040, 0x3038 }; /* RENDERABLE_TYPE = ES3, NONE */
    void *config = NULL;
    int count = 0;
    CHECK(eglChooseConfig_fn(display, config_attribs, &config, 1, &count) && count == 1);

    /* ES 3.0 is not implemented, so the request must fail instead of lying. */
    const int es3_attribs[] = { 0x3098, 3, 0x3038 };
    CHECK(eglCreateContext_fn(display, config, NULL, es3_attribs) == NULL);
    const int context_attribs[] = { 0x3098, 2, 0x3038 };
    void *context = eglCreateContext_fn(display, config, NULL, context_attribs);
    CHECK(context);
    CHECK(eglMakeCurrent_fn(display, NULL, NULL, context));

    unsigned texture = 0, framebuffer = 0;
    glGenTextures_fn(1, &texture);
    glBindTexture_fn(0x0DE1, texture);
    glTexImage2D_fn(0x0DE1, 0, 0x1908, 4, 3, 0, 0x1908, 0x1401, NULL);
    glGenFramebuffers_fn(1, &framebuffer);
    glBindFramebuffer_fn(0x8D40, framebuffer);
    glFramebufferTexture2D_fn(0x8D40, 0x8CE0, 0x0DE1, texture, 0);
    CHECK(glCheckFramebufferStatus_fn(0x8D40) == 0x8CD5);
    glClearColor_fn(0.0f, 1.0f, 0.0f, 1.0f);
    glClear_fn(0x4000);
    unsigned char pixels[4 * 3 * 4];
    memset(pixels, 7, sizeof pixels);
    glReadPixels_fn(0, 0, 4, 3, 0x1908, 0x1401, pixels);
    CHECK(glGetError_fn() == 0);
    for (int i = 0; i < 12; i++) {
        CHECK(pixels[i * 4 + 0] == 0 && pixels[i * 4 + 1] == 255 && pixels[i * 4 + 2] == 0 && pixels[i * 4 + 3] == 255);
    }

    /* Draw through the shader pipeline: a triangle covering the lower-left half. */
    const char *vs_src = "attribute vec2 a_pos; uniform vec2 u_offset;"
                         "void main() { gl_Position = vec4(a_pos + u_offset, 0.0, 1.0); }";
    const char *fs_src = "precision mediump float; uniform vec4 u_color;"
                         "void main() { gl_FragColor = u_color; }";
    unsigned vs = glCreateShader_fn(0x8B31), fs = glCreateShader_fn(0x8B30);
    CHECK(vs && fs);
    glShaderSource_fn(vs, 1, &vs_src, NULL);
    glShaderSource_fn(fs, 1, &fs_src, NULL);
    glCompileShader_fn(vs);
    glCompileShader_fn(fs);
    int ok = 0;
    glGetShaderiv_fn(vs, 0x8B81, &ok);
    CHECK(ok == 1);
    glGetShaderiv_fn(fs, 0x8B81, &ok);
    CHECK(ok == 1);
    unsigned program = glCreateProgram_fn();
    glAttachShader_fn(program, vs);
    glAttachShader_fn(program, fs);
    glLinkProgram_fn(program);
    glGetProgramiv_fn(program, 0x8B82, &ok);
    CHECK(ok == 1);
    glUseProgram_fn(program);
    unsigned vbo = 0;
    glGenBuffers_fn(1, &vbo);
    glBindBuffer_fn(0x8892, vbo);
    const float verts[] = { -1, -1, 1, -1, -1, 1 };
    glBufferData_fn(0x8892, sizeof verts, verts, 0x88E4);
    int pos = glGetAttribLocation_fn(program, "a_pos");
    CHECK(pos >= 0);
    glVertexAttribPointer_fn((unsigned)pos, 2, 0x1406, 0, 0, NULL);
    glEnableVertexAttribArray_fn((unsigned)pos);
    const float offset[2] = { 0, 0 };
    glUniform2fv_fn(glGetUniformLocation_fn(program, "u_offset"), 1, offset);
    glUniform4f_fn(glGetUniformLocation_fn(program, "u_color"), 1, 0, 0, 1);
    glViewport_fn(0, 0, 4, 3);
    glClearColor_fn(0, 0, 0, 1);
    glClear_fn(0x4000);
    glDrawArrays_fn(0x0004, 0, 3);
    CHECK(glGetError_fn() == 0);
    memset(pixels, 7, sizeof pixels);
    glReadPixels_fn(0, 0, 4, 3, 0x1908, 0x1401, pixels);
    CHECK(pixels[0] == 255 && pixels[1] == 0 && pixels[3] == 255);                       /* bottom-left covered */
    CHECK(pixels[44] == 0 && pixels[45] == 0 && pixels[46] == 0 && pixels[47] == 255);    /* top-right clear */

    /* Indexed, blended draw: half-transparent red over the sampled image, with green masked off. */
    glUseProgram_fn(program);
    glBindBuffer_fn(0x8892, vbo);
    glVertexAttribPointer_fn((unsigned)pos, 2, 0x1406, 0, 0, NULL);
    const float corners[] = { -1, -1, 1, -1, -1, 1, 1, 1 };
    glBufferData_fn(0x8892, sizeof corners, corners, 0x88E4);
    unsigned ebo = 0;
    glGenBuffers_fn(1, &ebo);
    glBindBuffer_fn(0x8893, ebo);
    const unsigned short indices[] = { 0, 1, 2, 2, 1, 3 };
    glBufferData_fn(0x8893, sizeof indices, indices, 0x88E4);
    glUniform4f_fn(glGetUniformLocation_fn(program, "u_color"), 1, 0, 0, 0.5f);
    glUniform2fv_fn(glGetUniformLocation_fn(program, "u_offset"), 1, offset);
    glClearColor_fn(0, 0, 1, 1);
    glClear_fn(0x4000);
    glEnable_fn(0x0BE2);
    CHECK(glIsEnabled_fn(0x0BE2));
    glBlendFunc_fn(0x0302, 0x0303);
    glDrawElements_fn(0x0004, 6, 0x1403, NULL);
    CHECK(glGetError_fn() == 0);
    glReadPixels_fn(0, 0, 4, 3, 0x1908, 0x1401, pixels);
    CHECK(pixels[0] >= 127 && pixels[0] <= 128 && pixels[1] == 0 && pixels[2] >= 127 && pixels[2] <= 128);
    glDisable_fn(0x0BE2);
    glColorMask_fn(1, 0, 1, 1);
    glClear_fn(0x4000);
    CHECK(glGetError_fn() == 0x0502); /* a masked clear is refused */
    glColorMask_fn(1, 1, 1, 1);

    /* Depth-tested draws into the framebuffer with a depth renderbuffer. */
    unsigned depth_rb = 0;
    glGenRenderbuffers_fn(1, &depth_rb);
    glBindRenderbuffer_fn(0x8D41, depth_rb);
    glRenderbufferStorage_fn(0x8D41, 0x81A5, 4, 3);
    glBindFramebuffer_fn(0x8D40, framebuffer);
    glFramebufferRenderbuffer_fn(0x8D40, 0x8D00, 0x8D41, depth_rb);
    CHECK(glCheckFramebufferStatus_fn(0x8D40) == 0x8CD5);
    CHECK(glIsRenderbuffer_fn(depth_rb));
    glUseProgram_fn(program);
    glBindBuffer_fn(0x8892, vbo);
    glVertexAttribPointer_fn((unsigned)pos, 2, 0x1406, 0, 0, NULL);
    glClearDepthf_fn(1.0f);
    glClearColor_fn(0, 0, 0, 1);
    glClear_fn(0x4000 | 0x100);
    glEnable_fn(0x0B71);
    glDepthFunc_fn(0x0201);
    glDepthMask_fn(1);
    glDepthRangef_fn(0, 1);
    glEnable_fn(0x0B44);
    glCullFace_fn(0x0405);
    glFrontFace_fn(0x0901);
    glUniform4f_fn(glGetUniformLocation_fn(program, "u_color"), 0, 1, 0, 1);
    glDrawArrays_fn(0x0004, 0, 3);
    glClear_fn(0x100);
    CHECK(glGetError_fn() == 0);
    glDisable_fn(0x0B44);
    glDisable_fn(0x0B71);
    glDeleteRenderbuffers_fn(1, &depth_rb);
    CHECK(!glIsRenderbuffer_fn(depth_rb));
    CHECK(glGetError_fn() == 0);

    /* State setters, introspection, and the Robust getters. */
    glUseProgram_fn(program);
    glUniform4f_fn(glGetUniformLocation_fn(program, "u_color"), 0.25f, 0.5f, 0.75f, 1.0f);
    float color_value[4] = { 0 };
    glGetUniformfv_fn(program, glGetUniformLocation_fn(program, "u_color"), color_value);
    CHECK(color_value[0] == 0.25f && color_value[1] == 0.5f && color_value[2] == 0.75f && color_value[3] == 1.0f);
    int count_value = 0;
    glGetProgramiv_fn(program, 0x8B86, &count_value);
    CHECK(count_value == 2);
    glGetProgramiv_fn(program, 0x8B89, &count_value);
    CHECK(count_value == 1);
    char uniform_name[32] = { 0 };
    int name_length = 0, uniform_size = 0;
    unsigned uniform_type = 0;
    glGetActiveUniform_fn(program, 0, sizeof uniform_name, &name_length, &uniform_size, &uniform_type, uniform_name);
    CHECK(name_length > 0 && uniform_size == 1 && (uniform_type == 0x8B50 || uniform_type == 0x8B52));
    int view[4] = { 0 }, view_length = 0;
    glGetIntegervRobustANGLE_fn(0x0BA2, 4, &view_length, view);
    CHECK(view_length == 4 && view[2] == 4 && view[3] == 3);
    glGetIntegervRobustANGLE_fn(0x0BA2, 2, &view_length, view);
    CHECK(glGetError_fn() == 0x0502); /* the buffer is too small */
    glVertexAttrib4f_fn(5, 1, 2, 3, 4);
    glPixelStorei_fn(0x0CF5, 1);
    glHint_fn(0x8192, 0x1102);
    glStencilFunc_fn(0x0207, 0, 0xff);
    glBindAttribLocation_fn(program, 3, "a_pos");
    CHECK(glGetError_fn() == 0);
    glPixelStorei_fn(0x0CF5, 3);
    CHECK(glGetError_fn() == 0x0501);
    glLineWidth_fn(0);
    CHECK(glGetError_fn() == 0x0501);
    glCopyTexImage2D_fn(0x0DE1, 0, 0x1908, 0, 0, 2, 2, 1);
    CHECK(glGetError_fn() == 0x0501);

    /* A broken shader reports a log through the C ABI. */
    const char *bad_src = "void main() { gl_FragColor = vec4(missing); }";
    unsigned bad = glCreateShader_fn(0x8B30);
    glShaderSource_fn(bad, 1, &bad_src, NULL);
    glCompileShader_fn(bad);
    glGetShaderiv_fn(bad, 0x8B81, &ok);
    CHECK(ok == 0);
    char log[256] = { 0 };
    int log_length = 0;
    glGetShaderInfoLog_fn(bad, sizeof log, &log_length, log);
    CHECK(log_length > 0 && strstr(log, "missing"));

    /* Queries and object lifetime. */
    const char *version = (const char *)glGetString_fn(0x1F02);
    CHECK(version && strncmp(version, "OpenGL ES 2.0", 13) == 0);
    CHECK(glGetString_fn(0x1234) == NULL && glGetError_fn() == 0x0500);
    int viewport[4] = { 0 };
    glGetIntegerv_fn(0x0BA2, viewport);
    CHECK(viewport[2] == 4 && viewport[3] == 3);
    glGetIntegerv_fn(0x8B8D, viewport);
    CHECK((unsigned)viewport[0] == program);
    CHECK(glIsProgram_fn(program) && glIsShader_fn(vs));
    glDeleteProgram_fn(program);
    CHECK(glIsProgram_fn(program)); /* still current */
    glUseProgram_fn(0);
    CHECK(!glIsProgram_fn(program));
    glDeleteShader_fn(vs);
    CHECK(!glIsShader_fn(vs));
    glFlush_fn();
    glFinish_fn();
    CHECK(glGetError_fn() == 0);

    /* Sample a second texture on unit 1 into the framebuffer texture. */
    const char *tvs_src = "attribute vec2 a_pos; varying vec2 v_uv;"
                          "void main() { v_uv = a_pos * 0.5 + vec2(0.5); gl_Position = vec4(a_pos, 0.0, 1.0); }";
    const char *tfs_src = "precision mediump float; uniform sampler2D u_tex; varying vec2 v_uv;"
                          "void main() { gl_FragColor = texture2D(u_tex, v_uv); }";
    unsigned tvs = glCreateShader_fn(0x8B31), tfs = glCreateShader_fn(0x8B30);
    glShaderSource_fn(tvs, 1, &tvs_src, NULL);
    glShaderSource_fn(tfs, 1, &tfs_src, NULL);
    glCompileShader_fn(tvs);
    glCompileShader_fn(tfs);
    unsigned tprogram = glCreateProgram_fn();
    glAttachShader_fn(tprogram, tvs);
    glAttachShader_fn(tprogram, tfs);
    glLinkProgram_fn(tprogram);
    glGetProgramiv_fn(tprogram, 0x8B82, &ok);
    CHECK(ok == 1);
    unsigned source_texture = 0;
    glActiveTexture_fn(0x84C0 + 1);
    glGenTextures_fn(1, &source_texture);
    glBindTexture_fn(0x0DE1, source_texture);
    unsigned char texels[4 * 3 * 4];
    for (int i = 0; i < 12; i++) {
        texels[i * 4] = (unsigned char)(i * 20); texels[i * 4 + 1] = (unsigned char)(255 - i);
        texels[i * 4 + 2] = 7; texels[i * 4 + 3] = 255;
    }
    glTexImage2D_fn(0x0DE1, 0, 0x1908, 4, 3, 0, 0x1908, 0x1401, NULL);
    glTexSubImage2D_fn(0x0DE1, 0, 0, 0, 4, 3, 0x1908, 0x1401, texels);
    glTexParameteri_fn(0x0DE1, 0x2801, 0x2600);
    glTexParameteri_fn(0x0DE1, 0x2800, 0x2600);
    glTexParameteri_fn(0x0DE1, 0x2802, 0x812F);
    glTexParameteri_fn(0x0DE1, 0x2803, 0x812F);
    CHECK(glGetError_fn() == 0);
    glUseProgram_fn(tprogram);
    glUniform1i_fn(glGetUniformLocation_fn(tprogram, "u_tex"), 1);
    const float quad[] = { -1, -1, 1, -1, -1, 1, 1, 1 };
    glBufferData_fn(0x8892, sizeof quad, quad, 0x88E4);
    int tpos = glGetAttribLocation_fn(tprogram, "a_pos");
    glVertexAttribPointer_fn((unsigned)tpos, 2, 0x1406, 0, 0, NULL);
    glEnableVertexAttribArray_fn((unsigned)tpos);
    glDrawArrays_fn(0x0005, 0, 4);
    CHECK(glGetError_fn() == 0);
    memset(pixels, 7, sizeof pixels);
    glReadPixels_fn(0, 0, 4, 3, 0x1908, 0x1401, pixels);
    CHECK(memcmp(pixels, texels, sizeof texels) == 0);
    glActiveTexture_fn(0x84C0 + 99);
    CHECK(glGetError_fn() == 0x0500);

    /* A non-zero border is GL_INVALID_VALUE and must not touch the texture. */
    glTexImage2D_fn(0x0DE1, 0, 0x1908, 4, 3, 1, 0x1908, 0x1401, NULL);
    CHECK(glGetError_fn() == 0x0501);
    CHECK(eglMakeCurrent_fn(display, NULL, NULL, NULL));
    CHECK(eglDestroyContext_fn(display, context));
    puts("capi smoke ok");
    return 0;
}
