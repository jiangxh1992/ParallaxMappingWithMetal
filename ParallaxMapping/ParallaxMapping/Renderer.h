//
//  Renderer.h
//  ParallaxMapping
//
//  Created by Xinhou Jiang on 2020/2/4.
//  Copyright © 2020 Xinhou Jiang. All rights reserved.
//

#import <MetalKit/MetalKit.h>

// Our platform independent renderer class.   Implements the MTKViewDelegate protocol which
//   allows it to accept per-frame update and drawable resize callbacks.
@interface Renderer : NSObject <MTKViewDelegate>

@property(nonatomic, assign) vector_float3 V;
-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;

@end

