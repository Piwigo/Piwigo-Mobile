//
//  ImageUploadThumbCollectionViewCell.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "AppDelegate.h"
#import "CategoriesData.h"
#import "ImageUploadThumbCollectionViewCell.h"
#import "ImageDetailViewController.h"
#import "ImageService.h"
#import "MBProgressHUD.h"
#import "Model.h"

NSString * const kImageUploadThumbCollectionCell_ID = @"ImageUploadThumbCollectionCell";

@interface ImageUploadThumbCollectionViewCell() <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIView *imageThumbnailView;
@property (nonatomic, weak) IBOutlet UIImageView *imageThumbnail;
@property (nonatomic, weak) IBOutlet UIView *imageDetails;
@property (nonatomic, weak) IBOutlet UILabel *imageDate;
@property (nonatomic, weak) IBOutlet UILabel *imageSize;
@property (nonatomic, weak) IBOutlet UILabel *imageFile;
@property (nonatomic, weak) IBOutlet UILabel *imageTime;

@property (nonatomic, weak) IBOutlet UIView *removeButtonView;
@property (nonatomic, weak) IBOutlet UIButton *removeImageButton;

@end

@implementation ImageUploadThumbCollectionViewCell

-(void)awakeFromNib {
    
    // Initialization code
    [super awakeFromNib];
        
    self.contentView.layer.cornerRadius = 10;
    self.imageThumbnailView.layer.cornerRadius = 14;
    self.imageThumbnail.layer.cornerRadius = 10;
    self.imageDetails.layer.cornerRadius = 10;
    self.removeButtonView.layer.cornerRadius = 15;

    self.imageSize.font = [UIFont piwigoFontSmallLight];
    self.imageSize.userInteractionEnabled = NO;

    self.imageDate.font = [UIFont piwigoFontSmallLight];
    self.imageSize.userInteractionEnabled = NO;

    self.imageTime.font = [UIFont piwigoFontSmallLight];
    self.imageTime.userInteractionEnabled = NO;
    
    self.imageFile.font = [UIFont piwigoFontSmallLight];
    self.imageTime.userInteractionEnabled = NO;

    // Register palette changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoNotificationPaletteChanged object:nil];
}

-(void)applyColorPalette
{
    // Background
    self.imageThumbnailView.backgroundColor = [UIColor piwigoColorBackground];
    self.imageDetails.backgroundColor = [UIColor piwigoColorBackground];
    self.removeButtonView.backgroundColor = [UIColor piwigoColorCellBackground];

    // Image size, file name, date and time
    self.imageSize.textColor = [UIColor piwigoColorLeftLabel];
    self.imageFile.textColor = [UIColor piwigoColorLeftLabel];
    self.imageDate.textColor = [UIColor piwigoColorLeftLabel];
    self.imageTime.textColor = [UIColor piwigoColorLeftLabel];
}

-(void)setupWithImage:(ImageUpload *)imageDetails andRemoveOption:(BOOL)hasRemove
{
    // Colors
    [self applyColorPalette];
    
    // Image file name
    self.imageId = imageDetails.imageId;
    if (imageDetails.fileName.length > 0) {
        self.imageFile.text = imageDetails.fileName;
    }

    // Show button for removing image from selection if needed
    if (hasRemove) {
        [self.removeButtonView setHidden:NO];
    } else {
        [self.removeButtonView setHidden:YES];
    }

    // Image thumbnail from Photo Library
    if ((imageDetails.imageAsset.pixelWidth > 0) &&
        (imageDetails.imageAsset.pixelHeight > 0)) {
        self.imageSize.text = [NSString stringWithFormat:@"%ldx%ld pixels", (long)imageDetails.imageAsset.pixelWidth, (long)imageDetails.imageAsset.pixelHeight];
    }
    
    if (imageDetails.imageAsset.creationDate != nil) {
        if (self.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
            self.imageDate.text = [NSDateFormatter localizedStringFromDate:imageDetails.imageAsset.creationDate dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterNoStyle];
        } else {
            self.imageDate.text = [NSDateFormatter localizedStringFromDate:imageDetails.imageAsset.creationDate dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
        }
        self.imageTime.text = [NSDateFormatter localizedStringFromDate:imageDetails.imageAsset.creationDate dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
    }
    
    // Retrieve image from Photo Libray
    NSInteger retinaScale = [UIScreen mainScreen].scale;
    CGSize retinaSquare = CGSizeMake(144*retinaScale, 144*retinaScale);       // See ImageUploadParams.storyboard
    
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

-(void)prepareForReuse
{
    [super prepareForReuse];
    
    self.imageFile.text = @"";
    self.imageSize.text = @"";
    self.imageDate.text = @"";
    self.imageTime.text = @"";
}


#pragma mark - Remove image from selection

-(IBAction)removeImage
{
    // Notify this deselection to parent view
    if ([self.delegate respondsToSelector:@selector(didDeselectImageWithId:)])
    {
        [self.delegate didDeselectImageWithId:self.imageId];
    }
}


#pragma mark - HUD methods

-(void)showHUDwithLabel:(NSString *)label inView:(UIView *)topView
{
    // Create the loading HUD if needed
    MBProgressHUD *hud = [MBProgressHUD HUDForView:topView];
    if (!hud) {
        hud = [MBProgressHUD showHUDAddedTo:topView animated:YES];
    }
    
    // Change the background view shape, style and color.
    hud.square = NO;
    hud.animationType = MBProgressHUDAnimationFade;
    hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
    hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
    hud.contentColor = [UIColor piwigoColorText];
    hud.bezelView.color = [UIColor piwigoColorText];
    hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
    hud.bezelView.backgroundColor = [UIColor piwigoColorCellBackground];

    // Define the text
    hud.label.text = label;
    hud.label.font = [UIFont piwigoFontNormal];
}

-(void)hideHUDwithSuccess:(BOOL)success inView:(UIView *)topView completion:(void (^)(void))completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hide and remove the HUD
        MBProgressHUD *hud = [MBProgressHUD HUDForView:topView];
        if (hud) {
            if (success) {
                UIImage *image = [[UIImage imageNamed:@"completed"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                hud.customView = imageView;
                hud.mode = MBProgressHUDModeCustomView;
                hud.label.text = NSLocalizedString(@"completeHUD_label", @"Complete");
                [hud hideAnimated:YES afterDelay:0.5f];
            } else {
                [hud hideAnimated:YES];
            }
        }
        if (completion) {
            completion();
        }
    });
}

@end
