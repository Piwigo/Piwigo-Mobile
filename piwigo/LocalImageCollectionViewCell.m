//
//  LocalImageCollectionViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "LocalImageCollectionViewCell.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface LocalImageCollectionViewCell()

@property (nonatomic, strong) UILabel *nameLabel;

@end

@implementation LocalImageCollectionViewCell

-(instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self)
	{
		self.backgroundColor = [UIColor whiteColor];
		
		self.cellImage = [UIImageView new];
		self.cellImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.cellImage.contentMode = UIViewContentModeScaleAspectFill;
		self.cellImage.clipsToBounds = YES;
		self.cellImage.image = [UIImage imageNamed:@"placeholder"];
		[self.contentView addSubview:self.cellImage];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.cellImage]];
		
		UIView *bottomLayer = [UIView new];
		bottomLayer.translatesAutoresizingMaskIntoConstraints = NO;
		bottomLayer.backgroundColor = [UIColor piwigoOrange];
		bottomLayer.alpha = 0.6;
		[self.contentView addSubview:bottomLayer];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillWidth:bottomLayer]];
		[self.contentView addConstraint:[NSLayoutConstraint constrainViewFromBottom:bottomLayer amount:0]];
		
		self.nameLabel = [UILabel new];
		self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.nameLabel.font = [UIFont piwigoFontNormal];
		self.nameLabel.textColor = [UIColor whiteColor];
		self.nameLabel.adjustsFontSizeToFitWidth = YES;
		self.nameLabel.minimumScaleFactor = 0.5;
		[self.contentView addSubview:self.nameLabel];
		[self.contentView addConstraint:[NSLayoutConstraint constraintHorizontalCenterView:self.nameLabel]];
		[self.contentView addConstraint:[NSLayoutConstraint constrainViewFromBottom:self.nameLabel amount:5]];
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
	}
	return self;
}

-(void)setupWithImageAsset:(ALAsset*)imageAsset
{
	self.cellImage.image = [UIImage imageWithCGImage:[imageAsset thumbnail]];
	self.nameLabel.text = [[imageAsset defaultRepresentation] filename];
}

-(void)prepareForReuse
{
	self.cellImage.image = nil;
}

@end
