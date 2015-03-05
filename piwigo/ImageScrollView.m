//
//  ImageScrollView.m
//  piwigo
//
//  Created by Spencer Baker on 2/21/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageScrollView.h"

@interface ImageScrollView() <UIScrollViewDelegate>

@end

@implementation ImageScrollView

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.showsVerticalScrollIndicator = NO;
		self.showsHorizontalScrollIndicator = NO;
		self.bouncesZoom = YES;
		self.decelerationRate = UIScrollViewDecelerationRateFast;
		self.delegate = self;
		
		self.maximumZoomScale = 2.5;
		self.minimumZoomScale = 1.0;
		
		self.imageView = [UIImageView new];
		self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.imageView.contentMode = UIViewContentModeScaleAspectFit;
		[self addSubview:self.imageView];
		
	}
	return self;
}

-(UIView*)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
	return self.imageView;
}

-(void)setupPlayerWithURL:(NSString*)videoURL
{
	self.maximumZoomScale = 1.0;
	self.minimumZoomScale = 1.0;
	
	self.player = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL URLWithString:videoURL]];
	[self.player setControlStyle:MPMovieControlStyleDefault];
	self.player.scalingMode = MPMovieScalingModeAspectFit;
	self.player.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self  addSubview: self.player.view];
	[self  bringSubviewToFront:self.player.view];
	[self.player prepareToPlay];
	self.player.shouldAutoplay = NO;	
}

@end
