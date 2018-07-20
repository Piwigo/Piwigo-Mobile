//
//  ImageDetailViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "AppDelegate.h"
#import "ImageDetailViewController.h"
#import "CategoriesData.h"
#import "ImageService.h"
#import "Model.h"
#import "ImagePreviewViewController.h"
#import "EditImageDetailsViewController.h"
#import "ImageUpload.h"
#import "ImageScrollView.h"
#import "AllCategoriesViewController.h"
#import "SAMKeychain.h"
#import "MBProgressHUD.h"

NSString * const kPiwigoNotificationPinchedImage = @"kPiwigoNotificationPinchedImage";

@interface ImageDetailViewController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, ImagePreviewDelegate, EditImageDetailsDelegate, UIToolbarDelegate>

@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, strong) PiwigoImageData *imageData;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) NSLayoutConstraint *topProgressBarConstraint;
@property (nonatomic, strong) UIViewController *hudViewController;

@property (nonatomic, strong) UIBarButtonItem *editBarButton;
@property (nonatomic, strong) UIBarButtonItem *deleteBarButton;
@property (nonatomic, strong) UIBarButtonItem *downloadBarButton;
@property (nonatomic, strong) UIBarButtonItem *setThumbnailBarButton;
@property (nonatomic, strong) UIBarButtonItem *spaceBetweenButtons;
@property (nonatomic, assign) BOOL isToolbarRequired;

@end

@implementation ImageDetailViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId atImageIndex:(NSInteger)imageIndex withArray:(NSArray *)array
{
	self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
	if(self)
	{
		self.categoryId = categoryId;
		self.images = [array mutableCopy];
		
		self.dataSource = self;
		self.delegate = self;
		
		self.imageData = [self.images objectAtIndex:imageIndex];
		self.title = self.imageData.name;
		ImagePreviewViewController *startingImage = [ImagePreviewViewController new];
		[startingImage setImageScrollViewWithImageData:self.imageData];
		startingImage.imageIndex = imageIndex;
        startingImage.imagePreviewDelegate = self;
		
		[self setViewControllers:@[startingImage]
					   direction:UIPageViewControllerNavigationDirectionForward
						animated:NO
					  completion:nil];
		
        // Progress bar
		self.progressBar = [UIProgressView new];
		self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
		self.progressBar.hidden = NO;
		self.progressBar.tintColor = [UIColor piwigoOrange];
		[self.view addSubview:self.progressBar];
		[self.view addConstraints:[NSLayoutConstraint constraintFillWidth:self.progressBar]];
		[self.progressBar addConstraint:[NSLayoutConstraint constraintView:self.progressBar toHeight:3]];
		self.topProgressBarConstraint = [NSLayoutConstraint
                                constraintWithItem:self.progressBar
                                         attribute:NSLayoutAttributeTop
                                         relatedBy:NSLayoutRelationEqual
                                toItem:self.view
                                         attribute:NSLayoutAttributeTop
                                         multiplier:1.0 constant:0];
		[self.view addConstraint:self.topProgressBarConstraint];
		
        // Bar buttons
        self.editBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editImage)];
        self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteImage)];
        self.deleteBarButton.tintColor = [UIColor redColor];
        self.downloadBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"download"] landscapeImagePhone:[UIImage imageNamed:@"downloadCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(downloadImage)];
        self.downloadBarButton.tintColor = [UIColor piwigoOrange];
        self.setThumbnailBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"paperclip"] landscapeImagePhone:[UIImage imageNamed:@"paperclipCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(setAsAlbumImage)];
        self.setThumbnailBarButton.tintColor = [UIColor piwigoOrange];
        self.spaceBetweenButtons = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
        self.navigationController.toolbar.barStyle = UIBarStyleDefault;
        [self.navigationController setToolbarHidden:YES animated:YES];

        // For managing taps
		[self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapView)]];

        // Register image pinches
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didPinchView) name:kPiwigoNotificationPinchedImage object:nil];

        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(paletteChanged) name:kPiwigoNotificationPaletteChanged object:nil];
	}
	return self;
}

-(void)paletteChanged
{
    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    [self.navigationController.navigationBar setTintColor:[UIColor piwigoOrange]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
    // Always open this view with a navigation bar
    // and never present video poster in full screen
    [self.navigationController setNavigationBarHidden:NO animated:YES];

    // Set colors, fonts, etc.
    [self paletteChanged];

    // Image options buttons
    [self updateNavBar];
    
    // Scrolling
	if([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)])
	{
		self.automaticallyAdjustsScrollViewInsets = false;
		self.edgesForExtendedLayout = UIRectEdgeNone;
	}
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    //Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self updateNavBar];
    } completion:nil];
}

-(void)updateNavBar
{
    // Interface depends on device and orientation
    if (([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) &&
        (([[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeLeft) &&
         ([[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeRight))) {
            
            // Redefine bar buttons (definition lost after rotation of device)
            self.editBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editImage)];
            self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteImage)];
            self.deleteBarButton.tintColor = [UIColor redColor];
            self.downloadBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"download"] landscapeImagePhone:[UIImage imageNamed:@"downloadCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(downloadImage)];
            self.downloadBarButton.tintColor = [UIColor piwigoOrange];
            self.setThumbnailBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"paperclip"] landscapeImagePhone:[UIImage imageNamed:@"paperclipCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(setAsAlbumImage)];
            self.setThumbnailBarButton.tintColor = [UIColor piwigoOrange];
            self.spaceBetweenButtons = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];

            if ([Model sharedInstance].hasAdminRights)
            {
                // User with admin rights can edit, delete images and set as album image
                [self.navigationItem setRightBarButtonItems:@[self.editBarButton]];
                self.toolbarItems = @[self.downloadBarButton, self.spaceBetweenButtons, self.setThumbnailBarButton, self.spaceBetweenButtons, self.deleteBarButton];

                // Present toolbar
                self.isToolbarRequired = YES;
                [self.navigationController setToolbarHidden:self.navigationController.isNavigationBarHidden animated:YES];
            }
            else if ([[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights])
            {
                // User with upload access to the current category can edit images
                [self.navigationItem setRightBarButtonItems:@[self.editBarButton]];
                self.toolbarItems = @[self.spaceBetweenButtons, self.downloadBarButton,  self.spaceBetweenButtons];

                // Present toolbar
                self.isToolbarRequired = YES;
                [self.navigationController setToolbarHidden:self.navigationController.isNavigationBarHidden animated:YES];
            }
            else
            {
            // User with no special access rights can only download images
            [self.navigationItem setRightBarButtonItems:@[self.downloadBarButton]];
            
            // Hide toolbar
            self.isToolbarRequired = NO;
            [self.navigationController setToolbarHidden:YES animated:NO];
            }
        }
    else    // iPhone in landscape mode, iPad in any orientation
    {
        // Hide toolbar
        self.isToolbarRequired = NO;
        [self.navigationController setToolbarHidden:YES animated:YES];

        if ([Model sharedInstance].hasAdminRights)
        {
            // User with admin rights can edit, delete images and set as album image
            [self.navigationItem setRightBarButtonItems:@[self.editBarButton, self.deleteBarButton, self.setThumbnailBarButton, self.downloadBarButton]];
        }
        else if ([[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights])
        {
            // User with upload access to the current category can edit images
            [self.navigationItem setRightBarButtonItems:@[self.editBarButton, self.downloadBarButton]];
        }
        else
        {
            // User with no special access rights can only download images
            [self.navigationItem setRightBarButtonItems:@[self.downloadBarButton]];
            
            // Hide toolbar
            [self.navigationController setToolbarHidden:YES animated:NO];
        }
    }
}

#pragma mark - User Interaction

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

-(void)didTapView
{
    // Should we do something else?
    if (self.imageData.isVideo) {
        // User wants to play/replay the video
        ImagePreviewViewController *playVideo = [ImagePreviewViewController new];
        [playVideo startVideoPlayerViewWithImageData:self.imageData];
    }
    else {
        // Display/hide the navigation bar
        BOOL isNavigationBarHidden = self.navigationController.isNavigationBarHidden;
        [self.navigationController setNavigationBarHidden:!isNavigationBarHidden animated:YES];
        
        // Display/hide the toolbar on iPhone if required
        if (self.isToolbarRequired)
            [self.navigationController setToolbarHidden:!isNavigationBarHidden animated:YES];
        
        // Set background color according to navigation bar visibility
        NSArray *viewControllers = self.childViewControllers;
        for (UIViewController *viewController in viewControllers) {
            if ([viewController isKindOfClass:[ImagePreviewViewController class]]) {
                if (self.navigationController.navigationBarHidden)
                    viewController.view.backgroundColor = [UIColor blackColor];
                else
                    viewController.view.backgroundColor = [UIColor piwigoBackgroundColor];
            }
        }
    }
}

-(void)didPinchView
{
    // Return to image collection (called by ImageScrollView)
    [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)prefersStatusBarHidden {
    if (self.navigationController.navigationBarHidden)
        return YES;     // Hide the status bar with the navigation bar
    else
        return NO;      // Show the status bar with the navigation bar
}


#pragma mark - UIPageViewControllerDataSource

-(UIViewController*)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    NSInteger currentIndex = [[[pageViewController viewControllers] firstObject] imageIndex];
    
    // Check to see if they've scroll beyond a certain threshold, then load more image data
    if(currentIndex >= self.images.count - 21 && self.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages])
    {
        if([self.imgDetailDelegate respondsToSelector:@selector(needToLoadMoreImages)])
        {
            [self.imgDetailDelegate needToLoadMoreImages];
        }
    }
    
    
    if(currentIndex >= self.images.count - 1)
    {
        return nil;
    }
    PiwigoImageData *imageData = [self.images objectAtIndex:currentIndex + 1];
    
    ImagePreviewViewController *nextImage = [ImagePreviewViewController new];
    [nextImage setImageScrollViewWithImageData:imageData];
    nextImage.imageIndex = currentIndex + 1;
    return nextImage;
}

-(UIViewController*)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    NSInteger currentIndex = [[[pageViewController viewControllers] firstObject] imageIndex];
    
    if(currentIndex <= 0)
    {
        // return nil;
        // Crash reported by AppStore here on May 25th, 2017
        // Should return 0 when the user reaches the first image of the album
        return 0;
    }
    
    PiwigoImageData *imageData = [self.images objectAtIndex:currentIndex - 1];
    
    ImagePreviewViewController *prevImage = [ImagePreviewViewController new];
    [prevImage setImageScrollViewWithImageData:imageData];
    prevImage.imageIndex = currentIndex - 1;
    return prevImage;
}

-(void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed
{
    ImagePreviewViewController *removedVC = [previousViewControllers firstObject];
    [removedVC.scrollView.imageView cancelImageDownloadTask];
    
    ImagePreviewViewController *view = [pageViewController.viewControllers firstObject];
    view.imagePreviewDelegate = self;
    
    self.progressBar.hidden = view.imageLoaded;
    [self.progressBar setProgress:0];
    
    NSInteger currentIndex = [[[pageViewController viewControllers] firstObject] imageIndex];
    
    if (currentIndex < 0)
    {
        // Crash reported by AppStore here on August 26th, 2017
        currentIndex = 0;
    }
    if (currentIndex >= self.images.count)
    {
        // Crash reported by AppleStore in November 2017
        currentIndex = self.images.count - 1;
    }
    
    self.imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andIndex:currentIndex];
    
    if(self.imageData.isVideo)
    {
        self.progressBar.hidden = YES;
    }
    
    self.imageData = [self.images objectAtIndex:currentIndex];
    
    self.title = self.imageData.name;
}


#pragma mark - Edit Image

-(void)editImage
{
    // Present EditImageDetails view
    UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageDetails" bundle:nil];
    EditImageDetailsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageDetails"];
    editImageVC.imageDetails = [[ImageUpload alloc] initWithImageData:self.imageData];
    editImageVC.delegate = self;
    editImageVC.isEdit = YES;
    
    UINavigationController *presentNav = [[UINavigationController alloc] initWithRootViewController:editImageVC];
    [self.navigationController presentViewController:presentNav animated:YES completion:nil];
}


#pragma mark - Delete Image

-(void)deleteImage
{
    UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:@""
            message:NSLocalizedString(@"deleteSingleImage_message", @"Are you sure you want to delete this image? This cannot be undone!")
            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
           actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
           style:UIAlertActionStyleCancel
           handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* deleteAction = [UIAlertAction
           actionWithTitle:NSLocalizedString(@"deleteSingleImage_title", @"Delete Image")
           style:UIAlertActionStyleDestructive
           handler:^(UIAlertAction * action) {
               [ImageService deleteImage:self.imageData
                        ListOnCompletion:^(NSURLSessionTask *task) {
                            // Successful deletion
                            if([self.imgDetailDelegate respondsToSelector:@selector(didDeleteImage:)])
                            {
                                [self.imgDetailDelegate didDeleteImage:self.imageData];
                            }
                            [self.navigationController popViewControllerAnimated:YES];
                            
                        } onFailure:^(NSURLSessionTask *task, NSError *error) {
                            // Error — Try again ?
                            UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed")
                                message:[NSString stringWithFormat:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted\n%@"), [error localizedDescription]]
                                preferredStyle:UIAlertControllerStyleAlert];
                            
                            UIAlertAction* dismissAction = [UIAlertAction
                                actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                style:UIAlertActionStyleCancel
                                handler:^(UIAlertAction * action) {}];
                            
                            UIAlertAction* retryAction = [UIAlertAction
                                actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                                style:UIAlertActionStyleDestructive
                                handler:^(UIAlertAction * action) {
                                    [self deleteImage];
                                }];
                            
                            [alert addAction:dismissAction];
                            [alert addAction:retryAction];
                            [self presentViewController:alert animated:YES completion:nil];
#if defined(DEBUG)
                            NSLog(@"Fail to delete!");
#endif
                        }];
           }];

    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:deleteAction];

    // Present list of actions
    alert.popoverPresentationController.barButtonItem = self.deleteBarButton;
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Download Image

-(void)downloadImage
{
    // Check autorisation to access Photo Library
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status != PHAuthorizationStatusAuthorized) {
        
        UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
            message:NSLocalizedString(@"localAlbums_photosNotAuthorized_msg", @"tell user to change settings, how")
            preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
            style:UIAlertActionStyleCancel
            handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Show loading HUD
    [self showHUDwithTitle:NSLocalizedString(@"downloadingImage", @"Downloading Image")];
    
    // Launch the download
    if(!self.imageData.isVideo)
	{
		[ImageService downloadImage:self.imageData
                         onProgress:^(NSProgress *progress) {
                             dispatch_async(dispatch_get_main_queue(),
                                    ^(void){
                                        [MBProgressHUD HUDForView:self.hudViewController.view].progress = progress.fractionCompleted;
                                    });
                         }
                  completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
                      // Any error ?
                      if (error.code) {
                          // Failed — Inform user
                          dispatch_async(dispatch_get_main_queue(),
                             ^(void){
                                 [self hideHUDwithSuccess:NO completion:^{
                                     UIAlertController* alert = [UIAlertController
                                    alertControllerWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
                                        message:[NSString stringWithFormat:NSLocalizedString(@"downloadImageFail_message", @"Failed to download image!\n%@"), [error localizedDescription]]
                                         preferredStyle:UIAlertControllerStyleAlert];
                                     
                                     UIAlertAction* defaultAction = [UIAlertAction
                                         actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                         style:UIAlertActionStyleCancel
                                         handler:^(UIAlertAction * action) {}];
                                     
                                     UIAlertAction* retryAction = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                                       style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction * action) {
                                           [self downloadImage];
                                       }];
                                     
                                     [alert addAction:defaultAction];
                                     [alert addAction:retryAction];
                                     [self presentViewController:alert animated:YES completion:nil];
                                 }];
                             });
                      }
                      else {
                          // Try to move photo in Photos.app
                          dispatch_async(dispatch_get_main_queue(),
                             ^(void){
                                 [self hideHUDwithSuccess:YES completion:^{
                                     [self saveImageToCameraRoll:filePath];
                                 }];
                             });
                      }
                  }
         ];
	}
	else
	{
        [ImageService downloadVideo:self.imageData
                         onProgress:^(NSProgress *progress) {
                             dispatch_async(dispatch_get_main_queue(),
                                ^(void){
                                    [MBProgressHUD HUDForView:self.hudViewController.view].progress = progress.fractionCompleted;}
                                );
                         }
                  completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {                      
                     // Any error ?
                      if (error.code) {
                          // Failed — Inform user
                          dispatch_async(dispatch_get_main_queue(),
                             ^(void){
                                 [self hideHUDwithSuccess:NO completion:^{
                                  UIAlertController* alert = [UIAlertController
                                      alertControllerWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
                                      message:[NSString stringWithFormat:NSLocalizedString(@"downloadVideoFail_message", @"Failed to download video!\n%@"), [error localizedDescription]]
                                      preferredStyle:UIAlertControllerStyleAlert];
                                  
                                  UIAlertAction* defaultAction = [UIAlertAction
                                          actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                          style:UIAlertActionStyleCancel
                                          handler:^(UIAlertAction * action) {}];
                              
                                  UIAlertAction* retryAction = [UIAlertAction
                                        actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                                        style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * action) {
                                            [self downloadImage];
                                        }];
                                  
                                  [alert addAction:defaultAction];
                                  [alert addAction:retryAction];
                                  [self presentViewController:alert animated:YES completion:nil];
                                 }];
                             });
                      } else {
                          // Try to move video in Photos.app
#if defined(DEBUG)
                          NSLog(@"path= %@", filePath.path);
#endif
                          dispatch_async(dispatch_get_main_queue(),
                             ^(void){
                              [self hideHUDwithSuccess:YES completion:^{
                                  if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(filePath.path)) {
                                      UISaveVideoAtPathToSavedPhotosAlbum(filePath.path, self, @selector(movie:didFinishSavingWithError:contextInfo:), nil);
                                  } else {
                                      // Failed — Inform user
                                      UIAlertController* alert = [UIAlertController
                                          alertControllerWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
                                          message:[NSString stringWithFormat:NSLocalizedString(@"downloadVideoFail_message", @"Failed to download video!\n%@"), NSLocalizedString(@"downloadVideoFail_Photos", @"Video format not accepted by Photos!")]
                                          preferredStyle:UIAlertControllerStyleAlert];
                                      
                                      UIAlertAction* defaultAction = [UIAlertAction
                                              actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                              style:UIAlertActionStyleCancel
                                              handler:^(UIAlertAction * action) {}];
                                      
                                      [alert addAction:defaultAction];
                                      [self presentViewController:alert animated:YES completion:nil];
                                    }
                                 }];
                             });
                      }
                  }
         ];
	}
}

-(void)saveImageToCameraRoll:(NSURL *)filePath
{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:filePath];
    } completionHandler:^(BOOL success, NSError *error) {
        if (!success) {
            // Failed — Inform user
            UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"imageSaveError_title", @"Fail Saving Image")
                message:[NSString stringWithFormat:NSLocalizedString(@"imageSaveError_message", @"Failed to save image. Error: %@"), [error localizedDescription]]
                preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction* defaultAction = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                style:UIAlertActionStyleCancel
                handler:^(UIAlertAction * action) {}];
            
            [alert addAction:defaultAction];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

-(void)movie:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
	if(error)
	{
        // Failed — Inform user
        UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"videoSaveError_title", @"Fail Saving Video")
                message:[NSString stringWithFormat:NSLocalizedString(@"videoSaveError_message", @"Failed to save video. Error: %@"), [error localizedDescription]]
                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                style:UIAlertActionStyleCancel
                handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
	}
}


#pragma mark - Move/Copy image to Category
-(void)addImageToCategory
{
    
}


#pragma mark - HUD methods

-(void)showHUDwithTitle:(NSString *)title
{
    // Determine the present view controller if needed (not necessarily self.view)
    if (!self.hudViewController) {
        self.hudViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (self.hudViewController.presentedViewController) {
            self.hudViewController = self.hudViewController.presentedViewController;
        }
    }
    
    // Create the loading HUD if needed
    MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
    if (!hud) {
        // Create the HUD
        hud = [MBProgressHUD showHUDAddedTo:self.hudViewController.view animated:YES];
        [hud setTag:loadingViewTag];
        
        // Change the background view shape, style and color.
        hud.mode = MBProgressHUDModeAnnularDeterminate;
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
                hud.label.text = NSLocalizedString(@"Complete", nil);
                [hud hideAnimated:YES afterDelay:2.f];
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
    MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
    if (hud) {
        [hud hideAnimated:YES];
        self.hudViewController = nil;
    }
}


#pragma mark - Set as Album Image

-(void)setAsAlbumImage
{
    // Hide the toolbar
    [self.navigationController setToolbarHidden:YES animated:YES];
    
    // Present CategoriesSelector view
    AllCategoriesViewController *allCategoriesPickVC = [[AllCategoriesViewController alloc] initForImageId:[self.imageData.imageId integerValue] andCategoryId:[[self.imageData.categoryIds firstObject] integerValue]];

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:allCategoriesPickVC];
    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    navController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navController animated:YES completion:nil];
}


#pragma mark - ImagePreviewDelegate Methods

-(void)downloadProgress:(CGFloat)progress
{
	[self.progressBar setProgress:progress animated:YES];
	if(progress == 1)
	{
		self.progressBar.hidden = YES;
	}
}

#pragma mark - EditImageDetailsDelegate Methods

-(void)didFinishEditingDetails:(ImageUpload *)details
{
    // Update list of images
    NSInteger index = 0;
    for(PiwigoImageData *image in self.images)
    {
        if([image.imageId integerValue] == details.imageId) {
            image.name = details.title;
            image.author = details.author;
            image.privacyLevel = details.privacyLevel;
            image.imageDescription = [NSString stringWithString:details.description];
            image.tags = [details.description copy];
            [self.images replaceObjectAtIndex:index withObject:image];
            break;
        }
        index++;
    }

    // Update previewed image
    self.imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:[NSString stringWithFormat:@"%ld", (long)details.imageId]];
    
    // Update current view
    self.title = details.title;
}

@end
