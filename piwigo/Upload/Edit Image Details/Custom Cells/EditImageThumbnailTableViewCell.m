//
//  EditImageThumbnailTableViewCell.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "EditImageThumbnailTableViewCell.h"

@interface EditImageThumbnailTableViewCell()

@property (weak, nonatomic) IBOutlet UIImageView *imageThumbnail;
@property (weak, nonatomic) IBOutlet UILabel *imageDate;
@property (weak, nonatomic) IBOutlet UILabel *imageSize;
@property (weak, nonatomic) IBOutlet UILabel *imageFile;
@property (weak, nonatomic) IBOutlet UILabel *imageTime;

@end

@implementation EditImageThumbnailTableViewCell

- (void)awakeFromNib {
    
    // Initialization code
    [super awakeFromNib];
    
    self.backgroundColor = [UIColor piwigoBackgroundColor];
    
    self.imageThumbnail.layer.cornerRadius = 10;
    self.imageSize.font = [UIFont piwigoFontSmallLight];
    self.imageDate.font = [UIFont piwigoFontSmallLight];
    self.imageTime.font = [UIFont piwigoFontSmallLight];
    self.imageFile.font = [UIFont piwigoFontSmallLight];

    [self paletteChanged];
}

-(void)paletteChanged
{
    self.imageSize.textColor = [UIColor piwigoLeftLabelColor];
    self.imageDate.textColor = [UIColor piwigoLeftLabelColor];
    self.imageTime.textColor = [UIColor piwigoLeftLabelColor];
    self.imageFile.textColor = [UIColor piwigoLeftLabelColor];
}

-(void)setupWithImage:(ImageUpload *)imageDetails
{
    // Initialisation
    self.imageFile.text = @"";
    self.imageSize.text = @"— x —";
    self.imageDate.text = @"";
    self.imageTime.text = @"";
    
    // Image from Photo Library or Piwigo server…
    if (imageDetails.imageAsset)
    {
        // Image thumbnail from Photo Library
        if ((imageDetails.imageAsset.pixelWidth > 0) &&
            (imageDetails.imageAsset.pixelHeight > 0)) {
            self.imageSize.text = [NSString stringWithFormat:@"%ld x %ld", imageDetails.imageAsset.pixelWidth, imageDetails.imageAsset.pixelHeight];
        }
        
        if (imageDetails.imageAsset.creationDate != nil) {
            self.imageDate.text = [NSDateFormatter localizedStringFromDate:imageDetails.imageAsset.creationDate dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterNoStyle];
            self.imageTime.text = [NSDateFormatter localizedStringFromDate:imageDetails.imageAsset.creationDate dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
        }
        
        // Retrieve image from Photo Libray
        NSInteger retinaScale = [UIScreen mainScreen].scale;
        CGSize retinaSquare = CGSizeMake(144*retinaScale, 144*retinaScale);       // See EditImageDetails.storyboard
        
        PHImageRequestOptions *cropToSquare = [[PHImageRequestOptions alloc] init];
        cropToSquare.resizeMode = PHImageRequestOptionsResizeModeExact;
        
        CGFloat cropSideLength = MIN(imageDetails.imageAsset.pixelWidth, imageDetails.imageAsset.pixelHeight);
        CGRect square = CGRectMake(0, 0, cropSideLength, cropSideLength);
        CGRect cropRect = CGRectApplyAffineTransform(square,
                                                     CGAffineTransformMakeScale(1.0 / imageDetails.imageAsset.pixelWidth,
                                                                                1.0 / imageDetails.imageAsset.pixelHeight));
        cropToSquare.normalizedCropRect = cropRect;
        
        [[PHImageManager defaultManager] requestImageForAsset:(PHAsset *)imageDetails.imageAsset
                                                   targetSize:retinaSquare
                                                  contentMode:PHImageContentModeAspectFit
                                                      options:cropToSquare
                                                resultHandler:^(UIImage *result, NSDictionary *info) {
                                                    self.imageThumbnail.image = result;
                                                }
        ];
    }
    else {
        // Image from Piwigo server
        if (imageDetails.fileName.length > 0) {
            self.imageFile.text = imageDetails.fileName;
        }
        if ((imageDetails.pixelWidth > 0) && (imageDetails.pixelHeight > 0)) {
            self.imageSize.text = [NSString stringWithFormat:@"%ld x %ld", imageDetails.pixelWidth, imageDetails.pixelHeight];
        }

        if (imageDetails.creationDate != nil) {
            self.imageDate.text = [NSDateFormatter localizedStringFromDate:imageDetails.creationDate dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterNoStyle];
            self.imageTime.text = [NSDateFormatter localizedStringFromDate:imageDetails.creationDate dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
        }

        // Retrieve image from Photo Libray
        if (imageDetails.thumbnailUrl.length <= 0)
            {
                // No known thumbnail URL
                self.imageThumbnail.image = [UIImage imageNamed:@"placeholder"];
                return;
            }
            else
            {
                // Load album thumbnail
                __weak typeof(self) weakSelf = self;
                NSURL *URL = [NSURL URLWithString:imageDetails.thumbnailUrl];
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
                [self.imageThumbnail setImageWithURLRequest:request
                                           placeholderImage:[UIImage imageNamed:@"placeholder"]
                                                    success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                                        weakSelf.imageThumbnail.image = image;
                                                    }
                                                    failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
#if defined(DEBUG)
                                                        NSLog(@"setupWithImageData — Fail to get thumbnail for image at %@", imageDetails.thumbnailUrl);
#endif
                                                    }];
            }
    }
}

@end
