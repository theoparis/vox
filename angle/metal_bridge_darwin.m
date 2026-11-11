/* Copyright (c) 2026, Ladybird contributors
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Minimal Metal C bridge for the V angle translation layer. It owns only GPU
 * resources (device, queue, buffers, RGBA8 textures) and the blocking clear,
 * upload and readback submissions; all GL state and validation live in V.
 * Compiled without ARC: every Objective-C object is released explicitly.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdlib.h>
#include <string.h>
#include "metal_bridge.h"

typedef struct VoxAngleMetal {
    id<MTLDevice> device;
    id<MTLCommandQueue> queue;
    /* Index 0 is reserved; slots hold NSNull once destroyed and are not reused. */
    NSMutableArray *resources;
} VoxAngleMetal;

static NSUInteger vox_angle_row_bytes(NSUInteger width)
{
    /* Blit row pitches are aligned to 256 bytes to satisfy every device. */
    NSUInteger bytes = width * 4;
    return (bytes + 255) & ~(NSUInteger)255;
}

static unsigned vox_angle_store(VoxAngleMetal *ctx, id object)
{
    if (!object) return 0;
    [ctx->resources addObject:object];
    [object release];
    return (unsigned)[ctx->resources count] - 1;
}

static id vox_angle_lookup(VoxAngleMetal *ctx, unsigned handle)
{
    if (!ctx || handle == 0 || handle >= [ctx->resources count]) return nil;
    id object = [ctx->resources objectAtIndex:handle];
    return [object isKindOfClass:[NSNull class]] ? nil : object;
}

void *vox_angle_mtl_context_create(void)
{
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) return NULL;
    id<MTLCommandQueue> queue = [device newCommandQueue];
    if (!queue) {
        [device release];
        return NULL;
    }
    VoxAngleMetal *ctx = calloc(1, sizeof(*ctx));
    if (!ctx) {
        [queue release];
        [device release];
        return NULL;
    }
    ctx->device = device;
    ctx->queue = queue;
    ctx->resources = [[NSMutableArray alloc] init];
    [ctx->resources addObject:[NSNull null]];
    return ctx;
}

void vox_angle_mtl_context_destroy(void *handle)
{
    VoxAngleMetal *ctx = handle;
    if (!ctx) return;
    [ctx->resources release];
    [ctx->queue release];
    [ctx->device release];
    free(ctx);
}

const char *vox_angle_mtl_device_name(void *handle)
{
    VoxAngleMetal *ctx = handle;
    return ctx ? [[ctx->device name] UTF8String] : "";
}

void vox_angle_mtl_release(void *handle, unsigned resource)
{
    VoxAngleMetal *ctx = handle;
    if (!ctx || resource == 0 || resource >= [ctx->resources count]) return;
    [ctx->resources replaceObjectAtIndex:resource withObject:[NSNull null]];
}

unsigned vox_angle_mtl_buffer_create(void *handle, long long size)
{
    VoxAngleMetal *ctx = handle;
    if (!ctx || size < 0) return 0;
    /* Metal rejects zero-length allocations; a one-byte backing keeps empty GL buffers valid. */
    NSUInteger length = size == 0 ? 1 : (NSUInteger)size;
    id<MTLBuffer> buffer = [ctx->device newBufferWithLength:length options:MTLResourceStorageModeShared];
    return vox_angle_store(ctx, buffer);
}

int vox_angle_mtl_buffer_write(void *handle, unsigned resource, long long offset, const void *bytes, long long size)
{
    id<MTLBuffer> buffer = vox_angle_lookup(handle, resource);
    if (!buffer || offset < 0 || size < 0 || (NSUInteger)(offset + size) > [buffer length]) return 0;
    if (size > 0) memcpy((char *)[buffer contents] + offset, bytes, (size_t)size);
    return 1;
}

int vox_angle_mtl_buffer_read(void *handle, unsigned resource, long long offset, void *bytes, long long size)
{
    id<MTLBuffer> buffer = vox_angle_lookup(handle, resource);
    if (!buffer || offset < 0 || size < 0 || (NSUInteger)(offset + size) > [buffer length]) return 0;
    if (size > 0) memcpy(bytes, (char *)[buffer contents] + offset, (size_t)size);
    return 1;
}

unsigned vox_angle_mtl_texture_create(void *handle, int width, int height, int mipmapped)
{
    VoxAngleMetal *ctx = handle;
    if (!ctx || width <= 0 || height <= 0) return 0;
    MTLTextureDescriptor *descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                           width:(NSUInteger)width
                                                          height:(NSUInteger)height
                                                       mipmapped:mipmapped ? YES : NO];
    descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    descriptor.storageMode = MTLStorageModePrivate;
    id<MTLTexture> texture = [ctx->device newTextureWithDescriptor:descriptor];
    return vox_angle_store(ctx, texture);
}

unsigned vox_angle_mtl_depth_create(void *handle, int width, int height)
{
    VoxAngleMetal *ctx = handle;
    if (!ctx || width <= 0 || height <= 0) return 0;
    MTLTextureDescriptor *descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float_Stencil8
                                                           width:(NSUInteger)width
                                                          height:(NSUInteger)height
                                                       mipmapped:NO];
    descriptor.usage = MTLTextureUsageRenderTarget;
    descriptor.storageMode = MTLStorageModePrivate;
    id<MTLTexture> texture = [ctx->device newTextureWithDescriptor:descriptor];
    return vox_angle_store(ctx, texture);
}

/* Blocking GPU submission: waits for completion and reports command failure. */
static int vox_angle_submit_and_wait(VoxAngleMetal *ctx, id<MTLCommandBuffer> command)
{
    [command commit];
    [command waitUntilCompleted];
    return [command status] == MTLCommandBufferStatusCompleted;
}

int vox_angle_mtl_depth_clear(void *handle, unsigned resource, float depth, int stencil, int mask)
{
    VoxAngleMetal *ctx = handle;
    id<MTLTexture> texture = vox_angle_lookup(ctx, resource);
    if (!texture) return 0;
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.depthAttachment.texture = texture;
    pass.depthAttachment.loadAction = (mask & 1) ? MTLLoadActionClear : MTLLoadActionLoad;
    pass.depthAttachment.storeAction = MTLStoreActionStore;
    pass.depthAttachment.clearDepth = depth;
    pass.stencilAttachment.texture = texture;
    pass.stencilAttachment.loadAction = (mask & 2) ? MTLLoadActionClear : MTLLoadActionLoad;
    pass.stencilAttachment.storeAction = MTLStoreActionStore;
    pass.stencilAttachment.clearStencil = (uint32_t)stencil & 0xFF;
    id<MTLCommandBuffer> command = [ctx->queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
    [encoder endEncoding];
    return vox_angle_submit_and_wait(ctx, command);
}

int vox_angle_mtl_texture_clear(void *handle, unsigned resource, float r, float g, float b, float a)
{
    VoxAngleMetal *ctx = handle;
    id<MTLTexture> texture = vox_angle_lookup(ctx, resource);
    if (!texture) return 0;
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(r, g, b, a);
    id<MTLCommandBuffer> command = [ctx->queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
    [encoder endEncoding];
    return vox_angle_submit_and_wait(ctx, command);
}

int vox_angle_mtl_generate_mipmaps(void *handle, unsigned resource)
{
    VoxAngleMetal *ctx = handle;
    id<MTLTexture> texture = vox_angle_lookup(ctx, resource);
    if (!texture) return 0;
    id<MTLCommandBuffer> command = [ctx->queue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [command blitCommandEncoder];
    [blit generateMipmapsForTexture:texture];
    [blit endEncoding];
    return vox_angle_submit_and_wait(ctx, command);
}

/* Uploads tightly packed RGBA8 pixels through a staging buffer and a blit. */
int vox_angle_mtl_texture_upload(void *handle, unsigned resource, int width, int height, const void *pixels)
{
    VoxAngleMetal *ctx = handle;
    id<MTLTexture> texture = vox_angle_lookup(ctx, resource);
    if (!texture || width <= 0 || height <= 0 || !pixels) return 0;
    NSUInteger row = vox_angle_row_bytes((NSUInteger)width);
    id<MTLBuffer> staging = [ctx->device newBufferWithLength:row * (NSUInteger)height
                                                     options:MTLResourceStorageModeShared];
    if (!staging) return 0;
    char *dst = [staging contents];
    for (int y = 0; y < height; y++)
        memcpy(dst + (NSUInteger)y * row, (const char *)pixels + (size_t)y * width * 4, (size_t)width * 4);
    id<MTLCommandBuffer> command = [ctx->queue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [command blitCommandEncoder];
    [blit copyFromBuffer:staging
            sourceOffset:0
       sourceBytesPerRow:row
     sourceBytesPerImage:row * (NSUInteger)height
              sourceSize:MTLSizeMake((NSUInteger)width, (NSUInteger)height, 1)
               toTexture:texture
        destinationSlice:0
        destinationLevel:0
       destinationOrigin:MTLOriginMake(0, 0, 0)];
    [blit endEncoding];
    int ok = vox_angle_submit_and_wait(ctx, command);
    [staging release];
    return ok;
}

/* Reads back tightly packed RGBA8 pixels; the caller provides width*height*4 bytes. */
int vox_angle_mtl_texture_read(void *handle, unsigned resource, int width, int height, void *pixels)
{
    VoxAngleMetal *ctx = handle;
    id<MTLTexture> texture = vox_angle_lookup(ctx, resource);
    if (!texture || width <= 0 || height <= 0 || !pixels) return 0;
    if ((NSUInteger)width != [texture width] || (NSUInteger)height != [texture height]) return 0;
    NSUInteger row = vox_angle_row_bytes((NSUInteger)width);
    id<MTLBuffer> staging = [ctx->device newBufferWithLength:row * (NSUInteger)height
                                                     options:MTLResourceStorageModeShared];
    if (!staging) return 0;
    id<MTLCommandBuffer> command = [ctx->queue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [command blitCommandEncoder];
    [blit copyFromTexture:texture
              sourceSlice:0
              sourceLevel:0
             sourceOrigin:MTLOriginMake(0, 0, 0)
               sourceSize:MTLSizeMake((NSUInteger)width, (NSUInteger)height, 1)
                 toBuffer:staging
        destinationOffset:0
   destinationBytesPerRow:row
 destinationBytesPerImage:row * (NSUInteger)height];
    [blit endEncoding];
    int ok = vox_angle_submit_and_wait(ctx, command);
    if (ok) {
        const char *src = [staging contents];
        for (int y = 0; y < height; y++)
            memcpy((char *)pixels + (size_t)y * width * 4, src + (NSUInteger)y * row, (size_t)width * 4);
    }
    [staging release];
    return ok;
}

/* Writes a compiler or validation message into the caller's fixed log buffer. */
static void vox_angle_write_log(NSString *message, char *log, int log_size)
{
    if (!log || log_size <= 0) return;
    const char *text = message ? [message UTF8String] : "";
    strncpy(log, text, (size_t)log_size - 1);
    log[log_size - 1] = 0;
}

unsigned vox_angle_mtl_library_create(void *handle, const char *source, char *log, int log_size)
{
    VoxAngleMetal *ctx = handle;
    if (!ctx || !source) return 0;
    NSError *error = nil;
    id<MTLLibrary> library = [ctx->device newLibraryWithSource:[NSString stringWithUTF8String:source]
                                                       options:nil
                                                         error:&error];
    if (!library) {
        vox_angle_write_log(error ? [error localizedDescription] : @"Metal rejected the shader", log, log_size);
        return 0;
    }
    return vox_angle_store(ctx, library);
}

/* Attribute i reads vertex buffer slot 16 + i. Each slot holds one tightly
 * spaced float attribute of 1 to 4 components at the given stride. */
unsigned vox_angle_mtl_pipeline_create(void *handle, unsigned vs_library, const char *vs_entry,
                                       unsigned fs_library, const char *fs_entry, int attr_count,
                                       const int *components, const unsigned *strides, const int *constant, const int *divisor, int blend_count,
                                       const int *blend, int write_mask, int has_depth, char *log, int log_size)
{
    VoxAngleMetal *ctx = handle;
    id<MTLLibrary> vs_lib = vox_angle_lookup(ctx, vs_library);
    id<MTLLibrary> fs_lib = vox_angle_lookup(ctx, fs_library);
    if (!ctx || !vs_lib || !fs_lib || attr_count < 0 || attr_count > 16) {
        vox_angle_write_log(@"invalid pipeline libraries", log, log_size);
        return 0;
    }
    id<MTLFunction> vf = [vs_lib newFunctionWithName:[NSString stringWithUTF8String:vs_entry]];
    id<MTLFunction> ff = [fs_lib newFunctionWithName:[NSString stringWithUTF8String:fs_entry]];
    if (!vf || !ff) {
        vox_angle_write_log(@"pipeline entry point is missing", log, log_size);
        return 0;
    }
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = vf;
    desc.fragmentFunction = ff;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    if (has_depth) {
        desc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
        desc.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    }
    MTLColorWriteMask mask = MTLColorWriteMaskNone;
    if (write_mask & 1) mask |= MTLColorWriteMaskRed;
    if (write_mask & 2) mask |= MTLColorWriteMaskGreen;
    if (write_mask & 4) mask |= MTLColorWriteMaskBlue;
    if (write_mask & 8) mask |= MTLColorWriteMaskAlpha;
    desc.colorAttachments[0].writeMask = mask;
    if (blend_count == 6) {
        /* Backend factor numbering to MTLBlendFactor. */
        static const MTLBlendFactor factors[15] = {
            MTLBlendFactorZero, MTLBlendFactorOne, MTLBlendFactorSourceColor, MTLBlendFactorOneMinusSourceColor,
            MTLBlendFactorDestinationColor, MTLBlendFactorOneMinusDestinationColor, MTLBlendFactorSourceAlpha,
            MTLBlendFactorOneMinusSourceAlpha, MTLBlendFactorDestinationAlpha, MTLBlendFactorOneMinusDestinationAlpha,
            MTLBlendFactorBlendColor, MTLBlendFactorOneMinusBlendColor, MTLBlendFactorBlendAlpha,
            MTLBlendFactorOneMinusBlendAlpha, MTLBlendFactorSourceAlphaSaturated
        };
        static const MTLBlendOperation operations[3] = {
            MTLBlendOperationAdd, MTLBlendOperationSubtract, MTLBlendOperationReverseSubtract
        };
        for (int i = 0; i < 4; i++) {
            if (blend[i] < 0 || blend[i] > 14) { [desc release]; return 0; }
        }
        if (blend[4] < 0 || blend[4] > 2 || blend[5] < 0 || blend[5] > 2) { [desc release]; return 0; }
        MTLRenderPipelineColorAttachmentDescriptor *color = desc.colorAttachments[0];
        color.blendingEnabled = YES;
        color.sourceRGBBlendFactor = factors[blend[0]];
        color.destinationRGBBlendFactor = factors[blend[1]];
        color.sourceAlphaBlendFactor = factors[blend[2]];
        color.destinationAlphaBlendFactor = factors[blend[3]];
        color.rgbBlendOperation = operations[blend[4]];
        color.alphaBlendOperation = operations[blend[5]];
    }
    MTLVertexDescriptor *layout = [MTLVertexDescriptor vertexDescriptor];
    for (int i = 0; i < attr_count; i++) {
        MTLVertexFormat format;
        switch (components[i]) {
        case 1: format = MTLVertexFormatFloat; break;
        case 2: format = MTLVertexFormatFloat2; break;
        case 3: format = MTLVertexFormatFloat3; break;
        case 4: format = MTLVertexFormatFloat4; break;
        default:
            [desc release];
            vox_angle_write_log(@"attribute component count must be 1 to 4", log, log_size);
            return 0;
        }
        layout.attributes[i].format = format;
        layout.attributes[i].offset = 0;
        layout.attributes[i].bufferIndex = 16 + (NSUInteger)i;
        layout.layouts[16 + i].stride = strides[i];
        if (constant[i]) {
            layout.layouts[16 + i].stepFunction = MTLVertexStepFunctionConstant;
            layout.layouts[16 + i].stepRate = 0;
        } else if (divisor[i] > 0) {
            layout.layouts[16 + i].stepFunction = MTLVertexStepFunctionPerInstance;
            layout.layouts[16 + i].stepRate = (NSUInteger)divisor[i];
        } else {
            layout.layouts[16 + i].stepFunction = MTLVertexStepFunctionPerVertex;
            layout.layouts[16 + i].stepRate = 1;
        }
    }
    desc.vertexDescriptor = layout;
    NSError *error = nil;
    id<MTLRenderPipelineState> state = [ctx->device newRenderPipelineStateWithDescriptor:desc error:&error];
    [desc release];
    if (!state) {
        vox_angle_write_log(error ? [error localizedDescription] : @"Metal could not create the pipeline", log, log_size);
        return 0;
    }
    return vox_angle_store(ctx, state);
}

int vox_angle_mtl_draw(void *handle, unsigned target, unsigned pipeline, int primitive, unsigned start,
                       unsigned count, int attr_count, const unsigned *buffers, const unsigned *offsets,
                       int uniform_count, const unsigned *uniform_sizes, const unsigned char *uniform_bytes,
                       const int *viewport, const int *scissor, int texture_count,
                       const unsigned *textures, const int *sampler_params, const float *blend_color,
                       unsigned index_buffer, int index_type, unsigned index_offset, unsigned depth_texture,
                       int depth_func, int depth_write, const float *depth_range, int cull, int front_ccw,
                       const float *depth_bias, unsigned instance_count, const int *stencil)
{
    VoxAngleMetal *ctx = handle;
    id<MTLTexture> texture = vox_angle_lookup(ctx, target);
    id<MTLRenderPipelineState> state = vox_angle_lookup(ctx, pipeline);
    if (!texture || !state || count == 0 || attr_count < 0 || attr_count > 16 || uniform_count < 0 || uniform_count > 16 || texture_count < 0 || texture_count > 16) return 0;
    /* Empty rectangles are filtered by the caller; reject them here as a safety net. */
    if (viewport[2] <= 0 || viewport[3] <= 0 || scissor[2] <= 0 || scissor[3] <= 0) return 0;
    /* Validate every buffer before encoding so a failure cannot leave an open encoder. */
    id<MTLBuffer> vertex_buffers[16];
    for (int i = 0; i < attr_count; i++) {
        vertex_buffers[i] = vox_angle_lookup(ctx, buffers[i]);
        if (!vertex_buffers[i]) return 0;
    }
    id<MTLTexture> depth = nil;
    if (depth_texture) {
        depth = vox_angle_lookup(ctx, depth_texture);
        if (!depth) return 0;
    }
    if (depth_func > 7 || cull < 0 || cull > 2) return 0;
    id<MTLBuffer> indices = nil;
    if (index_buffer) {
        if (index_type != 1 && index_type != 2) return 0;
        indices = vox_angle_lookup(ctx, index_buffer);
        if (!indices) return 0;
    }
    id<MTLTexture> sampled[16] = { nil };
    for (int i = 0; i < texture_count; i++) {
        if (textures[i] == 0) continue;
        sampled[i] = vox_angle_lookup(ctx, textures[i]);
        if (!sampled[i]) return 0;
    }
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionLoad;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    if (depth) {
        pass.depthAttachment.texture = depth;
        pass.depthAttachment.loadAction = MTLLoadActionLoad;
        pass.depthAttachment.storeAction = MTLStoreActionStore;
        pass.stencilAttachment.texture = depth;
        pass.stencilAttachment.loadAction = MTLLoadActionLoad;
        pass.stencilAttachment.storeAction = MTLStoreActionStore;
    }
    id<MTLCommandBuffer> command = [ctx->queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:state];
    if (depth && (depth_func >= 0 || stencil)) {
        MTLDepthStencilDescriptor *dd = [[MTLDepthStencilDescriptor alloc] init];
        /* With the depth test off nothing compares and nothing writes. */
        dd.depthCompareFunction = depth_func >= 0 ? (MTLCompareFunction)depth_func : MTLCompareFunctionAlways;
        dd.depthWriteEnabled = (depth_func >= 0 && depth_write) ? YES : NO;
        if (stencil) {
            for (int face = 0; face < 2; face++) {
                const int *s = stencil + face * 7;
                MTLStencilDescriptor *sd = [[MTLStencilDescriptor alloc] init];
                sd.stencilCompareFunction = (MTLCompareFunction)s[0];
                sd.readMask = (uint32_t)s[2] & 0xFF;
                sd.writeMask = (uint32_t)s[3] & 0xFF;
                sd.stencilFailureOperation = (MTLStencilOperation)s[4];
                sd.depthFailureOperation = (MTLStencilOperation)s[5];
                sd.depthStencilPassOperation = (MTLStencilOperation)s[6];
                if (face == 0) dd.frontFaceStencil = sd; else dd.backFaceStencil = sd;
                [sd release];
            }
        }
        id<MTLDepthStencilState> ds = [ctx->device newDepthStencilStateWithDescriptor:dd];
        [dd release];
        [encoder setDepthStencilState:ds];
        [ds release];
    }
    if (depth && stencil)
        [encoder setStencilFrontReferenceValue:(uint32_t)stencil[1] & 0xFF backReferenceValue:(uint32_t)stencil[8] & 0xFF];
    [encoder setDepthBias:depth_bias[0] slopeScale:depth_bias[1] clamp:0.0f];
    [encoder setCullMode:(MTLCullMode)cull];
    /* The vertex wrapper negates y, which reverses winding as Metal sees it. */
    [encoder setFrontFacingWinding:front_ccw ? MTLWindingClockwise : MTLWindingCounterClockwise];
    /* GL window row y is texture row y in this layer, so the rectangles pass through. */
    MTLViewport vp = { (double)viewport[0], (double)viewport[1], (double)viewport[2], (double)viewport[3],
                       (double)depth_range[0], (double)depth_range[1] };
    [encoder setViewport:vp];
    MTLScissorRect rect = { (NSUInteger)scissor[0], (NSUInteger)scissor[1], (NSUInteger)scissor[2], (NSUInteger)scissor[3] };
    [encoder setScissorRect:rect];
    for (int i = 0; i < attr_count; i++)
        [encoder setVertexBuffer:vertex_buffers[i] offset:offsets[i] atIndex:16 + (NSUInteger)i];
    const unsigned char *bytes = uniform_bytes;
    for (int i = 0; i < uniform_count; i++) {
        [encoder setVertexBytes:bytes length:uniform_sizes[i] atIndex:(NSUInteger)i];
        [encoder setFragmentBytes:bytes length:uniform_sizes[i] atIndex:(NSUInteger)i];
        bytes += uniform_sizes[i];
    }
    for (int i = 0; i < texture_count; i++) {
        if (!sampled[i]) continue;
        MTLSamplerDescriptor *sd = [[MTLSamplerDescriptor alloc] init];
        sd.minFilter = sampler_params[i * 5] ? MTLSamplerMinMagFilterLinear : MTLSamplerMinMagFilterNearest;
        sd.magFilter = sampler_params[i * 5 + 1] ? MTLSamplerMinMagFilterLinear : MTLSamplerMinMagFilterNearest;
        MTLSamplerAddressMode modes[3] = { MTLSamplerAddressModeRepeat, MTLSamplerAddressModeClampToEdge,
                                           MTLSamplerAddressModeMirrorRepeat };
        sd.sAddressMode = modes[sampler_params[i * 5 + 2] % 3];
        sd.tAddressMode = modes[sampler_params[i * 5 + 3] % 3];
        /* 0: base level only, 1: nearest mip level, 2: blend two levels. */
        sd.mipFilter = sampler_params[i * 5 + 4] == 2 ? MTLSamplerMipFilterLinear
                     : sampler_params[i * 5 + 4] == 1 ? MTLSamplerMipFilterNearest : MTLSamplerMipFilterNotMipmapped;
        id<MTLSamplerState> sampler = [ctx->device newSamplerStateWithDescriptor:sd];
        [sd release];
        [encoder setFragmentTexture:sampled[i] atIndex:(NSUInteger)i];
        [encoder setFragmentSamplerState:sampler atIndex:(NSUInteger)i];
        [sampler release];
    }
    [encoder setBlendColorRed:blend_color[0] green:blend_color[1] blue:blend_color[2] alpha:blend_color[3]];
    if (indices) {
        [encoder drawIndexedPrimitives:(MTLPrimitiveType)primitive
                            indexCount:count
                             indexType:index_type == 1 ? MTLIndexTypeUInt16 : MTLIndexTypeUInt32
                           indexBuffer:indices
                     indexBufferOffset:index_offset
                         instanceCount:instance_count];
    } else {
        [encoder drawPrimitives:(MTLPrimitiveType)primitive vertexStart:start vertexCount:count instanceCount:instance_count];
    }
    [encoder endEncoding];
    return vox_angle_submit_and_wait(ctx, command);
}
