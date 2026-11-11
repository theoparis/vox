// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module angle

// capi_shim.h defines entry points whose C signature V cannot export directly
// (see capi.v). It forwards to exported V functions and is compiled only for
// the shared-library build, `-d vox_angle_capi`.
#include "@DIR/capi_shim.h"
#include "@DIR/capi_es3_shim.h"

$if vox_angle_capi ? {
	// V restricts shared-library exports to its own @[export] functions, so the
	// shim's entry point must be listed explicitly.
	#flag darwin -Wl,-exported_symbol,_glTexImage2D
	#flag darwin -Wl,-exported_symbol,_glTexSubImage2D
	#flag darwin -Wl,-exported_symbol,_glTexImage2DRobustANGLE
	#flag darwin -Wl,-exported_symbol,_glTexSubImage2DRobustANGLE
	#flag darwin -Wl,-exported_symbol,_glReadPixelsRobustANGLE
	#flag darwin -Wl,-exported_symbol,_glBeginQuery
	#flag darwin -Wl,-exported_symbol,_glEndQuery
	#flag darwin -Wl,-exported_symbol,_glGenQueries
	#flag darwin -Wl,-exported_symbol,_glDeleteQueries
	#flag darwin -Wl,-exported_symbol,_glGetQueryObjectuivRobustANGLE
	#flag darwin -Wl,-exported_symbol,_glBeginTransformFeedback
	#flag darwin -Wl,-exported_symbol,_glEndTransformFeedback
	#flag darwin -Wl,-exported_symbol,_glPauseTransformFeedback
	#flag darwin -Wl,-exported_symbol,_glResumeTransformFeedback
	#flag darwin -Wl,-exported_symbol,_glGenTransformFeedbacks
	#flag darwin -Wl,-exported_symbol,_glDeleteTransformFeedbacks
	#flag darwin -Wl,-exported_symbol,_glBindTransformFeedback
	#flag darwin -Wl,-exported_symbol,_glTransformFeedbackVaryings
	#flag darwin -Wl,-exported_symbol,_glBindBufferBase
	#flag darwin -Wl,-exported_symbol,_glBindBufferRange
	#flag darwin -Wl,-exported_symbol,_glBindSampler
	#flag darwin -Wl,-exported_symbol,_glGenSamplers
	#flag darwin -Wl,-exported_symbol,_glDeleteSamplers
	#flag darwin -Wl,-exported_symbol,_glSamplerParameterf
	#flag darwin -Wl,-exported_symbol,_glSamplerParameteri
	#flag darwin -Wl,-exported_symbol,_glGetSamplerParameterfvRobustANGLE
	#flag darwin -Wl,-exported_symbol,_glFenceSync
	#flag darwin -Wl,-exported_symbol,_glClientWaitSync
	#flag darwin -Wl,-exported_symbol,_glDeleteSync
	#flag darwin -Wl,-exported_symbol,_glWaitSync
	#flag darwin -Wl,-exported_symbol,_glGetSynciv
	#flag darwin -Wl,-exported_symbol,_glClearBufferfi
	#flag darwin -Wl,-exported_symbol,_glClearBufferfv
	#flag darwin -Wl,-exported_symbol,_glClearBufferiv
	#flag darwin -Wl,-exported_symbol,_glClearBufferuiv
	#flag darwin -Wl,-exported_symbol,_glBlitFramebuffer
	#flag darwin -Wl,-exported_symbol,_glFramebufferTextureLayer
	#flag darwin -Wl,-exported_symbol,_glTexStorage2D
	#flag darwin -Wl,-exported_symbol,_glTexStorage3D
	#flag darwin -Wl,-exported_symbol,_glTexImage3DRobustANGLE
	#flag darwin -Wl,-exported_symbol,_glTexSubImage3DRobustANGLE
	#flag darwin -Wl,-exported_symbol,_glCompressedTexImage3D
	#flag darwin -Wl,-exported_symbol,_glCompressedTexSubImage3D
	#flag darwin -Wl,-exported_symbol,_glCompressedTexSubImage2D
	#flag darwin -Wl,-exported_symbol,_glCopyBufferSubData
	#flag darwin -Wl,-exported_symbol,_glMapBufferRange
	#flag darwin -Wl,-exported_symbol,_glUnmapBuffer
	#flag darwin -Wl,-exported_symbol,_glUniform1ui
	#flag darwin -Wl,-exported_symbol,_glUniform2ui
	#flag darwin -Wl,-exported_symbol,_glUniform3ui
	#flag darwin -Wl,-exported_symbol,_glUniform4ui
	#flag darwin -Wl,-exported_symbol,_glUniform1uiv
	#flag darwin -Wl,-exported_symbol,_glUniform2uiv
	#flag darwin -Wl,-exported_symbol,_glUniform3uiv
	#flag darwin -Wl,-exported_symbol,_glUniform4uiv
	#flag darwin -Wl,-exported_symbol,_glUniformMatrix2x3fv
	#flag darwin -Wl,-exported_symbol,_glUniformMatrix2x4fv
	#flag darwin -Wl,-exported_symbol,_glUniformMatrix3x2fv
	#flag darwin -Wl,-exported_symbol,_glUniformMatrix3x4fv
	#flag darwin -Wl,-exported_symbol,_glUniformMatrix4x2fv
	#flag darwin -Wl,-exported_symbol,_glUniformMatrix4x3fv
	#flag darwin -Wl,-exported_symbol,_glUniformBlockBinding
	#flag darwin -Wl,-exported_symbol,_glGetUniformBlockIndex
	#flag darwin -Wl,-exported_symbol,_glGetActiveUniformBlockName
	#flag darwin -Wl,-exported_symbol,_glGetActiveUniformBlockivRobustANGLE
	#flag darwin -Wl,-exported_symbol,_glGetUniformIndices
	#flag darwin -Wl,-exported_symbol,_glGetActiveUniformsiv
	#flag darwin -Wl,-exported_symbol,_glGetUniformuiv
	#flag darwin -Wl,-exported_symbol,_glVertexAttribI4i
	#flag darwin -Wl,-exported_symbol,_glVertexAttribI4iv
	#flag darwin -Wl,-exported_symbol,_glVertexAttribI4ui
	#flag darwin -Wl,-exported_symbol,_glVertexAttribI4uiv
	#flag darwin -Wl,-exported_symbol,_glVertexAttribIPointer
	#flag darwin -Wl,-exported_symbol,_glGetVertexAttribIiv
	#flag darwin -Wl,-exported_symbol,_glGetVertexAttribIuiv
}
