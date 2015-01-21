//
//  DirectoryImageTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "DirectoryImageTableViewCell.h"

@interface DirectoryImageTableViewCell()


@end

@implementation DirectoryImageTableViewCell

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if(self)
	{
		self.thumbnail = [UIImageView new];
		self.thumbnail.translatesAutoresizingMaskIntoConstraints = NO;
		[self.contentView addSubview:self.thumbnail];
		
		self.imageName = [UILabel new];
		self.imageName.translatesAutoresizingMaskIntoConstraints = NO;
		[self.contentView addSubview:self.imageName];
		
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillHeight:self.thumbnail]];
		[self.thumbnail addConstraint:[NSLayoutConstraint constrainViewWidthToEqualHeight:self.thumbnail]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintVerticalCenterView:self.imageName]];
		[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[thumb]-15-[name]"
																				 options:kNilOptions
																				 metrics:nil
																				   views:@{@"thumb" : self.thumbnail,
																						   @"name" : self.imageName}]];
		
	}
	return self;
}

-(void)prepareForReuse
{
	[super prepareForReuse];
	
	[self.thumbnail cancelImageRequestOperation];
	self.thumbnail.image = nil;
}

@end
