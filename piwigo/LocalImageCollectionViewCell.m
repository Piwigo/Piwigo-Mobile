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

@end
