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

@end
