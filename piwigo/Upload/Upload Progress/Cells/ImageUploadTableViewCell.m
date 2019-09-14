//
//  ImageUploadTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/5/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "ImageUploadTableViewCell.h"
#import "PhotosFetch.h"
#import "ImageUpload.h"
#import "Model.h"
#import "TagsData.h"

@interface ImageUploadTableViewCell()

@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UILabel *imageTitle;
@property (weak, nonatomic) IBOutlet UILabel *author;
@property (weak, nonatomic) IBOutlet UILabel *tags;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UILabel *privacyLevel;

@property (weak, nonatomic) IBOutlet UIView *imageTitleUnderline;
@property (weak, nonatomic) IBOutlet UIView *authorUnderline;
@property (weak, nonatomic) IBOutlet UIView *privacyUnderline;
@property (weak, nonatomic) IBOutlet UIView *tagsUnderline;

@property (nonatomic, strong) UIView *uploadingOverlay;
@property (nonatomic, strong) UIProgressView *uploadingProgressBar;
@property (nonatomic, strong) UILabel *uploadingProgressLabel;

@end

@implementation ImageUploadTableViewCell

- (void)awakeFromNib {
    
    // Initialization code
    [super awakeFromNib];
	
	self.uploadingOverlay = [UIView new];
	self.uploadingOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.uploadingOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
	self.uploadingOverlay.hidden = YES;
	[self.contentView addSubview:self.uploadingOverlay];
	[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.uploadingOverlay]];
	
	self.uploadingProgressBar = [UIProgressView new];
	self.uploadingProgressBar.translatesAutoresizingMaskIntoConstraints = NO;
	[self.uploadingOverlay addSubview:self.uploadingProgressBar];
    [self.uploadingOverlay addConstraint:[NSLayoutConstraint constraintViewFromTop:self.uploadingProgressBar amount:97.0]];
	[self.uploadingOverlay addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-20-[bar]-20-|"
																				  options:kNilOptions
																				  metrics:nil
																					views:@{@"bar" : self.uploadingProgressBar}]];
	
	self.uploadingProgressLabel = [UILabel new];
	self.uploadingProgressLabel.translatesAutoresizingMaskIntoConstraints = NO;
	self.uploadingProgressLabel.font = [UIFont piwigoFontNormal];
	self.uploadingProgressLabel.textColor = [UIColor whiteColor];
	self.uploadingProgressLabel.text = [NSString stringWithFormat:@"%@ %%", @(0)];
	[self.uploadingOverlay addSubview:self.uploadingProgressLabel];
	[self.uploadingOverlay addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.uploadingProgressLabel]];
	[self.uploadingOverlay addConstraint:[NSLayoutConstraint constraintWithItem:self.uploadingProgressLabel
																	  attribute:NSLayoutAttributeBottom
																	  relatedBy:NSLayoutRelationEqual
																		 toItem:self.uploadingProgressBar
																	  attribute:NSLayoutAttributeTop
																	 multiplier:1.0
																	   constant:-10]];
	
    self.rightSwipeSettings.transition = MGSwipeTransitionBorder;
    self.rightButtons = @[[MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"swipeCancel"]
                                         backgroundColor:[UIColor redColor]
                                                callback:^BOOL(MGSwipeTableCell *sender) {
                                                    return YES;
                                                }]];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)setupWithImageInfo:(ImageUpload*)imageInfo
{
	self.imageUploadInfo = imageInfo;
    
    // Image thumbnail
	PHAsset *imageAsset = self.imageUploadInfo.imageAsset;
    NSInteger retinaScale = [UIScreen mainScreen].scale;
    CGSize retinaSquare = CGSizeMake(90*retinaScale, 90*retinaScale);       // See ImageUploadCell.xib
    
    PHImageRequestOptions *cropToSquare = [[PHImageRequestOptions alloc] init];
    cropToSquare.resizeMode = PHImageRequestOptionsResizeModeExact;
    
    CGFloat cropSideLength = MIN(imageAsset.pixelWidth, imageAsset.pixelHeight);
    CGRect square = CGRectMake(0, 0, cropSideLength, cropSideLength);
    CGRect cropRect = CGRectApplyAffineTransform(square,
                                                 CGAffineTransformMakeScale(1.0 / imageAsset.pixelWidth,
                                                                            1.0 / imageAsset.pixelHeight));
    cropToSquare.normalizedCropRect = cropRect;
    
    [[PHImageManager defaultManager] requestImageForAsset:(PHAsset *)imageAsset
                                               targetSize:retinaSquare
                                              contentMode:PHImageContentModeAspectFit
                                                  options:cropToSquare
                                            resultHandler:^(UIImage *result, NSDictionary *info) {
                                                self.image.image = result;
                                                self.image.layer.cornerRadius = 6;
                                            }
     ];
	
    // Image properties
	self.imageTitle.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"imageUploadDetails_title", @"Title:"), imageInfo.title];
    self.imageTitle.textColor = [UIColor piwigoLeftLabelColor];
    self.imageTitleUnderline.backgroundColor = [UIColor piwigoUnderlineColor];
    
    if ([imageInfo.author isEqualToString:@"NSNotFound"]) {
        self.author.text = NSLocalizedString(@"imageUploadDetails_author", @"Author:");
    } else {
        self.author.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"imageUploadDetails_author", @"Author:"), imageInfo.author];
    }
    self.author.textColor = [UIColor piwigoLeftLabelColor];
    self.authorUnderline.backgroundColor = [UIColor piwigoUnderlineColor];

	self.privacyLevel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"imageUploadDetails_privacy", @"Privacy:"), [[Model sharedInstance] getNameForPrivacyLevel:imageInfo.privacyLevel]];
    self.privacyLevel.textColor = [UIColor piwigoLeftLabelColor];
    self.privacyUnderline.backgroundColor = [UIColor piwigoUnderlineColor];

	self.tags.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"imageUploadDetails_tags", @"Tags:"), [[TagsData sharedInstance] getTagsStringFromList:imageInfo.tags]];
    self.tags.textColor = [UIColor piwigoLeftLabelColor];
    self.tagsUnderline.backgroundColor = [UIColor piwigoUnderlineColor];

	self.descriptionLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"imageUploadDetails_description", @"Description:"), imageInfo.imageDescription];
    self.descriptionLabel.textColor = [UIColor piwigoLeftLabelColor];
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
		self.uploadingProgressLabel.text = NSLocalizedString(@"imageUploadDetailsCell_uploadComplete", @"Completed! Finishing up...");
	}
}

-(void)prepareForReuse
{
    [super prepareForReuse];
    
    self.image.image = nil;
	self.imageTitle.text = @"";
    self.privacyLevel.text = @"";
	self.author.text = @"";
	self.tags.text = @"";
	self.descriptionLabel.text = @"";
	
	self.isInQueueForUpload = NO;
	[self.uploadingProgressBar setProgress:0];
	self.uploadingProgressLabel.text = [NSString stringWithFormat:@"%@ %%", @(0)];
}

@end
