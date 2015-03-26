//
//  ImageCollectionViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageCollectionViewCell.h"
#import "PiwigoImageData.h"

@interface ImageCollectionViewCell()

@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIImageView *selectedImage;
@property (nonatomic, strong) UIView *darkenView;
@property (nonatomic, strong) UIImageView *playImage;
@property (nonatomic, strong) UILabel *noDataLabel;

@end

@implementation ImageCollectionViewCell

-(instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self)
	{
		self.backgroundColor = [UIColor whiteColor];
		self.isSelected = NO;
		
		self.cellImage = [UIImageView new];
		self.cellImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.cellImage.contentMode = UIViewContentModeScaleAspectFill;
		self.cellImage.clipsToBounds = YES;
		self.cellImage.image = [UIImage imageNamed:@"placeholder"];
		[self.contentView addSubview:self.cellImage];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.cellImage]];
		
		self.darkenView = [UIView new];
		self.darkenView.translatesAutoresizingMaskIntoConstraints = NO;
		self.darkenView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
		self.darkenView.hidden = YES;
		[self.contentView addSubview:self.darkenView];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.darkenView]];
		
		self.playImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"play"]];
		self.playImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.playImage.contentMode = UIViewContentModeScaleAspectFit;
		self.playImage.hidden = YES;
		[self.contentView addSubview:self.playImage];
		[self.contentView addConstraints:[NSLayoutConstraint constraintView:self.playImage toSize:CGSizeMake(40, 40)]];
		[self.contentView addConstraints:[NSLayoutConstraint constraintCenterView:self.playImage]];
		
		UIView *bottomLayer = [UIView new];
		bottomLayer.translatesAutoresizingMaskIntoConstraints = NO;
		bottomLayer.backgroundColor = [UIColor piwigoGray];
		bottomLayer.alpha = 0.6;
		[self.contentView addSubview:bottomLayer];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillWidth:bottomLayer]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromBottom:bottomLayer amount:0]];
		
		self.nameLabel = [UILabel new];
		self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.nameLabel.font = [UIFont piwigoFontNormal];
		self.nameLabel.textColor = [UIColor piwigoOrange];
		self.nameLabel.adjustsFontSizeToFitWidth = YES;
		self.nameLabel.minimumScaleFactor = 0.5;
		[self.contentView addSubview:self.nameLabel];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.nameLabel]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.nameLabel amount:5]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.nameLabel
																	 attribute:NSLayoutAttributeLeft
																	 relatedBy:NSLayoutRelationGreaterThanOrEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeLeft
																	multiplier:1.0
																	  constant:5]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.nameLabel
																	 attribute:NSLayoutAttributeRight
																	 relatedBy:NSLayoutRelationLessThanOrEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeRight
																	multiplier:1.0
																	  constant:5]];
		
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:bottomLayer
																	 attribute:NSLayoutAttributeTop
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.nameLabel
																	 attribute:NSLayoutAttributeTop
																	multiplier:1.0
																	  constant:-5]];
		
		self.selectedImage = [UIImageView new];
		self.selectedImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.selectedImage.contentMode = UIViewContentModeScaleAspectFit;
		UIImage *checkMark = [UIImage imageNamed:@"checkMark"];
		self.selectedImage.image = [checkMark imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		self.selectedImage.tintColor = [UIColor piwigoOrange];
		self.selectedImage.hidden = YES;
		[self.contentView addSubview:self.selectedImage];
		[self.contentView addConstraints:[NSLayoutConstraint constraintView:self.selectedImage toSize:CGSizeMake(30, 30)]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromRight:self.selectedImage amount:5]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromTop:self.selectedImage amount:5]];
		
		self.noDataLabel = [UILabel new];
		self.noDataLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.noDataLabel.font = [UIFont piwigoFontNormal];
		self.noDataLabel.textColor = [UIColor redColor];
		self.noDataLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
		self.noDataLabel.layer.cornerRadius = 3.0;
		self.noDataLabel.text = NSLocalizedString(@"categoryImageList_noDataError", @"Error No Data");
		self.noDataLabel.hidden = YES;
		[self.contentView addSubview:self.noDataLabel];
		[self.contentView addConstraints:[NSLayoutConstraint constraintCenterView:self.noDataLabel]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.noDataLabel
																	 attribute:NSLayoutAttributeLeft
																	 relatedBy:NSLayoutRelationGreaterThanOrEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeLeft
																	multiplier:1.0
																	  constant:0]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.noDataLabel
																	 attribute:NSLayoutAttributeRight
																	 relatedBy:NSLayoutRelationLessThanOrEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeRight
																	multiplier:1.0
																	  constant:0]];
	}
	return self;
}

-(void)setupWithImageData:(PiwigoImageData*)imageData
{
	self.imageData = imageData;

	if(!self.imageData || !self.imageData.thumbPath || self.imageData.thumbPath.length <= 0)
	{
		self.noDataLabel.hidden = NO;
		return;
	}
	
	[self.cellImage setImageWithURL:[NSURL URLWithString:self.imageData.thumbPath] placeholderImage:[UIImage imageNamed:@"placeholder"]];
	self.nameLabel.text = imageData.name;
	
	if(imageData.isVideo)
	{
		self.darkenView.hidden = NO;
		self.playImage.hidden = NO;
	}
}

-(void)prepareForReuse
{
	self.cellImage.image = nil;
	self.isSelected = NO;
	self.playImage.hidden = YES;
	self.noDataLabel.hidden = YES;
}

-(void)setIsSelected:(BOOL)isSelected
{
	_isSelected = isSelected;

	self.selectedImage.hidden = !isSelected;
	self.darkenView.hidden = !isSelected;
}

@end
