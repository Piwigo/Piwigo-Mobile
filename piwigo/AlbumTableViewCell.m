//
//  AlbumTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumTableViewCell.h"
#import "PiwigoAlbumData.h"

@implementation AlbumTableViewCell

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if(self)
	{
		
		self.thumbnail = [UIImageView new];
		self.thumbnail.translatesAutoresizingMaskIntoConstraints = NO;
		self.thumbnail.contentMode = UIViewContentModeScaleAspectFill;
		self.thumbnail.clipsToBounds = YES;
		[self.contentView addSubview:self.thumbnail];
		
		self.albumName = [UILabel new];
		self.albumName.translatesAutoresizingMaskIntoConstraints = NO;
		[self.contentView addSubview:self.albumName];
		
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillHeight:self.thumbnail]];
		[self.thumbnail addConstraint:[NSLayoutConstraint constrainViewWidthToEqualHeight:self.thumbnail]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintVerticalCenterView:self.albumName]];
		[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[thumb]-15-[name]"
																				 options:kNilOptions
																				 metrics:nil
																				   views:@{@"thumb" : self.thumbnail,
																						   @"name" : self.albumName}]];
	}
	return self;
}

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData
{
	self.albumData = albumData;
	
	self.albumName.text = self.albumData.name;
	
	__weak typeof(self) weakSelf = self;
	[self.thumbnail setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.albumData.albumThumbnailUrl]]
						  placeholderImage:nil
								   success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
									   weakSelf.thumbnail.image = image;
								   } failure:nil];
}

-(void)prepareForReuse
{
	[super prepareForReuse];
	
	[self.thumbnail cancelImageRequestOperation];
	self.thumbnail.image = nil;
}

@end
