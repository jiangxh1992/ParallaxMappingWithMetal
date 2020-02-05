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

/*** 陡峭视差映射函数 ***/
float2 ParallaxMapping(texture2d<half> depthTexture, sampler textureSampler, float3 V, float2 T)
{
   // 采样层数
   float numLayers = 20;
   // 每一层的高度
   float layerHeight = 1.0 / numLayers;
   // 当前层深度
   float currentLayerHeight = 0;
   // 每一层之间纹理坐标的偏移
   float2 dtex = V.xy / numLayers;

   // 当前纹理坐标
   float2 currentTextureCoords = T;

   // 原始位置的初始深度值
   half heightFromTexture = depthTexture.sample(textureSampler, currentTextureCoords).x;

   // 比对采样层深度和当前深度图的值，找到最接近的采样交点
   while(heightFromTexture > currentLayerHeight)
   {
      // 下一层的深度
      currentLayerHeight += layerHeight;
      // 纹理坐标递进偏移
      currentTextureCoords -= dtex;
      // 获取当前的深度图值
      heightFromTexture = depthTexture.sample(textureSampler, currentTextureCoords).x;
   }

    // 解决深度图断崖拖影问题
    if(currentLayerHeight - heightFromTexture > layerHeight) currentTextureCoords += dtex;
    
   //parallaxHeight = currentLayerHeight;
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
