//
//  ImageUploadTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/5/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageUploadTableViewCell.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "ImageUpload.h"

@interface ImageUploadTableViewCell()

@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UILabel *imageTitle;
@property (weak, nonatomic) IBOutlet UILabel *author;
@property (weak, nonatomic) IBOutlet UILabel *tags;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;

@end

@implementation ImageUploadTableViewCell

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)setupWithImageInfo:(ImageUpload*)imageInfo
{
	self.imageTitle.text = imageInfo.imageUploadName;
	self.author.text = imageInfo.author;
	self.tags.text = imageInfo.tags;
	self.descriptionLabel.text = imageInfo.imageDescription;
}

@end
