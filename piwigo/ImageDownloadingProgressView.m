//
//  ImageDownloadingProgressView.m
//  piwigo
//
//  Created by Spencer Baker on 1/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageDownloadingProgressView.h"

@interface ImageDownloadingProgressView()

@property (nonatomic, strong) UIImageView *downloadingImage;
@property (nonatomic, strong) UIImageView *downloadingImageSilhouette;
@property (nonatomic, strong) NSLayoutConstraint *imageHeightConstraint;

@end

@implementation ImageDownloadingProgressView

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.downloadingImageSilhouette = [UIImageView new];
		self.downloadingImageSilhouette.translatesAutoresizingMaskIntoConstraints = NO;
		self.downloadingImageSilhouette.contentMode = UIViewContentModeBottom;
		self.downloadingImageSilhouette.clipsToBounds = YES;
		self.downloadingImageSilhouette.alpha = 0.1;
		[self addSubview:self.downloadingImageSilhouette];
		[self addConstraints:[NSLayoutConstraint constraintCenterView:self.downloadingImageSilhouette]];
		
		self.downloadingImage = [UIImageView new];
		self.downloadingImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.downloadingImage.contentMode = UIViewContentModeBottom;
		self.downloadingImage.clipsToBounds = YES;
		[self addSubview:self.downloadingImage];
		[self addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.downloadingImage amount:33]];
		[self addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.downloadingImage]];
		[self addConstraint:[NSLayoutConstraint constraintView:self.downloadingImage toWidth:150]];
		self.imageHeightConstraint = [NSLayoutConstraint constraintView:self.downloadingImage toHeight:0];
		[self addConstraint:self.imageHeightConstraint];
		
		[self addConstraint:[NSLayoutConstraint constraintWithItem:self.downloadingImageSilhouette
															   attribute:NSLayoutAttributeBottom
															   relatedBy:NSLayoutRelationEqual
																  toItem:self.downloadingImage
															   attribute:NSLayoutAttributeBottom
															  multiplier:1.0
																constant:0]];
	}
	return self;
}

-(void)setImage:(UIImage *)image
{
	CGSize newSize = CGSizeMake(150, 80);
	CGSize scaledSize = newSize;
	float scaleFactor = 80 / image.size.height;
	scaledSize.width = image.size.width * scaleFactor;
	scaledSize.height = 80;
	
	UIGraphicsBeginImageContextWithOptions( scaledSize, NO, 0.0 );
	CGRect scaledImageRect = CGRectMake( 0.0, 0.0, scaledSize.width, scaledSize.height );
	[image drawInRect:scaledImageRect];
	UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	_image = scaledImage;
	
	self.downloadingImage.image = scaledImage;
	self.downloadingImageSilhouette.image = scaledImage;
}

-(void)setPercent:(CGFloat)percent
{
	self.imageHeightConstraint.constant = 80 * percent;
}

@end
