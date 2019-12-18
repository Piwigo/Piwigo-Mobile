//
//  EditImageThumbnailTableViewCell.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "CategoriesData.h"
#import "EditImageThumbnailCollectionViewCell.h"
#import "ImageDetailViewController.h"
#import "MBProgressHUD.h"
#import "Model.h"
#import "UploadService.h"

@interface EditImageThumbnailCollectionViewCell() <UITextFieldDelegate>

@property (nonatomic, strong) UIAlertAction *renameFileNameAction;
@property (nonatomic, strong) NSString *oldFileName;

@end

@implementation EditImageThumbnailCollectionViewCell

-(void)awakeFromNib {
    
    // Initialization code
    [super awakeFromNib];
        
    self.layer.cornerRadius = 10;
    self.imageThumbnail.layer.cornerRadius = 10;
    self.imageDetails.layer.cornerRadius = 10;
    self.editButtonView.layer.cornerRadius = 5;
    self.removeButtonView.layer.cornerRadius = 15;

    self.imageSize.font = [UIFont piwigoFontSmallLight];
    self.imageSize.userInteractionEnabled = NO;

    self.imageDate.font = [UIFont piwigoFontSmallLight];
    self.imageSize.userInteractionEnabled = NO;

    self.imageTime.font = [UIFont piwigoFontSmallLight];
    self.imageTime.userInteractionEnabled = NO;
    
    self.imageFile.font = [UIFont piwigoFontSmallLight];
    self.imageTime.userInteractionEnabled = NO;

    self.editImageButton.tintColor = [UIColor piwigoOrange];
}

-(void)setupWithImage:(ImageUpload *)imageDetails forEdit:(BOOL)isEdit andRemove:(BOOL)isRemove
{
    // Cell background
    self.imageDetails.backgroundColor = [UIColor piwigoBackgroundColor];
    self.editButtonView.backgroundColor = [UIColor piwigoBackgroundColor];

    // Image size, date and time
    self.imageSize.textColor = [UIColor piwigoLeftLabelColor];
    self.imageDate.textColor = [UIColor piwigoLeftLabelColor];
    self.imageTime.textColor = [UIColor piwigoLeftLabelColor];

    // Image file name
    self.imageId = imageDetails.imageId;
    self.imageFile.textColor = [UIColor piwigoLeftLabelColor];
    if (imageDetails.fileName.length > 0) {
        self.imageFile.text = imageDetails.fileName;
    }
    if (isEdit) {
        // Show button for renaming file
        [self.editButtonView setHidden:NO];
        
        // Show button for removing image from selection if needed
        if (isRemove) {
            [self.removeButtonView setHidden:NO];
        } else {
            [self.removeButtonView setHidden:YES];
        }
    }
    else {
        // Hide buttons for renaming file and removing image from selection
        [self.editButtonView setHidden:YES];
        [self.removeButtonView setHidden:YES];
    }

    // Image from Photo Library or Piwigo server…
    if (imageDetails.imageAsset)
    {
        // Image thumbnail from Photo Library
        if ((imageDetails.imageAsset.pixelWidth > 0) &&
            (imageDetails.imageAsset.pixelHeight > 0)) {
            self.imageSize.text = [NSString stringWithFormat:@"%ld x %ld", (long)imageDetails.imageAsset.pixelWidth, (long)imageDetails.imageAsset.pixelHeight];
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
        if ((imageDetails.pixelWidth > 0) && (imageDetails.pixelHeight > 0)) {
            self.imageSize.text = [NSString stringWithFormat:@"%ld x %ld", (long)imageDetails.pixelWidth, (long)imageDetails.pixelHeight];
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

-(void)prepareForReuse
{
    [super prepareForReuse];
    
    self.imageFile.text = @"";
    self.imageSize.text = @"";
    self.imageDate.text = @"";
    self.imageTime.text = @"";
}


#pragma mark - Edit Orginal Filename

// Propose to edit original filename
-(IBAction)editImage
{
    // Store old file name
    self.oldFileName = self.imageFile.text;
    
    // Determine the present view controller
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"renameImage_title", @"Original File")
                                message:[NSString stringWithFormat:@"%@ \"%@\":", NSLocalizedString(@"renameImage_message", @"Enter a new file name for this image"), self.imageFile.text]
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"renameImage_title", @"Original File");
        textField.text = self.imageFile.text;
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        textField.autocorrectionType = UITextAutocorrectionTypeYes;
        textField.returnKeyType = UIReturnKeyContinue;
        textField.delegate = self;
    }];

    UIAlertAction* cancelAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {}];

    self.renameFileNameAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"renameCategory_button", @"Rename")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            // Rename album if possible
            if(alert.textFields.firstObject.text.length > 0) {
                [self renameImageWithName:alert.textFields.firstObject.text andViewController:topViewController];
            }
        }];
    
    [alert addAction:cancelAction];
    [alert addAction:self.renameFileNameAction];
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [topViewController presentViewController:alert animated:YES completion:nil];
}

-(void)renameImageWithName:(NSString *)fileName andViewController:(UIViewController *)topViewController
{
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithLabel:NSLocalizedString(@"renameImageHUD_label", @"Renaming Original File…") inView:topViewController.view];
    });
    
    // Prepare dictionary of parameters
    NSMutableDictionary *imageInformation = [NSMutableDictionary new];
    [imageInformation setObject:fileName forKey:kPiwigoImagesUploadParamFileName];

    // Rename original filename
    [UploadService setImageFileForImageWithId:self.imageId
                                 withFileName:fileName
                                   onProgress:nil
             OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {

                if(response != nil)
                    {
                        [self hideHUDwithSuccess:YES inView:topViewController.view completion:^{
                            dispatch_async(dispatch_get_main_queue(), ^{
                                // Adopt new original filename
                                self.imageFile.text = fileName;
                                
                                // Notify this change to the image viewed
                                NSDictionary *objectInfo = @{@"imageId" : [NSString stringWithFormat:@"%ld", (long)self.imageId], @"fileName" : fileName};
                                [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationUpdateImageFileName object:objectInfo];
                            });
                        }];
                    }
                    else
                    {
                        [self hideHUDwithSuccess:NO inView:topViewController.view completion:^{
                            [self showRenameErrorWithMessage:nil andViewController:topViewController];
                        }];
                    }
                } onFailure:^(NSURLSessionTask *task, NSError *error) {
                        [self hideHUDwithSuccess:NO inView:topViewController.view completion:^{
                            [self showRenameErrorWithMessage:[error localizedDescription] andViewController:topViewController];
                        } ];
                }];
}
    
-(void)showRenameErrorWithMessage:(NSString*)message andViewController:(UIViewController *)topViewController
{
    NSString *errorMessage = NSLocalizedString(@"renameImageError_message", @"Failed to rename your image filename");
    if(message)
    {
        errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
    }
    UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"renameCategoyError_title", @"Rename Fail")
                message:errorMessage
                preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* defaultAction = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                style:UIAlertActionStyleCancel
                handler:^(UIAlertAction * action) {}];
    
    // Add actions
    [alert addAction:defaultAction];

    // Present list of actions
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.sourceView = self.contentView;
    alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUnknown;
    alert.popoverPresentationController.sourceRect = self.contentView.frame;
    [topViewController presentViewController:alert animated:YES completion:nil];
}


#pragma mark - Remove image from selection

-(IBAction)removeImage
{
    // Notify this deselection to album viewed
    NSDictionary *objectInfo = @{@"imageId" : [NSString stringWithFormat:@"%ld", (long)self.imageId]};
    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationUserDeselectedImage object:objectInfo];
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
    hud.contentColor = [UIColor piwigoHudContentColor];
    hud.bezelView.color = [UIColor piwigoHudBezelViewColor];

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


#pragma mark - UITextField Delegate Methods

-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    // Disable Add/Delete Category action
    [self.renameFileNameAction setEnabled:NO];
    return YES;
}

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // Enable Rename button if name and extension not empty
    NSString *finalString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    NSString *extension = [finalString pathExtension];
    [self.renameFileNameAction setEnabled:((finalString.length >= 1) && (extension.length >= 3) && ![finalString isEqualToString:self.oldFileName])];
    return YES;
}

-(BOOL)textFieldShouldClear:(UITextField *)textField
{
    // Disable Rename button
    [self.renameFileNameAction setEnabled:NO];
    return YES;
}

-(BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    return YES;
}

@end
