//
//  LocalImageCollectionViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

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
		self.backgroundColor = [UIColor piwigoCellBackgroundColor];
		self.cellSelected = NO;
		
		// Image
        self.cellImage = [UIImageView new];
		self.cellImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.cellImage.contentMode = UIViewContentModeScaleAspectFill;
		self.cellImage.clipsToBounds = YES;
		self.cellImage.image = [UIImage imageNamed:@"placeholderImage"];
		[self.contentView addSubview:self.cellImage];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.cellImage]];
		
        // Darken view
		self.darkenView = [UIView new];
		self.darkenView.translatesAutoresizingMaskIntoConstraints = NO;
		self.darkenView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
		self.darkenView.hidden = YES;
		[self.contentView addSubview:self.darkenView];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.darkenView]];
		
        // Selected image
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
		
        // Movie type
        self.playImage = [UIImageView new];
        UIImage *play = [UIImage imageNamed:@"video"];
        self.playImage.image = [play imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.playImage.tintColor = [UIColor piwigoOrange];
        self.playImage.hidden = YES;
        self.playImage.translatesAutoresizingMaskIntoConstraints = NO;
        self.playImage.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:self.playImage];
        [self.contentView addConstraints:[NSLayoutConstraint constraintView:self.playImage toSize:CGSizeMake(25, 25)]];
        [self.contentView addConstraint:[NSLayoutConstraint constraintViewFromLeft:self.playImage amount:5]];
        [self.contentView addConstraint:[NSLayoutConstraint constraintViewFromTop:self.playImage amount:5]];

        // Uploading stuff: mask
		self.uploadingView = [UIView new];
		self.uploadingView.translatesAutoresizingMaskIntoConstraints = NO;
		self.uploadingView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
		self.uploadingView.hidden = YES;
		[self.contentView addSubview:self.uploadingView];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.uploadingView]];
		
        // Uploading stuff: progress bar
		self.uploadingProgress = [UIProgressView new];
		self.uploadingProgress.translatesAutoresizingMaskIntoConstraints = NO;
        self.uploadingProgress.progressTintColor = [UIColor piwigoOrange];
        self.uploadingProgress.trackTintColor = [UIColor piwigoLeftLabelColor];
		[self.uploadingView addSubview:self.uploadingProgress];
		[self.uploadingView addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.uploadingProgress]];
        [self.uploadingView addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.uploadingProgress amount:10]];
		[self.uploadingView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[progress]-10-|"
                   options:kNilOptions
                   metrics:nil
                     views:@{@"progress" : self.uploadingProgress}]];
		
        // Uploading stuff: label
		UILabel *uploadingLabel = [UILabel new];
		uploadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
		uploadingLabel.font = [UIFont piwigoFontSmall];
		uploadingLabel.textColor = [UIColor piwigoOrange];
		uploadingLabel.text = NSLocalizedString(@"imageUploadTableCell_uploading", @"Uploading...");
        uploadingLabel.adjustsFontSizeToFitWidth = YES;
        uploadingLabel.minimumScaleFactor = 0.4;
		[self.uploadingView addSubview:uploadingLabel];
		[self.uploadingView addConstraint:[NSLayoutConstraint constraintCenterVerticalView:uploadingLabel]];
        [self.uploadingView addConstraint:[NSLayoutConstraint constraintViewFromBottom:uploadingLabel amount:16]];
        [self.uploadingView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[uploading]-10-|"
                   options:kNilOptions
                   metrics:nil
                     views:@{@"uploading" : uploadingLabel}]];
	}
	return self;
}

-(void)setupWithImageAsset:(PHAsset*)imageAsset andThumbnailSize:(CGFloat)size
{
    NSInteger retinaScale = [UIScreen mainScreen].scale;
    CGSize retinaSquare = CGSizeMake(size*retinaScale, size*retinaScale);
    
    PHImageRequestOptions *cropToSquare = [[PHImageRequestOptions alloc] init];
    cropToSquare.resizeMode = PHImageRequestOptionsResizeModeExact;
    
    CGFloat cropSideLength = MIN(imageAsset.pixelWidth, imageAsset.pixelHeight);
    CGRect square = CGRectMake(0, 0, cropSideLength, cropSideLength);
    CGRect cropRect = CGRectApplyAffineTransform(square,
                             CGAffineTransformMakeScale(1.0 / imageAsset.pixelWidth,
                                                        1.0 / imageAsset.pixelHeight));
    cropToSquare.normalizedCropRect = cropRect;
    
    @autoreleasepool {
        [[PHImageManager defaultManager] requestImageForAsset:(PHAsset *)imageAsset
                       targetSize:retinaSquare
                      contentMode:PHImageContentModeAspectFit
                          options:cropToSquare
                    resultHandler:^(UIImage *result, NSDictionary *info) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if ([info objectForKey:PHImageErrorKey]) {
                                NSError *error = [info valueForKey:PHImageErrorKey];
                                NSLog(@"=> Error : %@", error.description);
                                self.cellImage.image = [UIImage imageNamed:@"placeholder"];
                            } else {
                                self.cellImage.image = result;
                                if(imageAsset.mediaType == PHAssetMediaTypeVideo)
                                {
                                    self.playImage.hidden = NO;
                                }
                            }
                        });
                    }
         ];
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
