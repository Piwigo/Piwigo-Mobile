//
//  ImageScrollView.m
//  piwigo
//
//  Created by Spencer Baker on 2/21/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageScrollView.h"
#import "ImageDetailViewController.h"

@interface ImageScrollView() <UIScrollViewDelegate>

@property (nonatomic, assign) CGFloat previousScale;

@end

@implementation ImageScrollView

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		// Scroll settings
        self.showsVerticalScrollIndicator = NO;
        self.showsHorizontalScrollIndicator = NO;
        self.bouncesZoom = YES;
        self.decelerationRate = UIScrollViewDecelerationRateFast;
        self.delegate = self;

        self.maximumZoomScale = 5.0;
        self.minimumZoomScale = 1.0;
        self.previousScale = 0.0;
		
        // Image previewed
		self.imageView = [UIImageView new];
		self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.userInteractionEnabled = YES;
        [self addSubview:self.imageView];
        
        // Play button above posters of movie
        self.playImage = [UIImageView new];
        UIImage *play = [UIImage imageNamed:@"videoPlay"];
        self.playImage.image = [play imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.playImage.tintColor = [UIColor piwigoColorOrange];
        self.playImage.hidden = YES;
        self.playImage.translatesAutoresizingMaskIntoConstraints = NO;
        self.playImage.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:self.playImage];
        [self addConstraints:[NSLayoutConstraint constraintView:self.playImage to:CGSizeMake(50, 50)]];
        [self addConstraints:[NSLayoutConstraint constraintCenter:self.playImage]];
}
	return self;
}

-(UIView*)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
	return self.imageView;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale
{
    if ((scale == 1.0) && (self.previousScale == 1.0))
    {
        // The user scaled down twice the image => back to collection of images
        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationPinchedImage object:nil];

    } else {
        self.previousScale = scale;
    }
}

@end
