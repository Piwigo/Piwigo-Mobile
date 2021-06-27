//
//  EditImageThumbCollectionViewCell.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "CategoriesData.h"
#import "EditImageThumbCollectionViewCell.h"
#import "ImageDetailViewController.h"
#import "ImageService.h"
#import "MBProgressHUD.h"

NSString * const kEditImageThumbCollectionCell_ID = @"EditImageThumbCollectionCell";

@interface EditImageThumbCollectionViewCell() <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIView *imageThumbnailView;
@property (weak, nonatomic) IBOutlet UIImageView *imageThumbnail;
@property (weak, nonatomic) IBOutlet UIView *imageDetails;
@property (weak, nonatomic) IBOutlet UILabel *imageSize;
@property (weak, nonatomic) IBOutlet UILabel *imageFile;
@property (weak, nonatomic) IBOutlet UILabel *imageDate;
@property (weak, nonatomic) IBOutlet UILabel *imageTime;

@property (weak, nonatomic) IBOutlet UIView *editButtonView;
@property (weak, nonatomic) IBOutlet UIButton *editImageButton;

@property (weak, nonatomic) IBOutlet UIView *removeButtonView;
@property (weak, nonatomic) IBOutlet UIButton *removeImageButton;

@property (nonatomic, strong) UIAlertAction *renameFileNameAction;
@property (nonatomic, strong) NSString *oldFileName;

@end

@implementation EditImageThumbCollectionViewCell

-(void)awakeFromNib {
    
    // Initialization code
    [super awakeFromNib];
        
    self.contentView.layer.cornerRadius = 10;
    self.imageThumbnailView.layer.cornerRadius = 14;
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

    self.editImageButton.tintColor = [UIColor piwigoColorOrange];
    
    // Register palette changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:[PwgNotificationsObjc paletteChanged] object:nil];
}

-(void)applyColorPalette
{
    // Background
    self.imageThumbnailView.backgroundColor = [UIColor piwigoColorBackground];
    self.imageDetails.backgroundColor = [UIColor piwigoColorBackground];
    self.editButtonView.backgroundColor = [UIColor piwigoColorBackground];
    self.removeButtonView.backgroundColor = [UIColor piwigoColorCellBackground];

    // Image size, file name, date and time
    self.imageSize.textColor = [UIColor piwigoColorLeftLabel];
    self.imageFile.textColor = [UIColor piwigoColorLeftLabel];
    self.imageDate.textColor = [UIColor piwigoColorLeftLabel];
    self.imageTime.textColor = [UIColor piwigoColorLeftLabel];
}

-(void)setupWithImage:(PiwigoImageData *)imageData removeOption:(BOOL)hasRemove
{
    // Colors
    [self applyColorPalette];
    
    // Image file name
    self.imageId = imageData.imageId;
    if (imageData.fileName.length > 0) {
        self.imageFile.text = imageData.fileName;
    }
    
    // Show button for renaming file
    [self.editButtonView setHidden:NO];
    
    // Show button for removing image from selection if needed
    if (hasRemove) {
        [self.removeButtonView setHidden:NO];
    } else {
        [self.removeButtonView setHidden:YES];
    }

    // Image from Piwigo server…
    if ((imageData.fullResWidth > 0) && (imageData.fullResHeight > 0)) {
        if (self.bounds.size.width > 299) {     // i.e. larger than iPhone 5 screen width
            self.imageSize.text = [NSString stringWithFormat:@"%ldx%ld pixels, %.2f MB", (long)imageData.fullResWidth, (long)imageData.fullResHeight, (double)imageData.fileSize / 1024.0];
        } else {
            self.imageSize.text = [NSString stringWithFormat:@"%ldx%ld pixels", (long)imageData.fullResWidth, (long)imageData.fullResHeight];
        }
    }

    self.imageDate.text = @"";
    if (imageData.dateCreated != nil) {
        if (self.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
            self.imageDate.text = [NSDateFormatter localizedStringFromDate:imageData.dateCreated dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterNoStyle];
        } else {
            self.imageDate.text = [NSDateFormatter localizedStringFromDate:imageData.dateCreated dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
        }
        self.imageTime.text = [NSDateFormatter localizedStringFromDate:imageData.dateCreated dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
    }

    // Retrieve image thumbnail from Photo Libray
    NSString *thumbnailUrl;
    kPiwigoImageSize albumThumbnailSize = (kPiwigoImageSize)AlbumVars.defaultAlbumThumbnailSize;
    switch (albumThumbnailSize) {
        case kPiwigoImageSizeSquare:
            if (AlbumVars.hasSquareSizeImages) {
                thumbnailUrl = imageData.SquarePath;
            }
            break;
        case kPiwigoImageSizeXXSmall:
            if (AlbumVars.hasXXSmallSizeImages) {
                thumbnailUrl = imageData.XXSmallPath;
            }
            break;
        case kPiwigoImageSizeXSmall:
            if (AlbumVars.hasXSmallSizeImages) {
                thumbnailUrl = imageData.XSmallPath;
            }
            break;
        case kPiwigoImageSizeSmall:
            if (AlbumVars.hasSmallSizeImages) {
                thumbnailUrl = imageData.SmallPath;
            }
            break;
        case kPiwigoImageSizeMedium:
            if (AlbumVars.hasMediumSizeImages) {
                thumbnailUrl = imageData.MediumPath;
            }
            break;
        case kPiwigoImageSizeLarge:
            if (AlbumVars.hasLargeSizeImages) {
                thumbnailUrl = imageData.LargePath;
            }
            break;
        case kPiwigoImageSizeXLarge:
            if (AlbumVars.hasXLargeSizeImages) {
                thumbnailUrl = imageData.XLargePath;
            }
            break;
        case kPiwigoImageSizeXXLarge:
            if (AlbumVars.hasXXLargeSizeImages) {
                thumbnailUrl = imageData.XXLargePath;
            }
            break;

        case kPiwigoImageSizeThumb:
        case kPiwigoImageSizeFullRes:
        default:
            thumbnailUrl = imageData.ThumbPath;
            break;
    }

    if (thumbnailUrl.length <= 0)
    {
        // No known thumbnail URL
        self.imageThumbnail.image = [UIImage imageNamed:@"placeholder"];
        return;
    }
    else
    {
        // Load album thumbnail
        __weak typeof(self) weakSelf = self;
        NSURL *URL = [NSURL URLWithString:thumbnailUrl];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
        [self.imageThumbnail setImageWithURLRequest:request
                                   placeholderImage:[UIImage imageNamed:@"placeholder"]
                                            success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                                weakSelf.imageThumbnail.image = image;
                                            }
                                            failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
#if defined(DEBUG)
                                                NSLog(@"setupWithImageData — Fail to get thumbnail for image at %@", thumbnailUrl);
#endif
                                            }];
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


#pragma mark - Edit Filename

// Propose to edit original filename
-(IBAction)editFileName
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
        textField.keyboardAppearance = AppVars.isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
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
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [topViewController presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}

-(void)renameImageWithName:(NSString *)fileName andViewController:(UIViewController *)topViewController
{
    // Display HUD during the update
    [topViewController showPiwigoHUDWithTitle:NSLocalizedString(@"renameImageHUD_label", @"Renaming Original File…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    
    // Prepare dictionary of parameters
    NSMutableDictionary *imageInformation = [NSMutableDictionary new];
    [imageInformation setObject:fileName forKey:kPiwigoImagesUploadParamFileName];

    // Rename original filename
    [ImageService setImageFileForImageWithId:self.imageId
                                 withFileName:fileName
                                   onProgress:nil
             OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {

                if(response != nil)
                    {
                        [topViewController updatePiwigoHUDwithSuccessWithCompletion:^{
                            [topViewController hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    // Adopt new original filename
                                    self.imageFile.text = fileName;
                                    
                                    // Update parent image view
                                    if ([self.delegate respondsToSelector:@selector(didRenameFileOfImageWithId:andFilename:)])
                                    {
                                        [self.delegate didRenameFileOfImageWithId:self.imageId andFilename:fileName];
                                    }
                                });
                            }];
                        }];
                    }
                    else
                    {
                        [topViewController hidePiwigoHUDWithCompletion:^{
                            [topViewController dismissPiwigoErrorWithTitle:NSLocalizedString(@"renameCategoyError_title", @"Rename Fail") message:NSLocalizedString(@"renameImageError_message", @"Failed to rename your image filename") errorMessage:@"" completion:^{ }];
                        }];
                    }
                } onFailure:^(NSURLSessionTask *task, NSError *error) {
                    [topViewController hidePiwigoHUDWithCompletion:^{
                        [topViewController dismissPiwigoErrorWithTitle:NSLocalizedString(@"renameCategoyError_title", @"Rename Fail") message:NSLocalizedString(@"renameImageError_message", @"Failed to rename your image filename") errorMessage:[error localizedDescription] completion:^{ }];
                    }];
                }];
}


#pragma mark - Remove Image from Selection

-(IBAction)removeImage
{
    // Notify this deselection to parent view
    if ([self.delegate respondsToSelector:@selector(didDeselectImageWithId:)])
    {
        [self.delegate didDeselectImageWithId:self.imageId];
    }
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
