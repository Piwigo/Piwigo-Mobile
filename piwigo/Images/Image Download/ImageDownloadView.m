//
//  ImageDownloadView.m
//  piwigo
//
//  Created by Spencer Baker on 1/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageDownloadView.h"
#import "ImageDownloadingProgressView.h"

@interface ImageDownloadView()

@property (nonatomic, strong) UIView *modal;
@property (nonatomic, strong) ImageDownloadingProgressView *imageProgress;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, strong) UILabel *totalPercentLabel;

@end

@implementation ImageDownloadView

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
		
		self.modal = [UIView new];
		self.modal.translatesAutoresizingMaskIntoConstraints = NO;
		self.modal.backgroundColor = [UIColor piwigoWhiteCream];
		self.modal.layer.cornerRadius = 10;
		[self addSubview:self.modal];
		[self addConstraints:[NSLayoutConstraint constraintCenterView:self.modal]];
		[self addConstraints:[NSLayoutConstraint constraintView:self.modal toSize:CGSizeMake(200, 180)]];
		
		
		self.statusLabel = [UILabel new];
		self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.statusLabel.text = NSLocalizedString(@"downloadingImage", @"Downloading Image");
		self.statusLabel.font = [UIFont piwigoFontNormal];
		self.statusLabel.font = [self.statusLabel.font fontWithSize:18];
		self.statusLabel.textColor = [UIColor piwigoGray];
        self.statusLabel.textAlignment = NSTextAlignmentCenter;
		self.statusLabel.adjustsFontSizeToFitWidth = YES;
		self.statusLabel.minimumScaleFactor = 0.5;
		[self.modal addSubview:self.statusLabel];
		[self.modal addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-5-[status]-5-|"
																		   options:kNilOptions
																		   metrics:nil
																			 views:@{@"status" : self.statusLabel}]];
		[self.modal addConstraint:[NSLayoutConstraint constraintViewFromTop:self.statusLabel amount:10]];
		
		self.percentLabel = [UILabel new];
		self.percentLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.percentLabel.text = [NSString stringWithFormat:@"%@ %%", @(0)];
		self.percentLabel.font = [UIFont piwigoFontNormal];
		self.percentLabel.font = [self.percentLabel.font fontWithSize:15];
		self.percentLabel.textColor = [UIColor piwigoGrayLight];
		[self.modal addSubview:self.percentLabel];
		[self.modal addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.percentLabel]];
		
		self.totalPercentLabel = [UILabel new];
		self.totalPercentLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.totalPercentLabel.font = [UIFont piwigoFontNormal];
		self.totalPercentLabel.font = [self.totalPercentLabel.font fontWithSize:16.5];
		self.totalPercentLabel.textColor = [UIColor piwigoGray];
		[self.modal addSubview:self.totalPercentLabel];
		[self.modal addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.totalPercentLabel]];
		[self.modal addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.totalPercentLabel amount:10]];
		
		[self.modal addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[percent][total]"
																		   options:kNilOptions
																		   metrics:nil
																			 views:@{@"percent" : self.percentLabel,
																					 @"total" : self.totalPercentLabel}]];
		
		self.imageProgress = [ImageDownloadingProgressView new];
		self.imageProgress.translatesAutoresizingMaskIntoConstraints = NO;
		[self.modal addSubview:self.imageProgress];
		[self.modal addConstraints:[NSLayoutConstraint constraintCenterView:self.imageProgress]];
	}
	return self;
}

-(void)setDownloadImage:(UIImage *)downloadImage
{
	self.imageProgress.image = downloadImage;
}

-(void)setMultiImage:(BOOL)multiImage
{
	_multiImage = multiImage;
	
	if(multiImage)
	{
		self.statusLabel.text = NSLocalizedString(@"downloadingImages", @"Downloading Images");
	}
}

-(void)setPercentDownloaded:(CGFloat)percentDownloaded
{
	self.imageProgress.percent = percentDownloaded;
	NSInteger percent = percentDownloaded * 100;
	if(percent == 100) {
		self.percentLabel.text = NSLocalizedString(@"Complete", nil);
	} else {
		self.percentLabel.text = [NSString stringWithFormat:@"%@ %%", @(percent)];
	}
	
	if(self.multiImage)
	{
		CGFloat percentPerImage = 100 / self.totalImageDownloadCount;
		CGFloat currentImageProgress = percentPerImage * ((CGFloat)percent / 100);
		percent = ((((CGFloat)self.imageDownloadCount - 1) / self.totalImageDownloadCount) * 100) + currentImageProgress;
		self.totalPercentLabel.text = [NSString stringWithFormat:@"%@%% (%@/%@)", @(percent), @(self.imageDownloadCount), @(self.totalImageDownloadCount)];
	}
}

@end
