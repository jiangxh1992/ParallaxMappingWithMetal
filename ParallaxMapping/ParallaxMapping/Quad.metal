//
//  File.metal
//  ParallaxMapping
//
//  Created by Xinhou Jiang on 2020/2/4.
//  Copyright © 2020 Xinhou Jiang. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "ShaderTypes.h"

struct VSOutput
{
    float4 pos [[position]];
    float2 texcoord;
};
struct FSOutput
{
    half4 frag_data [[color(0)]];
};

/*** 顶点着色器 ***/
vertex VSOutput vertexQuadMain(uint vertexID [[ vertex_id]],
                               constant AAPLVertex *vertexArr [[buffer(0)]])
{
    VSOutput out;
    out.pos = vector_float4(vertexArr[vertexID].position,0.0,1.0);
    out.pos.y *= 0.25;
    out.texcoord = vertexArr[vertexID].textureCoordinate;
    return out;
}

/*** 带偏移上限的视差映射 ***/
float2 ParallaxMapping(texture2d<half> depthTexture, sampler textureSampler, float3 V, float2 T0)
{
    float scale = 1.0;
    half H0 = depthTexture.sample(textureSampler, T0).x;
    float2 currentTextureCoords = T0 + V.xy * H0 * scale;

    return currentTextureCoords;
}
fragment FSOutput fragmentQuadMain(VSOutput input [[stage_in]],
                                   constant Uniforms & uniforms [[buffer(0)]],
                                   texture2d<half> colorTexture [[ texture(0) ]],
                                   texture2d<half> depthTexture [[ texture(1) ]])
{
    FSOutput out;
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
        
    // 映射算法
    float scale = -0.15f;
    float2 offset = uniforms.camTanDir.xy * scale;
    float3 V = float3(offset,1.0);
    float2 parallaxCoord = ParallaxMapping(depthTexture,textureSampler,normalize(V),input.texcoord);
    
    // 采样贴图
    const half4 colorSample = colorTexture.sample(textureSampler, parallaxCoord);
    
    // return the color of the texture
    out.frag_data = colorSample;
    return out;
}
