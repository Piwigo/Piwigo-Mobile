//
//  VideoView.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/11/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

#import "VideoView.h"
#import "NetworkHandler.h"

@interface VideoView() <AVPlayerViewControllerDelegate>

@end

@implementation VideoView

-(instancetype)init
{
    self = [super init];
    if(self)
    {
        self.videoView = [UIView new];
        self.videoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.videoView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:self.videoView];
    }
    return self;
}

@end

