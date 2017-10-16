//
//  LocalImageCollectionViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>

#import "LocalImageCollectionViewCell.h"

@interface LocalImageCollectionViewCell()

@property (nonatomic, strong) UIImageView *selectedImage;
@property (nonatomic, strong) UIView *darkenView;

@property (nonatomic, strong) UIView *uploadingView;
@property (nonatomic, strong) UIProgressView *uploadingProgress;

@property (nonatomic, strong) UIImageView *playImage;

@end

@implementation LocalImageCollectionViewCell

-(instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self)
	{
		self.backgroundColor = [UIColor piwigoWhiteCream];
		self.cellSelected = NO;
		
		self.cellImage = [UIImageView new];
		self.cellImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.cellImage.contentMode = UIViewContentModeScaleAspectFill;
		self.cellImage.clipsToBounds = YES;
		self.cellImage.image = [UIImage imageNamed:@"placeholderImage"];
		[self.contentView addSubview:self.cellImage];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.cellImage]];
		
		self.darkenView = [UIView new];
		self.darkenView.translatesAutoresizingMaskIntoConstraints = NO;
		self.darkenView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
		self.darkenView.hidden = YES;
		[self.contentView addSubview:self.darkenView];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.darkenView]];
		
		self.selectedImage = [UIImageView new];
		self.selectedImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.selectedImage.contentMode = UIViewContentModeScaleAspectFit;
		UIImage *checkMark = [UIImage imageNamed:@"checkMark"];
		self.selectedImage.image = [checkMark imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		self.selectedImage.tintColor = [UIColor piwigoOrange];
		self.selectedImage.hidden = YES;
		[self.contentView addSubview:self.selectedImage];
		[self.contentView addConstraints:[NSLayoutConstraint constraintView:self.selectedImage toSize:CGSizeMake(25, 25)]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromRight:self.selectedImage amount:0]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromTop:self.selectedImage amount:5]];
		
		self.playImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"play"]];
		self.playImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.playImage.contentMode = UIViewContentModeScaleAspectFit;
		self.playImage.hidden = YES;
		[self.contentView addSubview:self.playImage];
		[self.contentView addConstraints:[NSLayoutConstraint constraintView:self.playImage toSize:CGSizeMake(40, 40)]];
		[self.contentView addConstraints:[NSLayoutConstraint constraintCenterView:self.playImage]];
		
		// uploading stuff:
		self.uploadingView = [UIView new];
		self.uploadingView.translatesAutoresizingMaskIntoConstraints = NO;
		self.uploadingView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
		self.uploadingView.hidden = YES;
		[self.contentView addSubview:self.uploadingView];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.uploadingView]];
		
		self.uploadingProgress = [UIProgressView new];
		self.uploadingProgress.translatesAutoresizingMaskIntoConstraints = NO;
		[self.uploadingView addSubview:self.uploadingProgress];
		[self.uploadingView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.uploadingProgress]];
		[self.uploadingView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[progress]-10-|"
																				   options:kNilOptions
																				   metrics:nil
																					 views:@{@"progress" : self.uploadingProgress}]];
		
		UILabel *uploadingLabel = [UILabel new];
		uploadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
		uploadingLabel.font = [UIFont piwigoFontNormal];
		uploadingLabel.textColor = [UIColor piwigoWhiteCream];
		uploadingLabel.text = NSLocalizedString(@"imageUploadTableCell_uploading", @"Uploading...");
		[self.uploadingView addSubview:uploadingLabel];
		[self.uploadingView addConstraint:[NSLayoutConstraint constraintCenterVerticalView:uploadingLabel]];
		[self.uploadingView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[label]-[progress]"
																				   options:kNilOptions
																				   metrics:nil
																					 views:@{@"progress" : self.uploadingProgress,
																							 @"label" : uploadingLabel}]];
		
	}
	return self;
}

-(void)setupWithImageAsset:(ALAsset*)imageAsset
{
	self.cellImage.image = [UIImage imageWithCGImage:[imageAsset thumbnail]];
	
	if ([[imageAsset valueForProperty:ALAssetPropertyType] isEqualToString:ALAssetTypeVideo])
	{
		self.playImage.hidden = NO;
	}
}

-(void)prepareForReuse
{
	self.cellImage.image = nil;
	self.cellSelected = NO;
	self.cellUploading = NO;
	self.playImage.hidden = YES;
	[self setProgress:0 withAnimation:NO];
}

-(void)setCellSelected:(BOOL)cellSelected
{
	_cellSelected = cellSelected;
	
	self.selectedImage.hidden = !cellSelected;
	self.darkenView.hidden = !cellSelected;
}

-(void)setCellUploading:(BOOL)uploading
{
	_cellUploading = uploading;
	
	self.uploadingView.hidden = !uploading;
}

-(void)setProgress:(CGFloat)progress
{
	[self setProgress:progress withAnimation:YES];
}

-(void)setProgress:(CGFloat)progress withAnimation:(BOOL)animate
{
	[self.uploadingProgress setProgress:progress animated:animate];
}

@end
