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

@end

@implementation ImageCollectionViewCell

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
		bottomLayer.backgroundColor = [UIColor piwigoGray];
		bottomLayer.alpha = 0.6;
		[self.contentView addSubview:bottomLayer];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillWidth:bottomLayer]];
		[self.contentView addConstraint:[NSLayoutConstraint constrainViewFromBottom:bottomLayer amount:0]];
		
		self.nameLabel = [UILabel new];
		self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.nameLabel.font = [UIFont piwigoFontNormal];
		self.nameLabel.textColor = [UIColor piwigoOrange];
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

-(void)setupWithImageData:(PiwigoImageData*)imageData
{
	self.imageData = imageData;
	
	[self.cellImage setImageWithURL:[NSURL URLWithString:self.imageData.thumbPath] placeholderImage:[UIImage imageNamed:@"placeholder"]];
	self.nameLabel.text = imageData.name;
}

-(void)prepareForReuse
{
	self.cellImage.image = nil;
}

@end
