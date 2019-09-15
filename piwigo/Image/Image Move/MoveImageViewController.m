//
//  MoveImageViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/07/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//

#import "AppDelegate.h"
#import "AlbumService.h"
#import "CategoriesData.h"
#import "CategoryTableViewCell.h"
#import "EditImageDetailsViewController.h"
#import "ImageService.h"
#import "MBProgressHUD.h"
#import "Model.h"
#import "MoveImageViewController.h"
#import "PiwigoAlbumData.h"

CGFloat const kMoveImageViewWidth = 512.0;      // MoveImage view width

@class PiwigoAlbumData;

@interface MoveImageViewController () <UITableViewDataSource, UITableViewDelegate, CategoryCellDelegate>

@property (nonatomic, strong) UITableView *categoriesTableView;
@property (nonatomic, strong) NSMutableArray *selectedImageIds;
@property (nonatomic, strong) NSMutableArray *selectedImages;
@property (nonatomic, assign) double nberOfSelectedImages;
@property (nonatomic, strong) PiwigoImageData *selectedImage;
@property (nonatomic, assign) NSInteger categoryIdOfSelectedImages;
@property (nonatomic, assign) NSInteger indexOfFirstSelectedImage;
@property (nonatomic, assign) BOOL copyImage;
@property (nonatomic, assign) BOOL isLoadingImageData;

@property (nonatomic, strong) NSMutableArray *categories;
@property (nonatomic, strong) NSMutableArray *categoriesThatShowSubCategories;
@property (nonatomic, strong) UIViewController *hudViewController;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, assign) BOOL isLoadingCategories;

@end

@implementation MoveImageViewController

-(instancetype)initWithSelectedImageIds:(NSArray*)imageIds orSingleImageData:(PiwigoImageData *)imageData inCategoryId:(NSInteger)categoryId atIndex:(NSInteger)index andCopyOption:(BOOL)copyImage
{
    self = [super init];
    if(self)
    {
        // View title
        if (copyImage)
            self.title = NSLocalizedString(@"copyImage_title", @"Copy to Album");
        else
            self.title = NSLocalizedString(@"moveImage_title", @"Move to Album");
        
        // Data
        self.selectedImages = [NSMutableArray new];
        self.selectedImageIds = [NSMutableArray new];
        if (imageIds != nil) self.selectedImageIds = [imageIds mutableCopy];
        if (imageData != nil) self.selectedImage = imageData;
        self.categoryIdOfSelectedImages = categoryId;
        self.indexOfFirstSelectedImage = index;
        self.copyImage = copyImage;
        
        // List of categories to present
        self.categories = [NSMutableArray new];
        self.categoriesThatShowSubCategories = [NSMutableArray new];
        
        // Table view
        self.categoriesTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        self.categoriesTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.categoriesTableView.backgroundColor = [UIColor clearColor];
        self.categoriesTableView.alwaysBounceVertical = YES;
        self.categoriesTableView.showsVerticalScrollIndicator = YES;
        self.categoriesTableView.delegate = self;
        self.categoriesTableView.dataSource = self;
        [self.categoriesTableView registerNib:[UINib nibWithNibName:@"CategoryTableViewCell" bundle:nil] forCellReuseIdentifier:@"CategoryTableViewCell"];
        [self.view addSubview:self.categoriesTableView];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.categoriesTableView]];
        
        // Button for cancelling action
        self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(quitMoveImage)];

        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoNotificationPaletteChanged object:nil];
    }
    return self;
}


#pragma mark - View Lifecycle

-(void)applyColorPalette
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];

    // Navigation bar
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoBackgroundColor];
    self.navigationController.navigationBar.tintColor = [UIColor piwigoOrange];
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    
    // Table view
    self.categoriesTableView.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self buildCategoryArrayUsingCache:YES untilCompletion:^(BOOL result) {
        // Build complete list
        [self.categoriesTableView reloadData];
    } orFailure:^(NSURLSessionTask *task, NSError *error) {
        // Invite users to refresh?
    }];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set colors, fonts, etc.
    [self applyColorPalette];

    // Add Cancel button
    [self.navigationItem setRightBarButtonItems:@[self.cancelBarButton] animated:YES];
    
    // Retrieve image data if necessary
    if (self.selectedImageIds.count > 0) {
        
        // Display HUD
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoadingImageData = YES;
            [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") andMode:MBProgressHUDModeIndeterminate];
        });
        
        // Start loading data of all image Ids
        [self retrieveImageData];
    }
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    //Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        // On iPad, the Settings section is presented in a centered popover view
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            CGRect mainScreenBounds = [UIScreen mainScreen].bounds;
            self.preferredContentSize = CGSizeMake(kMoveImageViewWidth, ceil(CGRectGetHeight(mainScreenBounds)*2/3));
        }
        
        // Reload table view
        [self.categoriesTableView reloadData];
    } completion:nil];
}

-(void)quitMoveImage
{
    // Return to image preview
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)quitAfterCopyingImageWithCategoryIds:(NSMutableArray *)categoryIds
{
    // Return to image preview
    [self dismissViewControllerAnimated:YES completion:^{
        // Update image data
        if([self.moveImageDelegate respondsToSelector:@selector(didCopyImageInOneOfCategoryIds:)])
        {
            [self.moveImageDelegate didCopyImageInOneOfCategoryIds:categoryIds];
        }
    }];
}

-(void)quitMoveImageAndReturnToAlbumView
{
    // Return to album view (image moved)
    [self dismissViewControllerAnimated:YES completion:^{
        // Update album view and dismiss image detail view
        if([self.moveImageDelegate respondsToSelector:@selector(didRemoveImage:atIndex:)])
        {
            [self.moveImageDelegate didRemoveImage:self.selectedImage atIndex:self.indexOfFirstSelectedImage];
        }
    }];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // Return to album view and re-enable buttons
    if ([self.moveImagesDelegate respondsToSelector:@selector(cancelMoveImages)])
    {
        [self.moveImagesDelegate cancelMoveImages];
    }

    // Return to image preview and re-enable buttons
    if ([self.moveImageDelegate respondsToSelector:@selector(cancelMoveImage)])
    {
        [self.moveImageDelegate cancelMoveImage];
    }
}


#pragma mark - Retrieve Image Data

-(void)retrieveImageData
{
    if (self.selectedImageIds.count <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.categoriesTableView reloadData];
            self.isLoadingImageData = NO;
            [self hideHUD];
        });
        return;
    }
    
    // Image data are not complete when retrieved using pwg.categories.getImages
    // Required by Copy, Delete, Move actions (may also be used to show albums image belongs to)
    [ImageService getImageInfoById:[[self.selectedImageIds lastObject] integerValue]
                andAddImageToCache:NO
          ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageDataComplete) {
              
              if (imageDataComplete != nil) {
                  // Store image data
                  [self.selectedImages addObject:imageDataComplete];
                  if (self.selectedImages.count == 1)
                      self.selectedImage = [self.selectedImages firstObject];
                  
                  // Determine categories common to all images
                  NSMutableSet *set1 = [NSMutableSet setWithArray:self.selectedImage.categoryIds];
                  NSSet *set2 = [NSSet setWithArray:imageDataComplete.categoryIds];
                  [set1 intersectSet:set2];
                  self.selectedImage.categoryIds = [set1 allObjects];
                  
                  // Next image
                  [self.selectedImageIds removeLastObject];
                  [self retrieveImageData];
              }
              else {
                  [self couldNotRetrieveImageData];
              }
          }
                 onFailure:^(NSURLSessionTask *task, NSError *error) {
                     // Failed — Ask user if he/she wishes to retry
                     [self couldNotRetrieveImageData];
                 }];
}

-(void)couldNotRetrieveImageData
{
    // Failed — Ask user if he/she wishes to retry
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"imageDetailsFetchError_title", @"Image Details Fetch Failed")
        message:NSLocalizedString(@"imageDetailsFetchError_retryMessage", @"Fetching the image data failed\nTry again?")
        preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* dismissAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isLoadingImageData = NO;
                [self hideHUDwithSuccess:NO completion:^{
                    [self quitMoveImage];
                }];
            });
        }];
    
    UIAlertAction* retryAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
          [self retrieveImageData];
        }];
    
    [alert addAction:dismissAction];
    [alert addAction:retryAction];
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - UITableView - Header

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Title
    NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"tabBar_albums", @"Albums")];
    NSDictionary *titleAttributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect titleRect = [titleString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:titleAttributes
                                                 context:context];
    
    // Text
    NSString *textString;
    if (self.selectedImages.count > 0) {
        if (self.copyImage)
            textString = NSLocalizedString(@"copySeveralImages_selectAlbum", @"Select an album to copy images to");
        else
            textString = NSLocalizedString(@"moveSeveralImages_selectAlbum", @"Select an album to move images to");
    }
    else {
        if (self.copyImage)
            textString = [NSString stringWithFormat:NSLocalizedString(@"copySingleImage_selectAlbum", @"Select an album to copy image \"%@\" to"), self.selectedImage.name];
        else
            textString = [NSString stringWithFormat:NSLocalizedString(@"moveSingleImage_selectAlbum", @"Select an album to move image \"%@\" to"), self.selectedImage.name];
    }
    NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:textAttributes
                                               context:context];
    return fmax(44.0, ceil(titleRect.size.height + textRect.size.height));
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSMutableAttributedString *headerAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
    
    // Title
    NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"tabBar_albums", @"Albums")];
    NSMutableAttributedString *titleAttributedString = [[NSMutableAttributedString alloc] initWithString:titleString];
    [titleAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold]
                                  range:NSMakeRange(0, [titleString length])];
    [headerAttributedString appendAttributedString:titleAttributedString];
    
    // Text
    NSString *textString;
    if (self.selectedImages.count > 0) {
        if (self.copyImage)
            textString = NSLocalizedString(@"copySeveralImages_selectAlbum", @"Select an album to copy images to");
        else
            textString = NSLocalizedString(@"moveSeveralImages_selectAlbum", @"Select an album to move images to");
    }
    else {
        if (self.copyImage)
            textString = [NSString stringWithFormat:NSLocalizedString(@"copySingleImage_selectAlbum", @"Select an album to copy image \"%@\" to"), self.selectedImage.name];
        else
            textString = [NSString stringWithFormat:NSLocalizedString(@"moveSingleImage_selectAlbum", @"Select an album to move image \"%@\" to"), self.selectedImage.name];
    }
    NSMutableAttributedString *textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
    [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                 range:NSMakeRange(0, [textString length])];
    [headerAttributedString appendAttributedString:textAttributedString];
    
    // Header label
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontNormal];
    headerLabel.textColor = [UIColor piwigoHeaderColor];
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    headerLabel.attributedText = headerAttributedString;
    
    // Header view
    UIView *header = [[UIView alloc] init];
    [header addSubview:headerLabel];
    [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:4]];
    if (@available(iOS 11, *)) {
        [header addConstraints:[NSLayoutConstraint
                                constraintsWithVisualFormat:@"|-[header]-|"
                                                    options:kNilOptions
                                                    metrics:nil
                                                      views:@{@"header" : headerLabel}]];
    } else {
        [header addConstraints:[NSLayoutConstraint
                                constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                                    options:kNilOptions
                                                    metrics:nil
                                                      views:@{@"header" : headerLabel}]];
    }
    
    return header;
}

#pragma mark - UITableView - Rows

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.categories.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CategoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CategoryTableViewCell" forIndexPath:indexPath];
    
    // Determine the depth before setting up the cell
    PiwigoAlbumData *categoryData = [self.categories objectAtIndex:indexPath.row];
    NSInteger depth = [categoryData getDepthOfCategory];
    PiwigoAlbumData *defaultCategoryData = [self.categories objectAtIndex:0];
    depth -= [defaultCategoryData getDepthOfCategory];
    [cell setupWithCategoryData:categoryData atDepth:depth];
    
    // Category contains selected image?
    if ([self.selectedImage.categoryIds containsObject:@(categoryData.albumId)])
    {
        cell.categoryLabel.textColor = [UIColor piwigoRightLabelColor];
        cell.userInteractionEnabled = NO;
    }
    
    // Switch between Open/Close cell disclosure
    cell.categoryDelegate = self;
    if([self.categoriesThatShowSubCategories containsObject:@(categoryData.albumId)]) {
        cell.upDownImage.image = [UIImage imageNamed:@"cellClose"];
        cell.userInteractionEnabled = YES;
    } else {
        cell.upDownImage.image = [UIImage imageNamed:@"cellOpen"];
        cell.userInteractionEnabled = YES;
    }
    
    cell.isAccessibilityElement = YES;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    PiwigoAlbumData *categoryData = [self.categories objectAtIndex:indexPath.row];
    if ([self.selectedImage.categoryIds containsObject:@(categoryData.albumId)])
        return NO;
    
    return YES;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    PiwigoAlbumData *categoryData = [self.categories objectAtIndex:indexPath.row];
    
    // User cannot move/copy image at current place
    if ([self.selectedImage.categoryIds containsObject:@(categoryData.albumId)]) return;
    
    NSString *message;
    if (self.selectedImages.count > 0) {
        if (self.copyImage)
            message = [NSString stringWithFormat:NSLocalizedString(@"copySeveralImages_message", @"Are you sure you want to copy the images to the album \"%@\"?"), categoryData.name];
        else
            message = [NSString stringWithFormat:NSLocalizedString(@"moveSeveralImages_message", @"Are you sure you want to move the images to the album \"%@\"?"), categoryData.name];
    }
    else {
        if (self.copyImage)
            message = [NSString stringWithFormat:NSLocalizedString(@"copySingleImage_message", @"Are you sure you want to copy the image \"%@\" to the album \"%@\"?"), self.selectedImage.name, categoryData.name];
        else
            message = [NSString stringWithFormat:NSLocalizedString(@"moveSingleImage_message", @"Are you sure you want to move the image \"%@\" to the album \"%@\"?"), self.selectedImage.name, categoryData.name];
    }

    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:@""
        message:message
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
       actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
       style:UIAlertActionStyleCancel
       handler:^(UIAlertAction * action) {
           if (self.selectedImages.count > 0) [self quitMoveImage];
       }];
    
    UIAlertAction* moveImageAction = [UIAlertAction
        actionWithTitle:self.copyImage ? NSLocalizedString(@"copyImage_title", @"Copy to Album") : NSLocalizedString(@"moveImage_title", @"Move to Album")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            [self addImagesToCategoryId:categoryData.albumId];
        }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:moveImageAction];
    
    // Determine position of cell in table view
    CGRect rectOfCellInTableView = [tableView rectForRowAtIndexPath:indexPath];
    
    // Determine width of text
    CategoryTableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *textString = cell.categoryLabel.text;
    NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:textAttributes
                                               context:context];
    
    // Calculate horizontal position of popover view
    rectOfCellInTableView.origin.x -= tableView.frame.size.width - textRect.size.width - tableView.layoutMargins.left - 12;
    
    // Present popover view
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.sourceView = tableView;
    alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionLeft;
    alert.popoverPresentationController.sourceRect = rectOfCellInTableView;
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - Copy/move image methods

-(void)addImagesToCategoryId:(NSInteger)categoryId
{
    // Display HUD during server update
    NSString *title;
    if (self.selectedImages.count > 0) {
        title = self.copyImage ? NSLocalizedString(@"copySeveralImagesHUD_copying", @"Copying Images…") : NSLocalizedString(@"moveSeveralImagesHUD_moving", @"Moving Images…");
        self.nberOfSelectedImages = (double)(self.selectedImages.count);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showHUDwithTitle:title andMode:MBProgressHUDModeAnnularDeterminate];
        });
    }
    else {
        title = self.copyImage ? NSLocalizedString(@"copySingleImageHUD_copying", @"Copying Image…") : NSLocalizedString(@"moveSingleImageHUD_moving", @"Moving Image…");
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showHUDwithTitle:title andMode:MBProgressHUDModeIndeterminate];
        });
    }
    
    // Start copying/moving images
    if (self.selectedImages.count > 0) {
        self.selectedImage = [self.selectedImages lastObject];
    }
    [self addImageToCategoryId:categoryId];
}

-(void)addImageToCategoryId:(NSInteger)categoryId
{
    // Update image category list
    NSMutableArray *categoryIds = [self.selectedImage.categoryIds mutableCopy];
    [categoryIds addObject:@(categoryId)];
    if (!self.copyImage && [categoryIds containsObject:@(self.categoryIdOfSelectedImages)]) {
        [categoryIds removeObject:@(self.categoryIdOfSelectedImages)];
    }
    
    // Send request to Piwigo server
    [ImageService setCategoriesForImage:self.selectedImage
          withCategories:categoryIds
              onProgress:nil
            OnCompletion:^(NSURLSessionTask *task, BOOL updatedSuccessfully) {
                if (updatedSuccessfully)
                {
                    // Add image to other category
                    [[[CategoriesData sharedInstance] getCategoryById:categoryId] addImages:@[self.selectedImage]];
                    [[[CategoriesData sharedInstance] getCategoryById:categoryId] incrementImageSizeByOne];

                    // Remove image from current category if needed
                    if (!self.copyImage) {
                        [[[CategoriesData sharedInstance] getCategoryById:self.categoryIdOfSelectedImages] removeImages:@[self.selectedImage]];
                        [[[CategoriesData sharedInstance] getCategoryById:self.categoryIdOfSelectedImages] deincrementImageSizeByOne];

                        // Notify album/image view of modification
                        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
                    }

                    // When called from image preview, return to image or album
                    if (self.selectedImages.count <= 0) {
                        // Hide HUD
                        [self hideHUDwithSuccess:YES completion:^{
                            // Return to album view if image moved
                            if (self.copyImage)
                                [self quitAfterCopyingImageWithCategoryIds:categoryIds];
                            else
                                [self quitMoveImageAndReturnToAlbumView];
                        }];
                    }
                    else if (self.selectedImages.count > 1) {
                        // Update album view if image moved
                        if (!self.copyImage) {
                            if([self.moveImagesDelegate respondsToSelector:@selector(didRemoveImage:atIndex:)])
                            {
                                [self.moveImagesDelegate didRemoveImage:self.selectedImage atIndex:self.indexOfFirstSelectedImage];
                            }
                        }
                        
                        // Next image
                        [self.selectedImages removeLastObject];
                        self.selectedImage = [self.selectedImages lastObject];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [MBProgressHUD HUDForView:self.hudViewController.view].progress = 1.0 - (double)(self.selectedImages.count) / self.nberOfSelectedImages;
                        });
                        [self addImageToCategoryId:categoryId];
                    }
                    else {
                        // Update album view if image moved
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [MBProgressHUD HUDForView:self.hudViewController.view].progress = 1.0;
                        });
                        if (!self.copyImage) {
                            if([self.moveImagesDelegate respondsToSelector:@selector(didRemoveImage:atIndex:)])
                            {
                                [self.moveImagesDelegate didRemoveImage:self.selectedImage atIndex:self.indexOfFirstSelectedImage];
                            }
                        }
                        
                        // Hide HUD
                        [self hideHUDwithSuccess:YES completion:^{
                            // Deselect images
                            if([self.moveImagesDelegate respondsToSelector:@selector(deselectImages)])
                            {
                                [self.moveImagesDelegate deselectImages];
                            }
                            [self quitMoveImage];
                        }];
                    }
                }
                else {
                  [self hideHUDwithSuccess:NO completion:^{
                      [self showMoveImageErrorWithMessage:nil];
                  }];
                }
            }
                onFailure:^(NSURLSessionTask *task, NSError *error) {
                  [self hideHUDwithSuccess:NO completion:^{
                      [self showMoveImageErrorWithMessage:[error localizedDescription]];
                  }];
                }];
}

-(void)showMoveImageErrorWithMessage:(NSString*)message
{
    NSString *errorMessage;
    if (self.copyImage)
        errorMessage = NSLocalizedString(@"copySingleImageError_message", @"Failed to copy your image");
    else
        errorMessage = NSLocalizedString(@"moveSingleImageError_message", @"Failed to move your image");

    if(message)
    {
        errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
    }
    
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:self.copyImage ? NSLocalizedString(@"copyImageError_title", @"Copy Fail") : NSLocalizedString(@"moveImageError_title", @"Move Fail")
                                message:errorMessage
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* dismissAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                    style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction * action) {}];
    
    [alert addAction:dismissAction];
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [self presentViewController:alert animated:YES completion:nil];    
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - HUD methods

-(void)showHUDwithTitle:(NSString *)title andMode:(MBProgressHUDMode)mode
{
    // Determine the present view controller if needed (not necessarily self.view)
    if (!self.hudViewController) {
        self.hudViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (self.hudViewController.presentedViewController) {
            self.hudViewController = self.hudViewController.presentedViewController;
        }
    }
    
    // Create the login HUD if needed
    MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
    if (!hud) {
        // Create the HUD
        hud = [MBProgressHUD showHUDAddedTo:self.hudViewController.view animated:YES];
        [hud setTag:loadingViewTag];
        
        // Change the background view shape, style and color.
        hud.mode = mode;
        hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
        hud.contentColor = [UIColor piwigoHudContentColor];
        hud.bezelView.color = [UIColor piwigoHudBezelViewColor];

        // Will look best, if we set a minimum size.
        hud.minSize = CGSizeMake(200.f, 100.f);
    }
    
    // Set title
    hud.label.text = title;
    hud.label.font = [UIFont piwigoFontNormal];
}

-(void)hideHUDwithSuccess:(BOOL)success completion:(void (^)(void))completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hide and remove the HUD
        MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
        if (hud) {
            if (success) {
                UIImage *image = [[UIImage imageNamed:@"completed"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                hud.customView = imageView;
                hud.mode = MBProgressHUDModeCustomView;
                hud.label.text = NSLocalizedString(@"completeHUD_label", @"Complete");
                [hud hideAnimated:YES afterDelay:1.f];
            } else {
                [hud hideAnimated:YES];
            }
        }
        if (completion) {
            completion();
        }
    });
}

-(void)hideHUD
{
    // Hide and remove the HUD
    if (self.isLoadingCategories || self.isLoadingImageData) return;
    MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
    if (hud) {
        [hud hideAnimated:YES];
        self.hudViewController = nil;
    }
}


#pragma mark - Category List Builder

-(void)buildCategoryArrayUsingCache:(BOOL)useCache
                    untilCompletion:(void (^)(BOOL result))completion
                          orFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Show loading HUD when not using cache option,
    if (!(useCache && [Model sharedInstance].loadAllCategoryInfo
          && ([Model sharedInstance].defaultCategory == 0))) {
        // Show loading HD
        self.isLoadingCategories = YES;
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") andMode:MBProgressHUDModeIndeterminate];
        
        // Reload category data and set current category
//        NSLog(@"buildCategoryMv => getAlbumListForCategory(%ld,NO,YES)", (long)0);
        [AlbumService getAlbumListForCategory:0
                                   usingCache:NO
                              inRecursiveMode:[Model sharedInstance].loadAllCategoryInfo
                                 OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                     // Build category array
                                     [self buildCategoryArray];
                                     
                                     // Hide loading HUD
                                     self.isLoadingCategories = NO;
                                     [self hideHUD];
                                     
                                     if (completion) {
                                         completion(YES);
                                     }
                                 }
                                    onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                        NSLog(@"getAlbumListForCategory error %ld: %@", (long)error.code, error.localizedDescription);
#endif
                                        // Hide loading HUD
                                        self.isLoadingCategories = NO;
                                        [self hideHUD];
                                        
                                        if(fail) {
                                            fail(task, error);
                                        }
                                    }
         ];
    } else {
        // Build category array from cache
        [self buildCategoryArray];
        
        if (completion) {
            completion(YES);
        }
    }
}

-(void)buildCategoryArray
{
    self.categories = [NSMutableArray new];
    
    // Build list of categories from complete known lists
    NSArray *allCategories = [CategoriesData sharedInstance].allCategories;
    NSArray *comCategories = [CategoriesData sharedInstance].communityCategoriesForUploadOnly;
    
    // Proposed list is collected in diff
    NSMutableArray *diff = [NSMutableArray new];
    
    // Look for categories which are not already displayed
    for(PiwigoAlbumData *category in allCategories)
    {
        // Smart albums should not be proposed
        if (category.albumId <= kPiwigoSearchCategoryId) {
            continue;
        }

        // Non-admin Community users can only upload in specific albums
        if (![Model sharedInstance].hasAdminRights && !category.hasUploadRights) {
            continue;
        }
        
        // Is this category already in displayed list?
        BOOL doesNotExist = YES;
        for(PiwigoAlbumData *existingCat in self.categories)
        {
            if(category.albumId == existingCat.albumId)
            {
                doesNotExist = NO;
                break;
            }
        }
        if(doesNotExist)
        {
            [diff addObject:category];
        }
    }
    
    // Build list of categories to be displayed
    for(PiwigoAlbumData *category in diff)
    {
        // Always add categories in default album
        if (category.parentAlbumId == 0)
        {
            [self.categories addObject:category];
            continue;
        }
    }
    
    // Add Community private categories
    for(PiwigoAlbumData *category in comCategories)
    {
        // Is this category already in displayed list?
        BOOL doesNotExist = YES;
        for(PiwigoAlbumData *existingCat in self.categories)
        {
            if(category.albumId == existingCat.albumId)
            {
                doesNotExist = NO;
                break;
            }
        }
        
        if(doesNotExist)
        {
            [self.categories addObject:category];
        }
    }
    
    // Do not add root album as one cannot store images into it
//    PiwigoAlbumData *rootAlbum = [PiwigoAlbumData new];
//    rootAlbum.albumId = 0;
//    rootAlbum.name = NSLocalizedString(@"categorySelection_root", @"Root Album");
//    [self.categories insertObject:rootAlbum atIndex:0];
}


#pragma mark - CategoryCellDelegate Methods

-(void)tappedDisclosure:(PiwigoAlbumData *)categoryTapped
{
    // Build list of categories from list of known categories
    NSArray *allCategories = [CategoriesData sharedInstance].allCategories;
    NSMutableArray *subcategories = [NSMutableArray new];
    
    // Look for known requested sub-categories
    for(PiwigoAlbumData *category in allCategories)
    {
        // Only add sub-categories of tapped category
        if (category.parentAlbumId != categoryTapped.albumId) {
            continue;
        }
        [subcategories addObject:category];
    }
    
    // Look for sub-categories which are already displayed
    NSInteger nberDisplayedSubCategories = 0;
    for(PiwigoAlbumData *category in subcategories)
    {
        for(PiwigoAlbumData *existingCat in self.categories)
        {
            if(category.albumId == existingCat.albumId)
            {
                nberDisplayedSubCategories++;
                break;
            }
        }
    }
    
    // This test depends on the caching option loadAllCategoryInfo:
    // => if YES: compare number of sub-albums inside category to be closed
    // => if NO: compare number of sub-sub-albums inside category to be closed
    if ((subcategories.count > 0) && (subcategories.count == nberDisplayedSubCategories))
    {
        // User wants to hide sub-categories
        [self removeSubCategoriesToCategoryID:categoryTapped];
    }
    else if (subcategories.count > 0)
    {
        // Sub-categories are already known
        [self addSubCateroriesToCategoryID:categoryTapped];
    }
    else
    {
        // Sub-categories are not known
//        NSLog(@"subCategories => getAlbumListForCategory(%ld,NO,NO)", (long)categoryTapped.albumId);
        
        // Show loading HD
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") andMode:MBProgressHUDModeIndeterminate];
        
        [AlbumService getAlbumListForCategory:categoryTapped.albumId
                                   usingCache:[Model sharedInstance].loadAllCategoryInfo
                              inRecursiveMode:NO
                                 OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                     // Add sub-categories
                                     [self addSubCateroriesToCategoryID:categoryTapped];
                                     
                                     // Hide loading HUD
                                     [self hideHUD];
                                     
                                 }
                                    onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                        NSLog(@"getAlbumListForCategory error %ld: %@", (long)error.code, error.localizedDescription);
#endif
                                        // Hide loading HUD
                                        [self hideHUD];
                                    }
         ];
    }
}

-(void)addSubCateroriesToCategoryID:(PiwigoAlbumData *)categoryTapped
{
    // Build list of categories from complete known list
    NSArray *allCategories = [CategoriesData sharedInstance].allCategories;
    
    // Proposed list is collected in diff
    NSMutableArray *diff = [NSMutableArray new];
    
    // Look for categories which are not already displayed
    for(PiwigoAlbumData *category in allCategories)
    {
        // Non-admin Community users can only upload in specific albums
        if (![Model sharedInstance].hasAdminRights && !category.hasUploadRights) {
            continue;
        }
        
        // Only add sub-categories of tapped category
        if (category.nearestUpperCategory != categoryTapped.albumId) {
            continue;
        }
        
        // Is this category already in displayed list?
        BOOL doesNotExist = YES;
        for(PiwigoAlbumData *existingCat in self.categories)
        {
            if(category.albumId == existingCat.albumId)
            {
                doesNotExist = NO;
                break;
            }
        }
        if(doesNotExist)
        {
            [diff addObject:category];
        }
    }
    
    // Build list of categories to be displayed
    for(PiwigoAlbumData *category in diff)
    {
        // Should we add sub-categories?
        if(category.upperCategories.count > 0)
        {
            NSInteger indexOfParent = 0;
            for(PiwigoAlbumData *existingCategory in self.categories)
            {
                if([category containsUpperCategory:existingCategory.albumId])
                {
                    [self.categories insertObject:category atIndex:indexOfParent+1];
                    break;
                }
                indexOfParent++;
            }
        }
    }
    
    // Add tapped category to list of categories having shown sub-categories
    [self.categoriesThatShowSubCategories addObject:@(categoryTapped.albumId)];
    
    // Reload table view
    [self.categoriesTableView reloadData];
}

-(void)removeSubCategoriesToCategoryID:(PiwigoAlbumData *)categoryTapped
{
    // Proposed list is collected in diff
    NSMutableArray *diff = [NSMutableArray new];
    
    // Look for sub-categories to remove
    for(PiwigoAlbumData *category in self.categories)
    {
        // Keep the parent category
        if (category.albumId == categoryTapped.albumId) {
            continue;
        }
        
        // Remove the sub-categories
        NSArray *upperCategories = category.upperCategories;
        if ([upperCategories containsObject:[NSString stringWithFormat:@"%ld", (long)categoryTapped.albumId]])
        {
            [diff addObject:category];
        }
    }
    
    // Remove objects from displayed list
    [self.categories removeObjectsInArray:diff];
    
    // Remove tapped category from list of categories having shown sub-categories
    if ([self.categoriesThatShowSubCategories containsObject:@(categoryTapped.albumId)]) {
        [self.categoriesThatShowSubCategories removeObject:@(categoryTapped.albumId)];
    }
    
    // Sub-categories will not be known if user closes several layers at once
    // and caching option loadAllCategoryInfo is not activated
    if (![Model sharedInstance].loadAllCategoryInfo) {
        //        NSLog(@"subCategories => getAlbumListForCategory(%ld,NO,NO)", (long)categoryTapped.albumId);
        
        // Show loading HD
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") andMode:MBProgressHUDModeIndeterminate];
        
        [AlbumService getAlbumListForCategory:categoryTapped.albumId
                                   usingCache:[Model sharedInstance].loadAllCategoryInfo
                              inRecursiveMode:NO
                                 OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                     // Reload table view
                                     [self.categoriesTableView reloadData];
                                     
                                     // Hide loading HUD
                                     [self hideHUD];
                                     
                                 }
                                    onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                        NSLog(@"getAlbumListForCategory error %ld: %@", (long)error.code, error.localizedDescription);
#endif
                                        // Hide loading HUD
                                        [self hideHUD];
                                    }
         ];
    } else {
        // Reload table view
        [self.categoriesTableView reloadData];
    }
}

@end
