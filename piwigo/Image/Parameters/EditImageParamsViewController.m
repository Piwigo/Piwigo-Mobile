//
//  EditImageParamsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "EditImageDatePickerTableViewCell.h"
#import "EditImageParamsViewController.h"
#import "EditImagePrivacyTableViewCell.h"
#import "EditImageShiftPickerTableViewCell.h"
#import "EditImageTagsTableViewCell.h"
#import "EditImageTextFieldTableViewCell.h"
#import "EditImageTextViewTableViewCell.h"
#import "EditImageThumbCollectionViewCell.h"
#import "EditImageThumbTableViewCell.h"
#import "ImageDetailViewController.h"
#import "ImageService.h"
#import "ImagesCollection.h"
#import "MBProgressHUD.h"
#import "PiwigoTagData.h"
#import "TagsData.h"

CGFloat const kEditImageParamsViewWidth = 512.0;

typedef enum {
    EditImageParamsOrderThumbnails,
	EditImageParamsOrderImageName,
	EditImageParamsOrderAuthor,
    EditImageParamsOrderDate,
    EditImageParamsOrderDatePicker,
	EditImageParamsOrderPrivacy,
	EditImageParamsOrderTags,
	EditImageParamsOrderDescription,
	EditImageParamsOrderCount
} EditImageParamsOrder;

@interface EditImageParamsViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UITextViewDelegate, EditImageThumbnailCellDelegate, EditImageDatePickerDelegate, EditImageShiftPickerDelegate, SelectPrivacyDelegate, TagsViewControllerDelegate>

@property (nonatomic, strong) PiwigoImageData *commonParameters;
@property (nonatomic, weak)   IBOutlet UITableView *editImageParamsTableView;
@property (nonatomic, strong) NSMutableArray<PiwigoImageData *> *imagesToUpdate;

@property (nonatomic, assign) BOOL hasDatePicker;
@property (nonatomic, assign) BOOL shouldUpdateTitle;
@property (nonatomic, assign) BOOL shouldUpdateAuthor;
@property (nonatomic, assign) BOOL shouldUpdateDateCreated;
@property (nonatomic, strong) NSDate *oldCreationDate;
@property (nonatomic, assign) BOOL shouldUpdatePrivacyLevel;
@property (nonatomic, assign) BOOL shouldUpdateTags;
@property (nonatomic, strong) NSMutableArray<PiwigoTagData *>* addedTags;
@property (nonatomic, strong) NSMutableArray<PiwigoTagData *>* removedTags;
@property (nonatomic, assign) BOOL shouldUpdateComment;
@property (nonatomic, strong) UIViewController *hudViewController;
@property (nonatomic, assign) double nberOfSelectedImages;

@end

@implementation EditImageParamsViewController

-(void)awakeFromNib
{
	[super awakeFromNib];
	
    self.title = NSLocalizedString(@"imageDetailsView_title", @"Properties");
	
    // Buttons
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEdit)];
    [cancel setAccessibilityIdentifier:@"Cancel"];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(doneEdit)];
    [done setAccessibilityIdentifier:@"Done"];

    // Navigation bar
    self.navigationController.navigationBarHidden = NO;
    self.navigationItem.leftBarButtonItem = cancel;
    self.navigationItem.rightBarButtonItem = done;

    // Register palette changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoNotificationPaletteChanged object:nil];
}

#pragma mark - View Lifecycle

-(void)applyColorPalette
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoColorBackground];

    // Navigation bar
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoColorWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.navigationBar.tintColor = [UIColor piwigoColorOrange];
    self.navigationController.navigationBar.barTintColor = [UIColor piwigoColorBackground];
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoColorBackground];

    // Table view
    self.editImageParamsTableView.separatorColor = [UIColor piwigoColorSeparator];
    self.editImageParamsTableView.backgroundColor = [UIColor piwigoColorBackground];
    [self.editImageParamsTableView reloadData];
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    // Register thumbnails cell
    [self.editImageParamsTableView registerNib:[UINib nibWithNibName:@"EditImageThumbTableViewCell" bundle:nil] forCellReuseIdentifier:kEditImageThumbTableCell_ID];

    // Register date picker cell
    [self.editImageParamsTableView registerNib:[UINib nibWithNibName:@"EditImageDatePickerTableViewCell" bundle:nil] forCellReuseIdentifier:kDatePickerTableCell_ID];
    self.hasDatePicker = NO;

    // Register date interval picker cell
    [self.editImageParamsTableView registerNib:[UINib nibWithNibName:@"EditImageShiftPickerTableViewCell" bundle:nil] forCellReuseIdentifier:kShiftPickerTableCell_ID];

    // Initialise common image properties, mostly from first supplied image
    self.commonParameters = [PiwigoImageData new];

    // Common title?
    self.commonParameters.imageTitle = self.images[0].imageTitle;
    for (PiwigoImageData *imageData in self.images) {
        // Keep title of first image if identical
        if ([self.commonParameters.imageTitle isEqualToString:imageData.imageTitle]) continue;
        
        // Images titles are different
        self.commonParameters.imageTitle = @"";
        break;
    }
    self.shouldUpdateTitle = NO;

    // Common author?
    self.commonParameters.author = self.images[0].author;
    for (PiwigoImageData *imageData in self.images) {
        // Keep author of first image if identical
        if ([self.commonParameters.author isEqualToString:imageData.author]) continue;
        
        // Images authors are different
        self.commonParameters.author = @"";
        break;
    }
    self.shouldUpdateAuthor = NO;

    // Common creation date is date of first image with non-nil value, or nil
    for (PiwigoImageData *imageData in self.images) {
        // Keep first non-nil date value
        if (imageData.dateCreated != nil) {
            self.commonParameters.dateCreated = imageData.dateCreated;
            self.oldCreationDate = imageData.dateCreated;
            break;
        }
    }
    if (self.commonParameters.dateCreated == nil) {
        self.oldCreationDate = nil;
    }
    self.shouldUpdateDateCreated = NO;
    
    // Common privacy?
    self.commonParameters.privacyLevel = self.images[0].privacyLevel;
    for (PiwigoImageData *imageData in self.images) {
        // Keep privacy of first image if identical
        if (self.commonParameters.privacyLevel == imageData.privacyLevel) continue;
        
        // Images privacy levels are different, display no level
        self.commonParameters.privacyLevel = kPiwigoPrivacyUnknown;
        break;
    }
    self.shouldUpdatePrivacyLevel = NO;

    // Common tags?
    self.commonParameters.tags = [self.images[0].tags mutableCopy];
    NSMutableArray<PiwigoTagData *> *newTags = [[NSMutableArray<PiwigoTagData *> alloc] initWithArray:self.commonParameters.tags];
    for (PiwigoImageData *imageData in self.images) {
        // Loop over the common tags
        NSMutableArray<PiwigoTagData *> *tempTagList = [[NSMutableArray<PiwigoTagData *> alloc] initWithArray:newTags];
        for (PiwigoTagData *tag in tempTagList) {
            // Remove tags not belonging to other images
            if (![[TagsData sharedInstance] listOfTags:imageData.tags containsTag:tag]) [newTags removeObject:tag];
            // Done if empty list
            if (newTags.count == 0) break;
        }
        // Done if empty list
        if (newTags.count == 0) break;
    }
    self.commonParameters.tags = newTags;
    self.shouldUpdateTags = NO;
    
    // Common comment?
    self.commonParameters.comment = self.images[0].comment;
    for (PiwigoImageData *imageData in self.images) {
        // Keep comment of first image if identical
        if ([self.commonParameters.comment isEqualToString:imageData.comment]) continue;
        
        // Images comments are different, display no comment
        self.commonParameters.comment = @"";
        break;
    }
    self.shouldUpdateComment = NO;

    // Set colors, fonts, etc.
    [self applyColorPalette];
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

    // Adjust content inset
    // See https://stackoverflow.com/questions/1983463/whats-the-uiscrollview-contentinset-property-for
    CGFloat navBarHeight = self.navigationController.navigationBar.bounds.size.height;
    CGFloat tableHeight = self.editImageParamsTableView.bounds.size.height;
    CGFloat viewHeight = self.view.bounds.size.height;

    // On iPad, the form is presented in a popover view
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [self.editImageParamsTableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, MAX(0.0, tableHeight + navBarHeight - viewHeight), 0.0)];
    } else {
        CGFloat statBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        [self.editImageParamsTableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, MAX(0.0, tableHeight + statBarHeight + navBarHeight - viewHeight), 0.0)];
    }
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        // Adjust content inset
        // See https://stackoverflow.com/questions/1983463/whats-the-uiscrollview-contentinset-property-for
        CGFloat navBarHeight = self.navigationController.navigationBar.bounds.size.height;
        CGFloat tableHeight = self.editImageParamsTableView.bounds.size.height;

        // On iPad, the form is presented in a popover view
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            CGRect mainScreenBounds = [UIScreen mainScreen].bounds;
            self.preferredContentSize = CGSizeMake(kPiwigoPadSubViewWidth,
                                                   ceil(CGRectGetHeight(mainScreenBounds)*2/3));
            [self.editImageParamsTableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, MAX(0.0, tableHeight + navBarHeight - size.height), 0.0)];
        } else {
            CGFloat statBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
            [self.editImageParamsTableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, MAX(0.0, tableHeight + statBarHeight + navBarHeight - size.height), 0.0)];
        }

        // Reload table view
        [self.editImageParamsTableView reloadData];

    } completion:nil];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    // Unregister palette changes
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationPaletteChanged object:nil];

    // Check if the user is still editing parameters
    if ([self.navigationController.visibleViewController isKindOfClass:[SelectPrivacyViewController class]] ||
        [self.navigationController.visibleViewController isKindOfClass:[TagsViewController class]]) {
        return;
    }
    
    // Return updated parameters
    if ([self.delegate respondsToSelector:@selector(didFinishEditingParameters)])
    {
        [self.delegate didFinishEditingParameters];
    }
}


#pragma mark - Edit image Methods

-(void)cancelEdit
{
    // No change
    self.commonParameters = nil;
    
    // Return to image preview
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)doneEdit
{
    // Initialise new image list and time shift
    NSTimeInterval timeInterval = 0.0;
    if ((self.commonParameters.dateCreated != nil) && (self.oldCreationDate != nil)) {
        timeInterval = [self.commonParameters.dateCreated timeIntervalSinceDate:self.oldCreationDate];
    }
    NSMutableArray<PiwigoImageData *> *updatedImages = [NSMutableArray<PiwigoImageData *> new];

    // Update all images
    for (PiwigoImageData *imageData in self.images)
    {
        // Update image title?
        if (self.commonParameters.imageTitle && self.shouldUpdateTitle) {
            imageData.imageTitle = self.commonParameters.imageTitle;
        }

        // Update image author?
        if (self.commonParameters.author && self.shouldUpdateAuthor) {
            imageData.author = self.commonParameters.author;
        }

        // Update image creation date?
        if (self.shouldUpdateDateCreated) {
            if (self.commonParameters.dateCreated == nil) {
                imageData.dateCreated = nil;
            } else if (self.oldCreationDate == nil) {
                imageData.dateCreated  = self.commonParameters.dateCreated;
            } else {
                imageData.dateCreated = [imageData.dateCreated dateByAddingTimeInterval:timeInterval];
            }
        }
        
        // Update image privacy level?
        if ((self.commonParameters.privacyLevel != kPiwigoPrivacyUnknown) && self.shouldUpdatePrivacyLevel) {
            imageData.privacyLevel = self.commonParameters.privacyLevel;
        }
        
        // Update image tags?
        if ((self.commonParameters.tags) && self.shouldUpdateTags) {
            // Retrieve tags of current image
            NSMutableArray<PiwigoTagData *> *imageTags = [imageData.tags mutableCopy];
            
            // Loop over the removed tags
            for (PiwigoTagData *tag in self.removedTags) {
                NSInteger indexOfExistingItem = [imageTags indexOfObjectPassingTest:^BOOL(PiwigoTagData * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    return obj.tagId == tag.tagId;
                }];
                if (indexOfExistingItem != NSNotFound) {
                    [imageTags removeObjectAtIndex:indexOfExistingItem];
                }
            }

            // Loop over the added tags
            for (PiwigoTagData *tag in self.addedTags) {
                NSInteger indexOfExistingItem = [imageTags indexOfObjectPassingTest:^BOOL(PiwigoTagData * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    return obj.tagId == tag.tagId;
                }];
                if (indexOfExistingItem == NSNotFound) {
                    [imageTags addObject:tag];
                }
            }

            // Append image data
            imageData.tags = [imageTags copy];
        }

        // Update image description?
        if ((self.commonParameters.comment) && self.shouldUpdateComment) {
            imageData.comment = self.commonParameters.comment;
        }
        
        // Append image data
        [updatedImages addObject:imageData];
    }
    self.images = updatedImages;
    self.imagesToUpdate = [self.images mutableCopy];
    
    // Start updating Piwigo database
    [self updateImageProperties];
}

-(void)updateImageProperties
{
    // Display HUD during the update
    if (self.imagesToUpdate.count > 1) {
        self.nberOfSelectedImages = (double)(self.imagesToUpdate.count);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showHUDwithTitle:NSLocalizedString(@"editImageDetailsHUD_updatingPlural", @"Updating Photos…") andMode:MBProgressHUDModeIndeterminate];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showHUDwithTitle:NSLocalizedString(@"editImageDetailsHUD_updatingSingle", @"Updating Photo…") andMode:MBProgressHUDModeAnnularDeterminate];
        });
    }
    
    // Update image info on server and in cache
    [ImageService setImageProperties:[self.imagesToUpdate lastObject]
                           onProgress:^(NSProgress *progress) {
                            // Progress
                            }
                          OnCompletion:^(NSURLSessionTask *task, NSDictionary *response)
                            {
                                if([[response objectForKey:@"stat"] isEqualToString:@"ok"])
                                {
                                    // Next image?
                                    [self.imagesToUpdate removeLastObject];
                                    if (self.imagesToUpdate.count) {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [MBProgressHUD HUDForView:self.hudViewController.view].progress = 1.0 - (double)(self.imagesToUpdate.count) / self.nberOfSelectedImages;
                                        });
                                        [self updateImageProperties];
                                    }
                                    else {
                                        // Done, hide HUD and dismiss controller
                                        [self hideHUDwithSuccess:YES completion:^{
                                            // Return to image preview or album view
                                            [self dismissViewControllerAnimated:YES completion:^{
                                                if ([self.delegate respondsToSelector:@selector(didChangeParamsOfImage:)])
                                                {
                                                    [self.delegate didChangeParamsOfImage:self.commonParameters];
                                                }
                                            }];
                                        }];
                                    }
                                }
                                else
                                {
                                    // Display Piwigo error in HUD
                                    NSError *error = [NetworkHandler getPiwigoErrorFromResponse:response path:kPiwigoImageSetInfo andURLparams:nil];
                                    [self hideHUDwithSuccess:NO completion:^{
                                        [self showErrorWithMessage:[error localizedDescription]];
                                    }];
                                }
                            }
                             onFailure:^(NSURLSessionTask *task, NSError *error) {
                                // Failed
                                [self hideHUDwithSuccess:NO completion:^{
                                    [self showErrorWithMessage:[error localizedDescription]];
                                }];
                            }];
}

-(void)showErrorWithMessage:(NSString*)message
{
    UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"editImageDetailsError_title", @"Failed to Update")
            message:message
            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancelAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                    style:UIAlertActionStyleCancel
                    handler:^(UIAlertAction * action) {
                    }];

    UIAlertAction* dismissAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                    style:UIAlertActionStyleCancel
                    handler:^(UIAlertAction * action) {
                        // Bypass this image
                        [self.imagesToUpdate removeLastObject];
                        // Next image
                        if (self.imagesToUpdate.count) [self updateImageProperties];
                    }];

    UIAlertAction* retryAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                    style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction * action) {
                        [self updateImageProperties];
                    }];

    [alert addAction:cancelAction];
    if (self.imagesToUpdate.count > 2) [alert addAction:dismissAction];
    [alert addAction:retryAction];
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [self presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}


#pragma mark - HUD Methods

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
        hud.contentColor = [UIColor piwigoColorText];
        hud.bezelView.color = [UIColor piwigoColorText];
        hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.bezelView.backgroundColor = [UIColor piwigoColorCellBackground];

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
//    if (self.isLoadingCategories || self.isLoadingImageData) return;
    MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
    if (hud) {
        [hud hideAnimated:YES];
        self.hudViewController = nil;
    }
}

//-(void)showUpdatingImageInfoHUD
//{
//    // Create the loading HUD if needed
//    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
//    if (!hud) {
//        hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
//    }
//    
//    // Change the background view shape, style and color.
//    hud.square = NO;
//    hud.animationType = MBProgressHUDAnimationFade;
//    hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
//    hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
//    hud.contentColor = [UIColor piwigoColorHudContent];
//    hud.bezelView.color = [UIColor piwigoColorHudBezelView];
//
//    // Define the text
//    hud.label.text = NSLocalizedString(@"editImageDetailsHUD_updating", @"Updating Image Info…");
//    hud.label.font = [UIFont piwigoFontNormal];
//}
//
//-(void)hideUpdatingImageInfoHUDwithSuccess:(BOOL)success completion:(void (^)(void))completion
//{
//    dispatch_async(dispatch_get_main_queue(), ^{
//        // Hide and remove the HUD
//        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
//        if (hud) {
//            if (success) {
//                UIImage *image = [[UIImage imageNamed:@"completed"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
//                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
//                hud.customView = imageView;
//                hud.mode = MBProgressHUDModeCustomView;
//                hud.label.text = NSLocalizedString(@"completeHUD_label", @"Complete");
//                [hud hideAnimated:YES afterDelay:2.f];
//            } else {
//                [hud hideAnimated:YES];
//            }
//        }
//        if (completion) {
//            completion();
//        }
//    });
//}


#pragma mark - UITableView - Rows

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.0;        // To hide the section header
}

- (CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0.0;        // To hide the section footer
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = 44.0;
    NSInteger row = indexPath.row;
    if (self.hasDatePicker == NO) {
        // Bypass the date picker
        if (row > EditImageParamsOrderDate) row++;
    }
    switch (row)
    {
        case EditImageParamsOrderThumbnails:
            height = 188.0;
            break;
            
        case EditImageParamsOrderDatePicker:
            if (self.images.count > 1) {
                // Time interval picker
                height = 258.0;
            } else {
                // Date picker
                height = 304.0;
            }
            break;
        
        case EditImageParamsOrderPrivacy:
        case EditImageParamsOrderTags:
            height = 73.0;
            break;
            
        case EditImageParamsOrderDescription:
            height = 428.0;
            break;

        default:
            break;
    }

    return height;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return EditImageParamsOrderCount - (self.hasDatePicker == NO);
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tableViewCell = [UITableViewCell new];

    NSInteger row = indexPath.row;
    if (self.hasDatePicker == NO) {
        // Bypass the date picker
        if (row > EditImageParamsOrderDate) row++;
    }
    switch (row)
	{
        case EditImageParamsOrderThumbnails:
        {
            EditImageThumbTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kEditImageThumbTableCell_ID forIndexPath:indexPath];
            [cell setupWithImages:self.images];
            cell.delegate = self;
            tableViewCell = cell;
            break;
        }
        
        case EditImageParamsOrderImageName:
		{
            EditImageTextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"title" forIndexPath:indexPath];
            [cell setupWithLabel:NSLocalizedString(@"editImageDetails_title", @"Title")
                     placeHolder:NSLocalizedString(@"editImageDetails_titlePlaceholder", @"Title")
                  andImageDetail:self.commonParameters.imageTitle];
            if (self.shouldUpdateTitle) cell.cellTextField.textColor = [UIColor piwigoColorOrange];
            cell.cellTextField.tag = EditImageParamsOrderImageName;
            cell.cellTextField.delegate = self;
            tableViewCell = cell;
            break;
		}
		
        case EditImageParamsOrderAuthor:
		{
            EditImageTextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"author" forIndexPath:indexPath];
            [cell setupWithLabel:NSLocalizedString(@"editImageDetails_author", @"Author")
                     placeHolder:NSLocalizedString(@"settings_defaultAuthorPlaceholder", @"Author Name")
                  andImageDetail:[self.commonParameters.author isEqualToString:@"NSNotFound"] ? @"" : self.commonParameters.author];
            if (self.shouldUpdateAuthor) cell.cellTextField.textColor = [UIColor piwigoColorOrange];
            cell.cellTextField.tag = EditImageParamsOrderAuthor;
            cell.cellTextField.delegate = self;
            tableViewCell = cell;
			break;
		}
		
        case EditImageParamsOrderDate:
        {
            EditImageTextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"dateCreation" forIndexPath:indexPath];
            [cell setupWithLabel:NSLocalizedString(@"editImageDetails_dateCreation", @"Creation Date")
                     placeHolder:@""
                  andImageDetail:[self getStringFromDate:self.commonParameters.dateCreated]];
            if (self.shouldUpdateDateCreated) cell.cellTextField.textColor = [UIColor piwigoColorOrange];
            cell.cellTextField.tag = EditImageParamsOrderDate;
            cell.cellTextField.delegate = self;
            tableViewCell = cell;
            break;
        }
        
        case EditImageParamsOrderDatePicker:
        {
            // Which picker?
            if (self.images.count > 1) {
                EditImageShiftPickerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kShiftPickerTableCell_ID forIndexPath:indexPath];
                [cell setShiftPickerWithDate:self.commonParameters.dateCreated animated:NO];
                cell.delegate = self;
                tableViewCell = cell;
            }
            else {
                EditImageDatePickerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kDatePickerTableCell_ID forIndexPath:indexPath];
                [cell setDatePickerWithDate:self.commonParameters.dateCreated animated:NO];
                [cell setDatePickerButtons];
                cell.delegate = self;
                tableViewCell = cell;
            }
            break;
        }
        
        case EditImageParamsOrderPrivacy:
		{
			EditImagePrivacyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"privacy" forIndexPath:indexPath];
			[cell setLeftLabelText:NSLocalizedString(@"editImageDetails_privacyLevel", @"Who can see this photo?")];
            [cell setPrivacyLevel:self.commonParameters.privacyLevel inColor:self.shouldUpdatePrivacyLevel ? [UIColor piwigoColorOrange] : [UIColor piwigoColorRightLabel]];
            tableViewCell = cell;
			break;
		}
		
        case EditImageParamsOrderTags:
		{
			EditImageTagsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"tags" forIndexPath:indexPath];
            [cell setTagList:self.commonParameters.tags inColor:self.shouldUpdateTags ? [UIColor piwigoColorOrange] : [UIColor piwigoColorRightLabel]];
            tableViewCell = cell;
			break;
		}
		
        case EditImageParamsOrderDescription:
		{
			EditImageTextViewTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"description" forIndexPath:indexPath];
            [cell setComment:self.commonParameters.comment inColor:self.shouldUpdateTags ? [UIColor piwigoColorOrange] : [UIColor piwigoColorRightLabel]];
            cell.textView.delegate = self;
            tableViewCell = cell;
			break;
		}
	}
	
    tableViewCell.backgroundColor = [UIColor piwigoColorCellBackground];
    tableViewCell.tintColor = [UIColor piwigoColorOrange];
	return tableViewCell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = indexPath.row;
    if (self.hasDatePicker == NO) {
        // Bypass the date picker
        if (row > EditImageParamsOrderDate) row++;
    }
    switch (row)
    {
        case EditImageParamsOrderPrivacy:
        {
            // Deselect row
            [tableView deselectRowAtIndexPath:indexPath animated:YES];

            // Dismiss the keyboard
            [self.view endEditing:YES];
            
            // Create view controller
            UIStoryboard *privacySB = [UIStoryboard storyboardWithName:@"SelectPrivacyViewController" bundle:nil];
            SelectPrivacyViewController *privacyVC = [privacySB instantiateViewControllerWithIdentifier:@"SelectPrivacyViewController"];
            privacyVC.delegate = self;
            [privacyVC setPrivacy:(kPiwigoPrivacy)self.commonParameters.privacyLevel];
            [self.navigationController pushViewController:privacyVC animated:YES];
            break;
        }
            
        case EditImageParamsOrderTags:
        {
            // Deselect row
            [tableView deselectRowAtIndexPath:indexPath animated:YES];

            // Dismiss the keyboard
            [self.view endEditing:YES];
            
            // Create view controller
            UIStoryboard *tagsSB = [UIStoryboard storyboardWithName:@"TagsViewController" bundle:nil];
            TagsViewController *tagsVC = [tagsSB instantiateViewControllerWithIdentifier:@"TagsViewController"];
            tagsVC.delegate = self;
            NSMutableArray *tagList = [NSMutableArray new];
            for (PiwigoTagData *tag in self.commonParameters.tags) {
                [tagList addObject:[NSNumber numberWithLong:tag.tagId]];
            }
            [tagsVC setSelectedTagIds: tagList];
            [self.navigationController pushViewController:tagsVC animated:YES];
            break;
        }
        
        default:
            break;
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL result;
    NSInteger row = indexPath.row;
    if (self.hasDatePicker == NO) {
        // Bypass the date picker
        if (row > EditImageParamsOrderDate) row++;
    }
    switch (row)
    {
        case EditImageParamsOrderImageName:
        case EditImageParamsOrderAuthor:
        case EditImageParamsOrderDate:
        case EditImageParamsOrderDatePicker:
        case EditImageParamsOrderDescription:
            result = NO;
            break;
            
        default:
            result = YES;
    }
    
    return result;
}


#pragma mark - UITextFieldDelegate Methods

-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (textField.tag == EditImageParamsOrderDate) {
        // The common date can be nil or past distant (i.e. unset)
        if (self.commonParameters.dateCreated == nil) {
            // Define date as today
            self.commonParameters.dateCreated = [NSDate date];
            self.shouldUpdateDateCreated = YES;
            
            // Update creation date
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:EditImageParamsOrderDate inSection:0];
            [self.editImageParamsTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        
        // Show date or hide picker
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:EditImageParamsOrderDatePicker inSection:0];
        if (self.hasDatePicker) {
            // Found a picker, so remove it
            self.hasDatePicker = NO;
            [self.editImageParamsTableView beginUpdates];
            [self.editImageParamsTableView deleteRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            [self.editImageParamsTableView endUpdates];
        }
        else {
            // Didn't find a picker, so we should insert it
            self.hasDatePicker = YES;
            [self.editImageParamsTableView beginUpdates];
            [self.editImageParamsTableView insertRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            [self.editImageParamsTableView endUpdates];
        }

        // Prevent keyboard from opening
        return NO;
    }
    
    return YES;
}

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
    switch (textField.tag)
    {
        case EditImageParamsOrderImageName:
        {
            // Title
            self.shouldUpdateTitle = YES;
            textField.textColor = [UIColor piwigoColorOrange];
            break;
        }
            
        case EditImageParamsOrderAuthor:
        {
            // Author
            self.shouldUpdateAuthor = YES;
            textField.textColor = [UIColor piwigoColorOrange];
            break;
        }
    }
}

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *finalString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    switch (textField.tag)
    {
        case EditImageParamsOrderImageName:
        {
            // Title
            self.commonParameters.imageTitle = finalString;
            break;
        }
            
        case EditImageParamsOrderAuthor:
        {
            // Author
            if (finalString.length > 0) {
                self.commonParameters.author = finalString;
            } else {
                self.commonParameters.author = @"NSNotFound";
            }
            break;
        }
    }
    return YES;
}

-(BOOL)textFieldShouldClear:(UITextField *)textField
{
    switch (textField.tag)
    {
        case EditImageParamsOrderImageName:
        {
            // Title
            self.commonParameters.imageTitle = @"";
            break;
        }
            
        case EditImageParamsOrderAuthor:
        {
            // Author
            self.commonParameters.author = @"NSNotFound";
            break;
        }
    }
    return YES;
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.editImageParamsTableView endEditing:YES];
    return YES;
}

-(void)textFieldDidEndEditing:(UITextField *)textField
{
    switch (textField.tag)
    {
        case EditImageParamsOrderImageName:
        {
            // Title
            self.commonParameters.imageTitle = textField.text;
            break;
        }
            
        case EditImageParamsOrderAuthor:
        {
            // Author
            if (textField.text.length > 0) {
                self.commonParameters.author = textField.text;
            } else {
                self.commonParameters.author = @"NSNotFound";
            }
            break;
        }
    }
}


#pragma mark - UITextViewDelegate Methods

-(void)textViewDidBeginEditing:(UITextView *)textView
{
    self.shouldUpdateComment = YES;
    textView.textColor = [UIColor piwigoColorOrange];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    NSString *finalString = [textView.text stringByReplacingCharactersInRange:range withString:text];
    self.commonParameters.comment = finalString;
    return YES;
}

-(BOOL)textViewShouldEndEditing:(UITextView *)textView
{
    [self.editImageParamsTableView endEditing:YES];
    return YES;
}

-(void)textViewDidEndEditing:(UITextView *)textView
{
    self.commonParameters.comment = textView.text;
}


#pragma mark - EditImageThumbnailCellDelegate Methods

-(void)didDeselectImageWithId:(NSInteger)imageId
{
    // Hide picker if needed
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:EditImageParamsOrderDatePicker inSection:0];
    if (self.hasDatePicker) {
        // Found a picker, so remove it
        self.hasDatePicker = NO;
        [self.editImageParamsTableView beginUpdates];
        [self.editImageParamsTableView deleteRowsAtIndexPaths:@[indexPath]
                         withRowAnimation:UITableViewRowAnimationFade];
        [self.editImageParamsTableView endUpdates];
    }

    // Update data source
    NSMutableArray *newImages = [[NSMutableArray alloc] initWithArray:self.images];
    NSTimeInterval timeInterval = [self.commonParameters.dateCreated timeIntervalSinceDate:self.oldCreationDate];
    for (PiwigoImageData *imageData in self.images)
    {
        if (imageData.imageId == imageId)
        {
            [newImages removeObject:imageData];
            break;
        }
    }
    self.images = newImages;
    
    // Update common creation date if needed
    for (PiwigoImageData *imageData in self.images) {
        // Keep first non-nil date value
        if (imageData.dateCreated != nil) {
            self.oldCreationDate = imageData.dateCreated;
            self.commonParameters.dateCreated = [self.oldCreationDate dateByAddingTimeInterval:timeInterval];
            break;
        }
    }
    if (self.commonParameters.dateCreated == nil) {
        self.oldCreationDate = nil;
    }

    // Refresh table
    [self.editImageParamsTableView reloadData];

    // Deselect image in album view
    if ([self.delegate respondsToSelector:@selector(didDeselectImageWithId:)])
    {
        [self.delegate didDeselectImageWithId:imageId];
    }
}

-(void)didRenameFileOfImage:(PiwigoImageData *)imageData
{
    // Update data source
    PiwigoImageData *updatedImage;
    NSMutableArray *updatedImages = [[NSMutableArray alloc] initWithArray:self.images];
    for (NSInteger index = 0; index < self.images.count; index++)
    {
        PiwigoImageData *image = [self.images objectAtIndex:index];
        if (image.imageId == imageData.imageId) {
            [updatedImages replaceObjectAtIndex:index withObject:imageData];
            break;
        }
    }
    self.images = updatedImages;
    
    // Update parent image view
    if ([self.delegate respondsToSelector:@selector(didRenameFileOfImage:)])
    {
        [self.delegate didRenameFileOfImage:updatedImage];
    }
}


# pragma mark -  EditImageDatePickerDelegate Methods

-(void)didSelectDateWithPicker:(NSDate *)date
{
    // Apply new date
    self.shouldUpdateDateCreated = YES;
    self.commonParameters.dateCreated = date;
    
    // Update cell
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:EditImageParamsOrderDate inSection:0];
    [self.editImageParamsTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

-(void)didUnsetImageCreationDate
{
    self.commonParameters.dateCreated = nil;
    self.shouldUpdateDateCreated = YES;
    
    // Close date picker
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:EditImageParamsOrderDatePicker inSection:0];
    if (self.hasDatePicker) {
        self.hasDatePicker = NO;
        [self.editImageParamsTableView beginUpdates];
        [self.editImageParamsTableView deleteRowsAtIndexPaths:@[indexPath]
                         withRowAnimation:UITableViewRowAnimationFade];
        [self.editImageParamsTableView endUpdates];
    }

    // Update creation date cell
    indexPath = [NSIndexPath indexPathForRow:EditImageParamsOrderDate inSection:0];
    [self.editImageParamsTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}


# pragma mark -  EditImageShiftPickerDelegate Methods

-(void)didSelectDateWithShiftPicker:(NSDate *)date
{
     // Apply new date
    self.shouldUpdateDateCreated = YES;
    self.commonParameters.dateCreated = date;
    
    // Update cell
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:EditImageParamsOrderDate inSection:0];
    [self.editImageParamsTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}


#pragma mark - SelectPrivacyDelegate Methods

-(void)didSelectPrivacyLevel:(kPiwigoPrivacy)privacyLevel
{
    // Check if the user decided to leave the Edit mode
    if (![self.navigationController.visibleViewController isKindOfClass:[EditImageParamsViewController class]]) {
        // Return updated parameters
        if ([self.delegate respondsToSelector:@selector(didFinishEditingParameters)])
        {
            [self.delegate didFinishEditingParameters];
        }
        return;
    }

	// Update image parameter?
    if (privacyLevel != self.commonParameters.privacyLevel) {
        // Remember to update image info
        self.shouldUpdatePrivacyLevel = YES;
        self.commonParameters.privacyLevel = privacyLevel;
	
        // Refresh table row
        NSInteger row = EditImageParamsOrderPrivacy - (self.hasDatePicker == NO ? 1 : 0);
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
        [self.editImageParamsTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}


#pragma mark - TagsViewControllerDelegate Methods

-(void)didSelectTags:(NSArray<Tag *> *)selectedTags
{
    // Check if the user decided to leave the Edit mode
    if (![self.navigationController.visibleViewController isKindOfClass:[EditImageParamsViewController class]]) {
        // Return updated parameters
        if ([self.delegate respondsToSelector:@selector(didFinishEditingParameters)])
        {
            [self.delegate didFinishEditingParameters];
        }
        return;
    }

    // Build new list of common tags (i.e. Tag -> PiwigoTagData)
    NSMutableArray<PiwigoTagData *>* newCommonTags = [NSMutableArray new];
    for (Tag *selectedTag in selectedTags) {
        PiwigoTagData *newTag = [PiwigoTagData new];
        newTag.tagId = selectedTag.tagId;
        newTag.tagName = selectedTag.tagName;
        newTag.lastModified = selectedTag.lastModified;
        newTag.numberOfImagesUnderTag = selectedTag.numberOfImagesUnderTag;
        [newCommonTags addObject:newTag];
//        NSLog(@"==> %@", newTag);
    }

    // Build list of added tags
    self.addedTags = [NSMutableArray new];
    for (PiwigoTagData *tag in newCommonTags) {
        NSInteger indexOfExistingTag = [self.commonParameters.tags indexOfObjectPassingTest:^BOOL(PiwigoTagData * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return obj.tagId == tag.tagId;
        }];
        if (indexOfExistingTag == NSNotFound) {
            [self.addedTags addObject:tag];
        }
    }

    // Build list of removed tags
    self.removedTags = [NSMutableArray new];
    for (PiwigoTagData *tag in self.commonParameters.tags) {
        NSInteger indexOfExistingTag = [newCommonTags indexOfObjectPassingTest:^BOOL(PiwigoTagData * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return obj.tagId == tag.tagId;
        }];
        if (indexOfExistingTag == NSNotFound) {
            [self.removedTags addObject:tag];
        }
    }
    
    // Do we need to update images?
    if (self.addedTags.count > 0 || self.removedTags.count > 0) {
        // Update common tag list and remember to update image info
        self.shouldUpdateTags = YES;
        self.commonParameters.tags = newCommonTags;

        // Refresh table row
        NSInteger row = EditImageParamsOrderTags - (self.hasDatePicker == NO ? 1 : 0);
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
        [self.editImageParamsTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}


#pragma mark - Utilities

-(NSString *)getStringFromDate:(NSDate *)date
{
    NSString *dateStr = @""; NSString *timeStr = @"";
    if (date != nil) {
        if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7,8 screen width
            dateStr = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
            timeStr = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
        } else if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
            dateStr = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle];
            timeStr = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
        } else {
            dateStr = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
            timeStr = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
        }
    }
    return [NSString stringWithFormat:@"%@ - %@", dateStr, timeStr];
}
@end
