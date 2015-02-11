//
//  ImageUploadTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/5/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageUploadTableViewCell.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "PhotosFetch.h"
#import "ImageUpload.h"

@interface ImageUploadTableViewCell()

@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UILabel *imageTitle;
@property (weak, nonatomic) IBOutlet UILabel *author;
@property (weak, nonatomic) IBOutlet UILabel *tags;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;

@property (nonatomic, strong) UIView *uploadingOverlay;
@property (nonatomic, strong) UIProgressView *uploadingProgressBar;
@property (nonatomic, strong) UILabel *uploadingProgressLabel;

@end

@implementation ImageUploadTableViewCell

- (void)awakeFromNib {
    // Initialization code
	
	self.uploadingOverlay = [UIView new];
	self.uploadingOverlay.translatesAutoresizingMaskIntoConstraints = NO;
	self.uploadingOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
	self.uploadingOverlay.hidden = YES;
	[self.contentView addSubview:self.uploadingOverlay];
	[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.uploadingOverlay]];
	
	self.uploadingProgressBar = [UIProgressView new];
	self.uploadingProgressBar.translatesAutoresizingMaskIntoConstraints = NO;
	[self.uploadingOverlay addSubview:self.uploadingProgressBar];
	[self.uploadingOverlay addConstraint:[NSLayoutConstraint constraintVerticalCenterView:self.uploadingProgressBar]];
	[self.uploadingOverlay addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-20-[bar]-20-|"
																				  options:kNilOptions
																				  metrics:nil
																					views:@{@"bar" : self.uploadingProgressBar}]];
	
	self.uploadingProgressLabel = [UILabel new];
	self.uploadingProgressLabel.translatesAutoresizingMaskIntoConstraints = NO;
	self.uploadingProgressLabel.font = [UIFont piwigoFontNormal];
	self.uploadingProgressLabel.textColor = [UIColor whiteColor];
	self.uploadingProgressLabel.text = @"0 %";
	[self.uploadingOverlay addSubview:self.uploadingProgressLabel];
	[self.uploadingOverlay addConstraint:[NSLayoutConstraint constraintHorizontalCenterView:self.uploadingProgressLabel]];
	[self.uploadingOverlay addConstraint:[NSLayoutConstraint constraintWithItem:self.uploadingProgressLabel
																	  attribute:NSLayoutAttributeBottom
																	  relatedBy:NSLayoutRelationEqual
																		 toItem:self.uploadingProgressBar
																	  attribute:NSLayoutAttributeTop
																	 multiplier:1.0
																	   constant:-10]];
	
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)setupWithImageInfo:(ImageUpload*)imageInfo
{
	self.imageUploadInfo = imageInfo;
	
	ALAsset *imageAsset = [[PhotosFetch sharedInstance] getImageAssetForImageName:imageInfo.image];
	self.image.image = [UIImage imageWithCGImage:[imageAsset thumbnail]];
	
	self.imageTitle.text = imageInfo.imageUploadName;
	self.author.text = imageInfo.author;
	self.tags.text = imageInfo.tags;
	self.descriptionLabel.text = imageInfo.imageDescription;
}

-(void)setIsInQueueForUpload:(BOOL)isInQueueForUpload
{
	_isInQueueForUpload = isInQueueForUpload;
	
	self.uploadingOverlay.hidden = !isInQueueForUpload;
}

-(void)setImageProgress:(CGFloat)imageProgress
{
	_imageProgress = imageProgress;
	
	if(imageProgress != 1)
	{
		[self.uploadingProgressBar setProgress:imageProgress animated:YES];
		NSInteger percent = imageProgress * 100;
		self.uploadingProgressLabel.text = [NSString stringWithFormat:@"%@ %%", @(percent)];
	}
	else
	{
		[self.uploadingProgressBar setProgress:1.0 animated:YES];
		self.uploadingProgressLabel.text = @"Completed! Finishing up...";
	}
}

-(void)prepareForReuse
{
	self.image.image = nil;
	self.imageTitle.text = @"";
	self.imageTitle.text = @"";
	self.author.text = @"";
	self.tags.text = @"";
	self.descriptionLabel.text = @"";
	
	self.isInQueueForUpload = NO;
	[self.uploadingProgressBar setProgress:0];
}

@end
