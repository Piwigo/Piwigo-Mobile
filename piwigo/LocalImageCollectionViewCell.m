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

@property (nonatomic, strong) UIImageView *selectedImage;

@end

@implementation LocalImageCollectionViewCell

-(instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self)
	{
		self.backgroundColor = [UIColor whiteColor];
		self.cellSelected = NO;
		
		self.cellImage = [UIImageView new];
		self.cellImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.cellImage.contentMode = UIViewContentModeScaleAspectFill;
		self.cellImage.clipsToBounds = YES;
		self.cellImage.image = [UIImage imageNamed:@"placeholder"];
		[self.contentView addSubview:self.cellImage];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.cellImage]];
		
		self.selectedImage = [UIImageView new];
		self.selectedImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.selectedImage.contentMode = UIViewContentModeScaleAspectFit;
		self.selectedImage.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
		self.selectedImage.layer.cornerRadius = 10;
		UIImage *checkMark = [UIImage imageNamed:@"checkMark"];
		self.selectedImage.image = [checkMark imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		self.selectedImage.tintColor = [UIColor piwigoOrange];
		self.selectedImage.hidden = YES;
		[self.contentView addSubview:self.selectedImage];
		[self.contentView addConstraints:[NSLayoutConstraint constrainViewToSize:self.selectedImage size:CGSizeMake(30, 30)]];
		[self.contentView addConstraint:[NSLayoutConstraint constrainViewFromRight:self.selectedImage amount:5]];
		[self.contentView addConstraint:[NSLayoutConstraint constrainViewFromTop:self.selectedImage amount:5]];
	}
	return self;
}

-(void)setupWithImageAsset:(ALAsset*)imageAsset
{
	self.cellImage.image = [UIImage imageWithCGImage:[imageAsset thumbnail]];
}

-(void)prepareForReuse
{
	self.cellImage.image = nil;
}

-(void)setCellSelected:(BOOL)cellSelected
{
	_cellSelected = cellSelected;
	
	self.selectedImage.hidden = !cellSelected;
}

@end
