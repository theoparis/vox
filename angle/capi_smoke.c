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
