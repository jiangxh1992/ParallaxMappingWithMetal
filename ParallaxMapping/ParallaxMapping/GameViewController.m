//
//  GameViewController.m
//  ParallaxMapping
//
//  Created by Xinhou Jiang on 2020/2/4.
//  Copyright © 2020 Xinhou Jiang. All rights reserved.
//

#import "GameViewController.h"
#import "Renderer.h"
#import <CoreMotion/CoreMotion.h>

@implementation GameViewController
{
    MTKView *_view;

    Renderer *_renderer;
    CMMotionManager *_motionManager;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _view = (MTKView *)self.view;
    _view.device = MTLCreateSystemDefaultDevice();
    _view.backgroundColor = UIColor.blackColor;
    if(!_view.device)
    {
        NSLog(@"Metal is not supported on this device");
        self.view = [[UIView alloc] initWithFrame:self.view.frame];
        return;
    }
    
    // 渲染器
    _renderer = [[Renderer alloc] initWithMetalKitView:_view];
    [_renderer mtkView:_view drawableSizeWillChange:_view.bounds.size];
    _view.delegate = _renderer;
    
    _renderer.parallaxScale = - 0.2; // 镜头偏移敏感度设置，符号表示方向
    
    // 陀螺仪
    _motionManager = [[CMMotionManager alloc] init];
    if(![_motionManager isGyroAvailable])
    {
        NSLog(@"陀螺仪不可用");
        return;
    }
    _motionManager.gyroUpdateInterval = 0.1;
    [_motionManager startDeviceMotionUpdatesToQueue:[[NSOperationQueue alloc] init] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        // 传入陀螺仪参数到render
        self->_renderer.V = (vector_float3){motion.gravity.x, motion.gravity.y, motion.gravity.z};
    }];
}

@end
