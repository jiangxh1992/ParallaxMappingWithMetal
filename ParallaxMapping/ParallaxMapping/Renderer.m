//
//  Renderer.m
//  ParallaxMapping
//
//  Created by Xinhou Jiang on 2020/2/4.
//  Copyright © 2020 Xinhou Jiang. All rights reserved.
//
#import <simd/simd.h>
#import <ModelIO/ModelIO.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import "Renderer.h"
// Include header shared between C code here, which executes Metal API commands, and .metal files
#import "ShaderTypes.h"
@implementation Renderer
{
    id <MTLDevice> _device;
    id <MTLCommandQueue> _commandQueue;
    
    id<MTLBuffer> _quadBuffer;
    id<MTLBuffer> _uniformBuffer;
    
    id<MTLTexture> sourceTexture;
    id<MTLTexture> bgBlurTexture;
    id<MTLTexture> depthTexture;
    
    id <MTLRenderPipelineState> _pipelineState;
    id<MTLRenderPipelineState> _quadPipeline;
    
    id <MTLDepthStencilState> _quadDepthState;
}

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
{
    self = [super init];
    if(self)
    {
        _device = view.device;
        [self _loadMetalWithView:view];
        [self _loadAssets];
    }
    return self;
}

- (void)_loadMetalWithView:(nonnull MTKView *)view;
{
    view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    view.sampleCount = 1;

    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
    
    // quad buffer
    static const AAPLVertex verts[] =
    {
        // Pixel positions, Texture coordinates
        { {  1.0,  -1.0 },  { 1.f, 1.f } },
        { { -1.0,  -1.0 },  { 0.f, 1.f } },
        { { -1.0,   1.0 },  { 0.f, 0.f } },
        
        { {  1.0,  -1.0 },  { 1.f, 1.f } },
        { { -1.0,   1.0 },  { 0.f, 0.f } },
        { {  1.0,   1.0 },  { 1.f, 0.f } },
    };
    
    // 初始化相机位置
    _uniformBuffer = [_device newBufferWithLength:sizeof(Uniforms) options:MTLResourceStorageModeShared];
    Uniforms *uniforms = (Uniforms*)_uniformBuffer.contents;
    uniforms->camTanDir = (vector_float3){0,0,0};
    uniforms->parallaxScale = - 0.2f;
    
    _quadBuffer = [_device newBufferWithBytes:verts length:sizeof(verts) options:MTLResourceStorageModeShared];
    _quadBuffer.label = @"QuadVB";
    id<MTLFunction> vertexQuadFunction = [defaultLibrary newFunctionWithName:@"vertexQuadMain"];
    id<MTLFunction> fragmentQuadFunction = [defaultLibrary newFunctionWithName:@"fragmentQuadMain"];
    MTLRenderPipelineDescriptor *pipeDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipeDesc.label = @"QuadPileLine";
    pipeDesc.vertexFunction        = vertexQuadFunction;
    pipeDesc.fragmentFunction    = fragmentQuadFunction;
    pipeDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    pipeDesc.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
    pipeDesc.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;
    _quadPipeline = [_device newRenderPipelineStateWithDescriptor:pipeDesc error:nil];
    
    // 深度状态对象
    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLessEqual;
    depthStateDesc.depthWriteEnabled = NO;
    _quadDepthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];

    _commandQueue = [_device newCommandQueue];
}

// 加载要处理的图像
- (void)_loadAssets
{
    NSError *error;
    MTKTextureLoader* textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
    NSDictionary *textureLoaderOptions =
    @{
      MTKTextureLoaderOptionTextureUsage       : @(MTLTextureUsageShaderRead),
      MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate)
      };
    depthTexture = [textureLoader newTextureWithName:@"depth2"
                                         scaleFactor:1.0
                                              bundle:nil
                                             options:textureLoaderOptions
                                               error:&error];
    if(!depthTexture || error)
    {
        NSLog(@"Error creating texture %@", error.localizedDescription);
    }
    sourceTexture = [textureLoader newTextureWithName:@"origin2"
                                      scaleFactor:1.0
                                           bundle:nil
                                          options:textureLoaderOptions
                                            error:&error];
    sourceTexture.label = @"原图纹理";
    if(!sourceTexture || error)
    {
        NSLog(@"Error creating texture %@", error.localizedDescription);
    }
    
    MTLTextureDescriptor *texDes = [[MTLTextureDescriptor alloc] init];
    texDes.pixelFormat = sourceTexture.pixelFormat;
    texDes.width = sourceTexture.width;
    texDes.height = sourceTexture.height;
    texDes.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead;
    bgBlurTexture = [_device newTextureWithDescriptor:texDes];
    bgBlurTexture.label = @"模糊背景贴图";
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    MTLRenderPassDescriptor* curRenderDescriptor = view.currentRenderPassDescriptor;
    if(curRenderDescriptor !=  nil)
    {
        // MPS 高斯模糊
        MPSImageGaussianBlur *gaussianBlur = [[MPSImageGaussianBlur alloc] initWithDevice:_device sigma:15];
        [gaussianBlur encodeToCommandBuffer:commandBuffer sourceTexture:sourceTexture destinationTexture:bgBlurTexture];

        id<MTLRenderCommandEncoder> myRenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:curRenderDescriptor];
        
        // 镜头偏移
        Uniforms *uniforms = (Uniforms*)_uniformBuffer.contents;
        uniforms->camTanDir = self.V;
        uniforms->parallaxScale = self.parallaxScale;
        
        // 绘制RT到屏幕上
        [myRenderEncoder pushDebugGroup:@"DrawQuad"];
        [myRenderEncoder setDepthStencilState:_quadDepthState];
        [myRenderEncoder setCullMode:MTLCullModeNone];
        [myRenderEncoder setRenderPipelineState:_quadPipeline];
        [myRenderEncoder setVertexBuffer:_quadBuffer offset:0 atIndex:0];
        [myRenderEncoder setFragmentBuffer:_uniformBuffer offset:0 atIndex:0];
        [myRenderEncoder setFragmentTexture:sourceTexture atIndex:0];
        [myRenderEncoder setFragmentTexture:bgBlurTexture atIndex:1];
        [myRenderEncoder setFragmentTexture:depthTexture atIndex:2];
        [myRenderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [myRenderEncoder popDebugGroup];
        [myRenderEncoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
}
@end
