//
//  ImageDetailViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "ThumbnailCategoryViewController.h"
#import "AppDelegate.h"
#import "CategoriesData.h"
#import "EditImageParamsViewController.h"
#import "ImageDetailViewController.h"
#import "ImagePreviewViewController.h"
#import "ImageService.h"
#import "ImageScrollView.h"
#import "ImagesCollection.h"
#import "Model.h"
#import "MoveImageViewController.h"
#import "MBProgressHUD.h"
#import "SAMKeychain.h"

NSString * const kPiwigoNotificationPinchedImage = @"kPiwigoNotificationPinchedImage";
NSString * const kPiwigoNotificationUpdateImageFileName = @"kPiwigoNotificationUpdateImageFileName";

@interface ImageDetailViewController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, ImagePreviewDelegate, EditImageParamsDelegate, SetAlbumImageDelegate, MoveImageDelegate, ShareImageActivityItemProviderDelegate, UIToolbarDelegate>

@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, strong) PiwigoImageData *imageData;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) NSLayoutConstraint *topProgressBarConstraint;
@property (nonatomic, strong) UIViewController *hudViewController;

@property (nonatomic, strong) UIBarButtonItem *editBarButton;
@property (nonatomic, strong) UIBarButtonItem *deleteBarButton;
@property (nonatomic, strong) UIBarButtonItem *shareBarButton;
@property (nonatomic, strong) UIBarButtonItem *setThumbnailBarButton;
@property (nonatomic, strong) UIBarButtonItem *moveBarButton;
//@property (nonatomic, strong) UIBarButtonItem *favoriteBarButton;
@property (nonatomic, strong) UIBarButtonItem *spaceBetweenButtons;
@property (nonatomic, assign) BOOL isToolbarRequired;

@end

//#ifndef DEBUG_SHARE
//#define DEBUG_SHARE
//#endif

@implementation ImageDetailViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId atImageIndex:(NSInteger)imageIndex withArray:(NSArray *)arrayOfImages
{
	self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
	if(self)
	{
		// Current category and images data
        self.categoryId = categoryId;
		self.images = [arrayOfImages mutableCopy];
		
		self.dataSource = self;
		self.delegate = self;
		
        // Progress bar
		self.progressBar = [UIProgressView new];
		self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
        [self.progressBar setProgress:0.0 animated:NO];
		self.progressBar.hidden = NO;
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
        [self.editBarButton setAccessibilityIdentifier:@"edit"];
        self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteImage)];
        self.deleteBarButton.tintColor = [UIColor redColor];
        [self.deleteBarButton setAccessibilityIdentifier:@"delete"];
        self.shareBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareImage)];
        self.shareBarButton.tintColor = [UIColor piwigoColorOrange];
        [self.shareBarButton setAccessibilityIdentifier:@"share"];
        if (@available(iOS 13.0, *)) {
            self.setThumbnailBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"rectangle.and.paperclip"] style:UIBarButtonItemStylePlain target:self action:@selector(setAsAlbumImage)];
        } else {
            // Fallback on earlier versions
            self.setThumbnailBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imagePaperclip"] landscapeImagePhone:[UIImage imageNamed:@"imagePaperclipCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(setAsAlbumImage)];
        }
        self.setThumbnailBarButton.tintColor = [UIColor piwigoColorOrange];
        [self.setThumbnailBarButton setAccessibilityIdentifier:@"albumThumbnail"];
        self.moveBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemReply target:self action:@selector(addImageToCategory)];
        self.moveBarButton.tintColor = [UIColor piwigoColorOrange];
        [self.moveBarButton setAccessibilityIdentifier:@"move"];
//        self.favoriteBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageNotFavorite"] landscapeImagePhone:[UIImage imageNamed:@"imageNotFavoriteCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(addImageToFavorites)];
//        self.favoriteBarButton.tintColor = [UIColor piwigoColorOrange];
//        [self.favoriteBarButton setAccessibilityIdentifier:@"favorite"];
        self.spaceBetweenButtons = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];

        // Current image
        self.imageData = [self.images objectAtIndex:imageIndex];
        [self setTitleViewFromImageData];

        // Image preview view controller
        ImagePreviewViewController *startingImage = [ImagePreviewViewController new];
        startingImage.imagePreviewDelegate = self;
        startingImage.imageIndex = imageIndex;
        [startingImage setImageScrollViewWithImageData:self.imageData];
        [self setViewControllers:@[startingImage]
                       direction:UIPageViewControllerNavigationDirectionForward
                        animated:NO
                      completion:nil];
        
        // Retrieve complete image data if needed (buttons are greyed until job done)
        if (self.imageData.fileSize == NSNotFound) {
            [self retrieveCompleteImageDataOfImage:self.imageData];
        }
        
        // For managing taps
		[self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapView)]];

        // Register image pinches
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didPinchView) name:kPiwigoNotificationPinchedImage object:nil];

        // Register image data updates
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateImageFileName:) name:kPiwigoNotificationUpdateImageFileName object:nil];

        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoNotificationPaletteChanged object:nil];
	}
	return self;
}


#pragma mark - View Lifecycle

-(void)applyColorPalette
{
    // Navigation bar
    [self setTitleViewFromImageData];
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
    
    // Toolbar
    self.navigationController.toolbar.barTintColor = [UIColor piwigoColorBackground];
    self.navigationController.toolbar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;

    // Progress bar
    self.progressBar.progressTintColor = [UIColor piwigoColorOrange];
    self.progressBar.trackTintColor = [UIColor piwigoColorLeftLabel];
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
    // Always open this view with a navigation bar
    // and never present video poster in full screen
    [self.navigationController setNavigationBarHidden:NO animated:YES];

    // Image options buttons
    [self updateNavBar];
    
    // Set colors, fonts, etc.
    [self applyColorPalette];

    // Scrolling
	if([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)])
	{
		self.automaticallyAdjustsScrollViewInsets = false;
		self.edgesForExtendedLayout = UIRectEdgeNone;
	}
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self updateNavBar];
        [self setTitleViewFromImageData];
    } completion:nil];
}

-(void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    // Should we update user interface based on the appearance?
    if (@available(iOS 13.0, *)) {
        BOOL hasUserInterfaceStyleChanged = (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle);
        if (hasUserInterfaceStyleChanged) {
            [Model sharedInstance].isSystemDarkModeActive = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate screenBrightnessChanged];
        }

    } else {
        // Fallback on earlier versions
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Scroll previewed image to visible area
    if([self.imgDetailDelegate respondsToSelector:@selector(didFinishPreviewOfImageWithId:)])
    {
        [self.imgDetailDelegate didFinishPreviewOfImageWithId:self.imageData.imageId];
    }
}

-(void)updateNavBar
{
    // Redefine bar buttons (definition lost after rotation of device)
    self.editBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editImage)];
    [self.editBarButton setAccessibilityIdentifier:@"edit"];
    self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteImage)];
    self.deleteBarButton.tintColor = [UIColor redColor];
    [self.deleteBarButton setAccessibilityIdentifier:@"delete"];
    self.shareBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareImage)];
    self.shareBarButton.tintColor = [UIColor piwigoColorOrange];
    [self.shareBarButton setAccessibilityIdentifier:@"share"];
    if (@available(iOS 13.0, *)) {
        self.setThumbnailBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"rectangle.and.paperclip"] style:UIBarButtonItemStylePlain target:self action:@selector(setAsAlbumImage)];
    } else {
        // Fallback on earlier versions
        self.setThumbnailBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imagePaperclip"] landscapeImagePhone:[UIImage imageNamed:@"imagePaperclipCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(setAsAlbumImage)];
    }
    self.setThumbnailBarButton.tintColor = [UIColor piwigoColorOrange];
    [self.setThumbnailBarButton setAccessibilityIdentifier:@"albumThumbnail"];
    self.moveBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemReply target:self action:@selector(addImageToCategory)];
    self.moveBarButton.tintColor = [UIColor piwigoColorOrange];
    [self.moveBarButton setAccessibilityIdentifier:@"move"];
//        self.favoriteBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageNotFavorite"] landscapeImagePhone:[UIImage imageNamed:@"imageNotFavoriteCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(addImageToFavorites)];
//        self.favoriteBarButton.tintColor = [UIColor piwigoColorOrange];
//        [self.favoriteBarButton setAccessibilityIdentifier:@"favorite"];

    // Interface depends on device and orientation
    if (([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) ||
        ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad &&
         [[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeLeft &&
         [[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeRight)) {
            
        // iPhone or iPad in portrait mode
        if ([Model sharedInstance].hasAdminRights)
        {
            // User with admin rights can move, edit, delete images and set as album image
            [self.navigationItem setRightBarButtonItems:@[self.editBarButton]];
//            if ([@"2.10.0" compare:[Model sharedInstance].version options:NSNumericSearch] == NSOrderedDescending) {
                self.toolbarItems = @[self.shareBarButton, self.spaceBetweenButtons, self.moveBarButton, self.spaceBetweenButtons, self.setThumbnailBarButton, self.spaceBetweenButtons, self.deleteBarButton];
//            } else {
//                self.toolbarItems = @[self.shareBarButton, self.spaceBetweenButtons, self.moveBarButton, self.spaceBetweenButtons, self.favoriteBarButton, self.spaceBetweenButtons, self.setThumbnailBarButton, self.spaceBetweenButtons, self.deleteBarButton];
//            }
            
            // Present toolbar if needed
            self.isToolbarRequired = YES;
            BOOL isNavigationBarHidden = self.navigationController.isNavigationBarHidden;
            [self.navigationController setToolbarHidden:isNavigationBarHidden animated:YES];
        }
        else if ([Model sharedInstance].hasNormalRights && [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights])
        {
            // WRONG =====> 'normal' user with upload access to the current category can edit images
            // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by' values of images for checking rights
            [self.navigationItem setRightBarButtonItems:@[self.editBarButton]];
            self.toolbarItems = @[self.shareBarButton, self.spaceBetweenButtons, self.moveBarButton];

            // Present toolbar if needed
            self.isToolbarRequired = YES;
            BOOL isNavigationBarHidden = self.navigationController.isNavigationBarHidden;
            [self.navigationController setToolbarHidden:isNavigationBarHidden animated:YES];
        }
        else
        {
            // User with no special access rights can only download images
            [self.navigationItem setRightBarButtonItems:@[self.shareBarButton]];
            
            // Hide toolbar
            self.isToolbarRequired = NO;
            [self.navigationController setToolbarHidden:YES animated:NO];
        }
    }
    else    // iPad in landscape mode
    {
        // iPad in landcsape mode: buttons in navigation bar -> Hide toolbar
        self.isToolbarRequired = NO;
        [self.navigationController setToolbarHidden:YES animated:YES];

        if ([Model sharedInstance].hasAdminRights)
        {
            // User with admin rights can edit, delete images and set as album image
            self.deleteBarButton.tintColor = [UIColor redColor];
            [self.navigationItem setRightBarButtonItems:@[self.editBarButton, self.deleteBarButton, self.setThumbnailBarButton, self.moveBarButton, self.shareBarButton]];
        }
        else if ([[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights])
        {
            // User with upload access to the current category can edit images
            [self.navigationItem setRightBarButtonItems:@[self.editBarButton, self.moveBarButton, self.shareBarButton]];
        }
        else
        {
            // User with no special access rights can only download images
            [self.navigationItem setRightBarButtonItems:@[self.shareBarButton]];
        }
    }
}

// Buttons are disabled (greyed) when retrieving image data
// They are also disabled during an action
-(void)setEnableStateOfButtons:(BOOL)state
{
    self.editBarButton.enabled = state;
    self.shareBarButton.enabled = state;
    self.moveBarButton.enabled = state;
    self.setThumbnailBarButton.enabled = state;
    self.deleteBarButton.enabled = state;
//    self.favoriteBarButton.enabled = state;
}


#pragma mark - Image Data Updates

-(void)updateImageFileName:(NSNotification *)notification
{
    // Extract notification user info
    if (notification != nil) {
        NSDictionary *userInfo = notification.object;

        // Right image Id?
        NSInteger imageId = [[userInfo objectForKey:@"imageId"] integerValue];
        if (imageId != self.imageData.imageId) return;
        
        // Update image data
        NSString *fileName = [userInfo objectForKey:@"fileName"];
        if (fileName) self.imageData.fileName = fileName;
        
        // Update title view
        [self setTitleViewFromImageData];
    }
}


#pragma mark - Retrieve Image Data

-(void)retrieveCompleteImageDataOfImage:(PiwigoImageData *)imageData
{
//    NSLog(@"=> Retrieve complete image data for image #%ld", (long)imageData.imageId);

    // Image data is not complete when retrieved using pwg.categories.getImages
    [self setEnableStateOfButtons:NO];
    
    // Image data is not complete after an upload with pwg.images.upload
    BOOL shouldUpdateImage = [imageData getURLFromImageSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultImagePreviewSize] == nil;

    // Required by Copy, Delete, Move actions (may also be used to show albums image belongs to)
    [ImageService getImageInfoById:imageData.imageId
                      OnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageDataComplete) {
              if (imageDataComplete != nil) {

                  // Update list of images
                  self.imageData = imageDataComplete;
                  NSInteger index = [self.images indexOfObjectPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                      return obj.imageId == imageDataComplete.imageId;
                  }];
                  [self.images replaceObjectAtIndex:index withObject:imageDataComplete];

                  // Enable actions
                  [self setEnableStateOfButtons:YES];
                  
                  // Retrieve complete image data if needed
                  if (shouldUpdateImage) {
                      NSArray *viewControllers = self.childViewControllers;
                      for (UIViewController *childVC in viewControllers)
                      {
                          if ([childVC isKindOfClass:[ImagePreviewViewController class]]) {
                              // Right class ;-)
                              ImagePreviewViewController *previewVC = (ImagePreviewViewController *)childVC;
                              if (previewVC.imageIndex == index) {
                                  [previewVC setImageScrollViewWithImageData:imageDataComplete];
                              }
                          }
                      }
                  }
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
        }];
    
    UIAlertAction* retryAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
          [self retrieveCompleteImageDataOfImage:self.imageData];
        }];
    
    [alert addAction:dismissAction];
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
                    viewController.view.backgroundColor = [UIColor piwigoColorBackground];
            }
        }
    }
}

// Display/hide status bar
-(BOOL)prefersStatusBarHidden{
    return self.navigationController.isNavigationBarHidden;
}

-(void)didPinchView
{
    // Return to image collection (called by ImageScrollView)
    [self.navigationController popViewControllerAnimated:YES];
}


#pragma mark - UIPageViewControllerDataSource

// Returns the view controller after the given view controller
-(UIViewController*)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    NSInteger currentIndex = [[[pageViewController viewControllers] firstObject] imageIndex];
    
    // Reached the end of the category?
    if (currentIndex >= (self.images.count - 1))
    {
        return nil;
    }
    
    // Check to see if they've scrolled beyond a certain threshold, then load more image data
//    if ((currentIndex >= self.images.count - 21) && (self.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages]))
//    {
//        if([self.imgDetailDelegate respondsToSelector:@selector(needToLoadMoreImages)])
//        {
//            [self.imgDetailDelegate needToLoadMoreImages];
//        }
//    }
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:self.view imagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
    if ((currentIndex > (self.images.count - roundf(imagesPerPage / 3.0))) &&
        (self.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages]))
    {
        if([self.imgDetailDelegate respondsToSelector:@selector(needToLoadMoreImages)])
        {
            [self.imgDetailDelegate needToLoadMoreImages];
        }
    }

    // Does the needed image preview controller already exist?
//    for (UIViewController *viewController in [pageViewController viewControllers]) {
//        // Only consider view controllers of the right class!
//        if ([viewController isKindOfClass:[ImagePreviewViewController class]]) {
//            ImagePreviewViewController *imageViewCtrl = (ImagePreviewViewController *)viewController;
//            // Return if exists
//            if (imageViewCtrl.imageIndex == currentIndex + 1) {
//                NSLog(@"=> Preview view controller for next image already exists");
//                return imageViewCtrl;
//            }
//        }
//    }
    
    // Retrieve data of next image (may be incomplete)
    PiwigoImageData *imageData = [self.images objectAtIndex:currentIndex + 1];

    // Create view controller for presenting next image
//    NSLog(@"=> Create preview view controller for next image %@", imageData.imageId);
    ImagePreviewViewController *nextImage = [ImagePreviewViewController new];
    nextImage.imageLoaded = NO;
    nextImage.imageIndex = currentIndex + 1;
    [nextImage setImageScrollViewWithImageData:imageData];
    return nextImage;
}

// Returns the view controller before the given view controller
-(UIViewController*)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    NSInteger currentIndex = [[[pageViewController viewControllers] firstObject] imageIndex];
    
    // Reached the beginning of the category?
    if ((currentIndex - 1 < 0) || (currentIndex - 1 >= self.images.count))
    {
        // Crash reported by AppStore here on May 25th, 2017!
        // Should return nil when the user reaches the first image of the album
        return nil;
    }
    
    // Does the needed image preview controller already exist?
//    for (UIViewController *viewController in [pageViewController viewControllers]) {
//        // Only consider view controllers of the right class!
//        if ([viewController isKindOfClass:[ImagePreviewViewController class]]) {
//            ImagePreviewViewController *imageViewCtrl = (ImagePreviewViewController *)viewController;
//            // Return if exists
//            if (imageViewCtrl.imageIndex == currentIndex - 1) {
//                NSLog(@"=> Preview view controller for previous image already exists");
//                return imageViewCtrl;
//            }
//        }
//    }

    // Retrieve data of previous image (may be incomplete)
    PiwigoImageData *imageData = [self.images objectAtIndex:(currentIndex - 1)];
    
    // Create view controller
//    NSLog(@"=> Create preview view controller for previous image %@", imageData.imageId);
    ImagePreviewViewController *prevImage = [ImagePreviewViewController new];
    prevImage.imageLoaded = NO;
    prevImage.imageIndex = currentIndex - 1;
    [prevImage setImageScrollViewWithImageData:imageData];
    return prevImage;
}

// Called before a gesture-driven transition begins
- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray<UIViewController *> *)pendingViewControllers
{
    // Stop downloading image if needed
//    ImagePreviewViewController *removedVC = [pageViewController.viewControllers firstObject];
//    if (removedVC.downloadTask.state == 0) {                        // Task active?
//        [removedVC.scrollView.imageView cancelImageDownloadTask];   // Cancel thumbnail download
//        [removedVC.downloadTask cancel];                            // Cancel image file download
//    }
    
    // Retrieve complete image data if needed
    for (UIViewController *pendingVC in pendingViewControllers)
    {
        if ([pendingVC isKindOfClass:[ImagePreviewViewController class]]) {
            // Right class ;-)
            ImagePreviewViewController *previewVC = (ImagePreviewViewController *)pendingVC;
            
            // Retrieve image data in case user will want to copy, edit, move, etc. the image
            if (previewVC.imageIndex < self.images.count) {
                PiwigoImageData *imageData = [self.images objectAtIndex:previewVC.imageIndex];
                if (imageData.fileSize == NSNotFound) {
                    [self retrieveCompleteImageDataOfImage:imageData];
                }
            }
        }
    }
}

// Called after a gesture-driven transition completes
-(void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed
{
    ImagePreviewViewController *view = [pageViewController.viewControllers firstObject];
    view.imagePreviewDelegate = self;
    self.progressBar.hidden = view.imageLoaded;
    
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

    // Retrieve image data in case user will want to copy, edit, move, etc. the image
//    PiwigoImageData *imageData = [self.images objectAtIndex:currentIndex];
//    if (self.imageData.fileSize == NSNotFound) {
//        [self retrieveCompleteImageDataOfImage:imageData];
//    }

    self.imageData = [self.images objectAtIndex:currentIndex];
    [self setTitleViewFromImageData];
    if(self.imageData.isVideo)
    {
        self.progressBar.hidden = YES;
    }
}

-(NSInteger)indexOfSelectedImage
{
    NSInteger index = 0;
    for (UIViewController *viewController in self.viewControllers) {
        // Look for view controller of the right class!
        if ([viewController isKindOfClass:[ImagePreviewViewController class]]) {
            ImagePreviewViewController *imageViewCtrl = (ImagePreviewViewController *)viewController;
            // Return if exists
            index = imageViewCtrl.imageIndex;
            break;
        }
    }
    return index;
}

#pragma mark - Edit Image

-(void)editImage
{
    // Disable buttons during action
    [self setEnableStateOfButtons:NO];

    // Present EditImageDetails view
    UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageParams" bundle:nil];
    EditImageParamsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageParams"];
    editImageVC.images = @[self.imageData];
    editImageVC.delegate = self;
    [self pushView:editImageVC];
}


#pragma mark - Delete Image

-(void)deleteImage
{
    // Disable buttons during action
    [self setEnableStateOfButtons:NO];

    UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:@""
            message:NSLocalizedString(@"deleteSingleImage_message", @"Are you sure you want to delete this image? This cannot be undone!")
            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
           actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
           style:UIAlertActionStyleCancel
           handler:^(UIAlertAction * action) {
                // Re-enable buttons
                [self setEnableStateOfButtons:YES];
    }];
    
    UIAlertAction *removeAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"removeSingleImage_title", @"Remove from Album")
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
                [self removeImageFromCategory];
            }];

    UIAlertAction* deleteAction = [UIAlertAction
           actionWithTitle:NSLocalizedString(@"deleteSingleImage_title", @"Delete Image")
           style:UIAlertActionStyleDestructive
           handler:^(UIAlertAction * action) {
               [self deleteImageFromDatabase];
           }];

    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:deleteAction];
    if (([self.imageData.categoryIds count] > 1) && (self.categoryId > 0)) {
        // This image is used in another album
        // Proposes to remove it from the current album, unless it was selected from a smart album
        [alert addAction:removeAction];
    }

    // Present list of actions
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.barButtonItem = self.deleteBarButton;
    [self presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}

-(void)removeImageFromCategory
{
    // Display HUD during deletion
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"removeSingleImageHUD_removing", @"Removing Image…") withProgress:NO];
    });
    
    // Update image category list
    NSMutableArray *categoryIds = [self.imageData.categoryIds mutableCopy];
    [categoryIds removeObject:@(self.categoryId)];
    
    // Send request to Piwigo server
    [ImageService setCategoriesForImage:self.imageData
         withCategories:categoryIds
             onProgress:nil
           OnCompletion:^(NSURLSessionTask *task, BOOL updatedSuccessfully) {
               
                if (updatedSuccessfully)
                {
                    // Update image data
                    self.imageData.categoryIds = categoryIds;

                    // Remove image from cache and update UI
                    [[CategoriesData sharedInstance] removeImage:self.imageData fromCategory:[NSString stringWithFormat:@"%ld", (long)self.categoryId]];

                    // Notify the Upload database that this image has been removed from this category
                    if (categoryIds.count > 0) {
                        NSDictionary *userInfo = @{@"albumId" : @([categoryIds[0] longValue]),
                                                   @"imageId" : @(self.imageData.imageId)};
                        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationMovedImage object:nil userInfo:userInfo];
                    }

                    // Hide HUD
                    [self hideHUDwithSuccess:YES completion:^{
                        self.hudViewController = nil;
                    }];

                    // Return to album view
                    NSInteger index = 0;
                    for (UIViewController *viewController in self.viewControllers) {
                        // Look for view controller of the right class!
                        if ([viewController isKindOfClass:[ImagePreviewViewController class]]) {
                            ImagePreviewViewController *imageViewCtrl = (ImagePreviewViewController *)viewController;
                            // Return if exists
                            index = imageViewCtrl.imageIndex;
                            break;
                        }
                    }
                    [self didRemoveImage:self.imageData atIndex:index];
               }
               else {
                    [self hideHUDwithSuccess:NO completion:^{
                       self.hudViewController = nil;
                       [self showDeleteImageErrorWithMessage:NSLocalizedString(@"alertTryAgainButton", @"Try Again")];
                    }];
               }
           }
              onFailure:^(NSURLSessionTask *task, NSError *error) {
                  [self hideHUDwithSuccess:NO completion:^{
                      self.hudViewController = nil;
                      [self showDeleteImageErrorWithMessage:[error localizedDescription]];
                  }];
              }];
}

-(void)deleteImageFromDatabase
{
    // Display HUD during deletion
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"deleteSingleImageHUD_deleting", @"Deleting Image…") withProgress:NO];
    });
    
    // Send request to Piwigo server
    [ImageService deleteImage:self.imageData
             ListOnCompletion:^(NSURLSessionTask *task) {
                 
                 // Hide HUD
                 [self hideHUDwithSuccess:YES completion:^{
                     self.hudViewController = nil;
                 }];

                 // Return to album view
                 [self didRemoveImage:self.imageData atIndex:[self indexOfSelectedImage]];
             }
                    onFailure:^(NSURLSessionTask *task, NSError *error) {
                 [self hideHUDwithSuccess:NO completion:^{
                     self.hudViewController = nil;
                     [self showDeleteImageErrorWithMessage:[error localizedDescription]];
                 }];
             }];
}

-(void)showDeleteImageErrorWithMessage:(NSString*)message
{
    NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted\n%@"), message];
    
    UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed")
            message:errorMessage
            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* dismissAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
            style:UIAlertActionStyleCancel
            handler:^(UIAlertAction * action) {
                // Re-enable buttons
                [self setEnableStateOfButtons:YES];
    }];
    
    [alert addAction:dismissAction];
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


#pragma mark - Share Image

-(void)shareImage
{
    // Disable buttons during action
    [self setEnableStateOfButtons:NO];

    // Check autorisation to access Photo Library (camera roll)
    // Check autorisation to access Photo Library (camera roll)
    if (@available(iOS 14, *)) {
        [[PhotosFetch sharedInstance] checkPhotoLibraryAuthorizationStatusFor:PHAccessLevelAddOnly for:self
            onAccess:^{
            // User allowed to save image in camera roll
            [self presentShareImageViewControllerWithCameraRollAccess:YES];
        } onDeniedAccess:^{
            // User not allowed to save image in camera roll
            if ([NSThread isMainThread]) {
                [self presentShareImageViewControllerWithCameraRollAccess:NO];
            }
            else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self presentShareImageViewControllerWithCameraRollAccess:NO];
                });
            }
        }];
    } else {
        // Fallback on earlier versions
        [[PhotosFetch sharedInstance] checkPhotoLibraryAccessForViewController:nil
            onAuthorizedAccess:^{
                // User allowed to save image in camera roll
                [self presentShareImageViewControllerWithCameraRollAccess:YES];
            }
                onDeniedAccess:^{
                    // User not allowed to save image in camera roll
                    if ([NSThread isMainThread]) {
                        [self presentShareImageViewControllerWithCameraRollAccess:NO];
                    }
                    else{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self presentShareImageViewControllerWithCameraRollAccess:NO];
                        });
                    }
            }];
    }
}

-(void)presentShareImageViewControllerWithCameraRollAccess:(BOOL)hasCameraRollAccess
{
    // To exclude some activity types
    NSMutableSet *excludedActivityTypes = [NSMutableSet new];

    // Create new activity provider item to pass to the activity view controller
    NSMutableArray *itemsToShare = [NSMutableArray new];
    if (self.imageData.isVideo) {
        // Case of a video
        ShareVideoActivityItemProvider *videoItemProvider = [[ShareVideoActivityItemProvider alloc] initWithPlaceholderImage:self.imageData];

        // Use delegation to monitor the progress of the item method
        videoItemProvider.delegate = self;
        
        // Add to list of items to share
        [itemsToShare addObject:videoItemProvider];

        // Exclude "assign to contact" activity
        [excludedActivityTypes addObject:UIActivityTypeAssignToContact];
    }
    else {
        // Case of an image
        ShareImageActivityItemProvider *imageItemProvider = [[ShareImageActivityItemProvider alloc]  initWithPlaceholderImage:self.imageData];

        // Use delegation to monitor the progress of the item method
        imageItemProvider.delegate = self;

        // Add to list of items to share
        [itemsToShare addObject:imageItemProvider];
    }
    
    // Create an activity view controller with the activity provider item.
    // ShareImageActivityItemProvider's superclass conforms to the UIActivityItemSource protocol
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];

    // Set HUD view controller for displaying progress
    self.hudViewController = activityViewController;
    
    // Exclude some activity types if needed
    if (!hasCameraRollAccess) {
        // Exclude "camera roll" activity when the Photo Library is not accessible
        [excludedActivityTypes addObject:UIActivityTypeSaveToCameraRoll];
    }
    activityViewController.excludedActivityTypes = [excludedActivityTypes allObjects];
    
    // Delete image/video file and remove observers after dismissing activity view controller
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError){
//        NSLog(@"Activity Type selected: %@", activityType);

        // Enable buttons after action
        [self setEnableStateOfButtons:YES];

        if (completed) {
//            NSLog(@"Selected activity was performed and returned error:%ld", (long)activityError.code);
            if (self.imageData.isVideo) {
                // Remove observers
                [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareVideo object:nil];
            }
            else {
                // Remove observers
                [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareImage object:nil];
            }
        } else {
            if (activityType == NULL) {
//                NSLog(@"User dismissed the view controller without making a selection.");
            } else {
                NSLog(@"Activity was not performed.");
                if (self.imageData.isVideo)
                {
                    // Cancel download task
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelDownloadVideo object:nil];
                    
                    // Remove observers
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareVideo object:nil];
                }
                else {
                    // Cancel download task
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelDownloadImage object:nil];
                    
                    // Remove observers
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareImage object:nil];
                }
            }
        }
    }];
    
    // Present share image activity view controller
    activityViewController.popoverPresentationController.barButtonItem = self.shareBarButton;
    [self presentViewController:activityViewController animated:YES completion:nil];
}

-(void)cancelShareImage
{
    if (self.imageData.isVideo) {
        // Cancel video file donwload
        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelDownloadVideo object:nil];
    }
    else {
        // Cancel image file download
        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelDownloadImage object:nil];
    }
}

#pragma mark - Set as Album Image

-(void)setAsAlbumImage
{
    // Disable buttons during action
    [self setEnableStateOfButtons:NO];

    // Present AllCategories view
    ThumbnailCategoryViewController *allCategoriesPickVC = [[ThumbnailCategoryViewController alloc] initForImage:self.imageData andCategoryId:[[self.imageData.categoryIds firstObject] integerValue]];
    allCategoriesPickVC.setAlbumImageDelegate = self;
    [self pushView:allCategoriesPickVC];
}


#pragma mark - Move/Copy image to Category

-(void)addImageToCategory
{
    // Disable buttons during action
    [self setEnableStateOfButtons:NO];

    // If image selected from Search, immediatley propose to copy it
    if (self.categoryId == kPiwigoSearchCategoryId) {
        MoveImageViewController *moveImageVC = [[MoveImageViewController alloc] initWithSelectedImageIds:nil orSingleImageData:self.imageData inCategoryId:self.categoryId atIndex:[self indexOfSelectedImage] andCopyOption:YES];
        moveImageVC.moveImageDelegate = self;
        [self pushView:moveImageVC];
        return;
    }
    
    // Image selected from album collection
    UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:nil message:nil
            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
            style:UIAlertActionStyleCancel
            handler:^(UIAlertAction * action) {
                // Re-enable buttons
                [self setEnableStateOfButtons:YES];
    }];
    
    UIAlertAction* copyAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"copyImage_title", @"Copy to Album")
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction * action) {
                MoveImageViewController *moveImageVC = [[MoveImageViewController alloc] initWithSelectedImageIds:nil orSingleImageData:self.imageData inCategoryId:self.categoryId atIndex:[self indexOfSelectedImage] andCopyOption:YES];
                moveImageVC.moveImageDelegate = self;
                [self pushView:moveImageVC];
            }];

    UIAlertAction* moveAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"moveImage_title", @"Move to Album")
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction * action) {
                MoveImageViewController *moveImageVC = [[MoveImageViewController alloc] initWithSelectedImageIds:nil orSingleImageData:self.imageData inCategoryId:self.categoryId atIndex:[self indexOfSelectedImage] andCopyOption:NO];
                moveImageVC.moveImageDelegate = self;
                [self pushView:moveImageVC];
            }];

    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:copyAction];
    [alert addAction:moveAction];

    // Present list of actions
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.barButtonItem = self.moveBarButton;
    [self presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}


#pragma mark - Add to / remove from favorites

-(void)addImageToFavorites
{
    // Disable buttons during action
    [self setEnableStateOfButtons:NO];

    // Send request to Piwigo server
    [ImageService addImageToFavorites:self.imageData
                           onProgress:nil
                         OnCompletion:^(NSURLSessionTask *task, BOOL addedSuccessfully) {
        
                            // Enable buttons during action
                            [self setEnableStateOfButtons:YES];

                        } onFailure:^(NSURLSessionTask *task, NSError *error) {
                                
                            // Enable buttons during action
                            [self setEnableStateOfButtons:YES];
                        }];
}

-(void)removeImageFromFavorites
{
    // Disable buttons during action
    [self setEnableStateOfButtons:NO];

    // Send request to Piwigo server
    [ImageService removeImageFromFavorites:self.imageData
                                onProgress:nil
                              OnCompletion:^(NSURLSessionTask *task, BOOL removedSuccessfully) {
        
                                // Enable buttons during action
                                [self setEnableStateOfButtons:YES];

                            } onFailure:^(NSURLSessionTask *task, NSError *error) {
                                    
                                // Enable buttons during action
                                [self setEnableStateOfButtons:YES];
                            }];
}


#pragma mark - push view
-(void)pushView:(UIViewController *)viewController
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        
        if ([viewController isKindOfClass:[ThumbnailCategoryViewController class]])
        {
            viewController.modalPresentationStyle = UIModalPresentationPopover;
            viewController.popoverPresentationController.sourceView = self.view;
            viewController.popoverPresentationController.barButtonItem = self.setThumbnailBarButton;
            [self.navigationController presentViewController:viewController animated:YES completion:nil];
       }
        else if ([viewController isKindOfClass:[MoveImageViewController class]])
        {
            viewController.modalPresentationStyle = UIModalPresentationPopover;
            viewController.popoverPresentationController.sourceView = self.view;
            viewController.popoverPresentationController.barButtonItem = self.moveBarButton;
            [self.navigationController presentViewController:viewController animated:YES completion:nil];
        }
        else if ([viewController isKindOfClass:[EditImageParamsViewController class]])
        {
            // Push Edit view embedded in navigation controller
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
            navController.modalPresentationStyle = UIModalPresentationPopover;
            navController.popoverPresentationController.sourceView = self.view;
            navController.popoverPresentationController.barButtonItem = self.editBarButton;
            [self.navigationController presentViewController:navController animated:YES completion:nil];
        }
    }
    else {
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
        navController.modalPresentationStyle = UIModalPresentationPopover;
        navController.popoverPresentationController.sourceView = self.view;
        navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        navController.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:navController animated:YES completion:nil];
    }
}


#pragma mark - HUD methods

-(void)showHUDwithTitle:(NSString *)title withProgress:(BOOL)showProgress
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
        hud.mode = showProgress ? MBProgressHUDModeAnnularDeterminate : MBProgressHUDModeIndeterminate;
        hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
        hud.contentColor = [UIColor piwigoColorText];
        hud.bezelView.color = [UIColor piwigoColorText];
        hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.bezelView.backgroundColor = [UIColor piwigoColorCellBackground];

        // Will look best, if we set a minimum size.
        hud.minSize = CGSizeMake(200.f, 100.f);
        
        // Configure the button if managed progress
        if (showProgress) {
            [hud.button setTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                        forState:UIControlStateNormal];
            [hud.button addTarget:self action:@selector(cancelShareImage) forControlEvents:UIControlEventTouchUpInside];
        }
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
            } else {
                UIImage *image = [[UIImage imageNamed:@"warning"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                hud.customView = imageView;
                hud.mode = MBProgressHUDModeCustomView;
                hud.label.text = NSLocalizedString(@"errorHUD_label", @"Error");
            }
            [hud hideAnimated:YES afterDelay:0.5f];
        }
        if (completion) {
            completion();
        }
    });
}


#pragma mark - Title and Subtitle

-(void)setTitleViewFromImageData
{
    // Create label programmatically
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = [UIColor piwigoColorWhiteCream];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 1;
    titleLabel.font = [UIFont piwigoFontSmallSemiBold];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.adjustsFontSizeToFitWidth = NO;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    if (@available(iOS 9, *)) {
        titleLabel.allowsDefaultTighteningForTruncation = YES;
    }
    if ([self.imageData.imageTitle length] == 0) {
        // No title => Use file name
        titleLabel.text = self.imageData.fileName;
    } else {
        titleLabel.text = self.imageData.imageTitle;
    }
    [titleLabel sizeToFit];

    // There is no subtitle in landscape mode on iPhone or when the creation date is unknown
    if ((([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) &&
         (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))) ||
        (self.imageData.dateCreated == self.imageData.datePosted))
    {
        float titleWidth = fmin(titleLabel.bounds.size.width, self.view.bounds.size.width*0.4);
        [titleLabel sizeThatFits:CGSizeMake(fmin(titleLabel.bounds.size.width, titleWidth), titleLabel.bounds.size.height)];
        UIView *oneLineTitleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, titleWidth, titleLabel.bounds.size.height)];
        self.navigationItem.titleView = oneLineTitleView;

        [oneLineTitleView addSubview:titleLabel];
        [oneLineTitleView addConstraint:[NSLayoutConstraint constraintView:titleLabel toWidth:titleWidth]];
        [oneLineTitleView addConstraints:[NSLayoutConstraint constraintCenter:titleLabel]];
    }
    else
    {
        UILabel *subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, titleLabel.frame.size.height, 0, 0)];
        subTitleLabel.backgroundColor = [UIColor clearColor];
        subTitleLabel.textColor = [UIColor piwigoColorWhiteCream];
        subTitleLabel.textAlignment = NSTextAlignmentCenter;
        subTitleLabel.numberOfLines = 1;
        subTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        subTitleLabel.font = [UIFont piwigoFontTiny];
        subTitleLabel.adjustsFontSizeToFitWidth = NO;
        subTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        if (@available(iOS 9, *)) {
            subTitleLabel.allowsDefaultTighteningForTruncation = YES;
        }
        subTitleLabel.text = [NSDateFormatter localizedStringFromDate:self.imageData.dateCreated
                                                            dateStyle:NSDateFormatterMediumStyle
                                                            timeStyle:NSDateFormatterMediumStyle];
        [subTitleLabel sizeToFit];
        
        float titleWidth = fmax(subTitleLabel.bounds.size.width, titleLabel.bounds.size.width);
        titleWidth = fmin(titleWidth, self.navigationController.view.bounds.size.width*0.4);
        UIView *twoLineTitleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, titleWidth, titleLabel.bounds.size.height + subTitleLabel.bounds.size.height)];
        self.navigationItem.titleView = twoLineTitleView;

        [twoLineTitleView addSubview:titleLabel];
        [twoLineTitleView addSubview:subTitleLabel];
        [twoLineTitleView addConstraint:[NSLayoutConstraint constraintView:titleLabel toWidth:titleWidth]];
        [twoLineTitleView addConstraint:[NSLayoutConstraint constraintCenterVerticalView:titleLabel]];
        [twoLineTitleView addConstraint:[NSLayoutConstraint constraintCenterVerticalView:subTitleLabel]];

        NSDictionary *views = @{
                                @"title" : titleLabel,
                                @"subtitle" : subTitleLabel,
                                };
        [twoLineTitleView addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"V:|[title][subtitle]|"
                                   options:kNilOptions metrics:nil views:views]];
    }
}

#pragma mark - ImagePreviewDelegate Methods

-(void)downloadProgress:(CGFloat)progress
{
	[self.progressBar setProgress:progress animated:YES];
    self.progressBar.hidden = (progress == 1) ? YES : NO;
}


#pragma mark - EditImageParamsDelegate Methods

-(void)didDeselectImageWithId:(NSInteger)imageId
{
    // Should never be called when the properties of a single image are edited
}

-(void)didRenameFileOfImage:(PiwigoImageData *)imageData
{
    // Update image data
    if (imageData.fileName) self.imageData.fileName = imageData.fileName;
    
    // Update title view
    [self setTitleViewFromImageData];
}

-(void)didFinishEditingParams:(PiwigoImageData *)params
{
    // Update image data
    if (params != nil) {
        // Update list of images
        NSInteger index = 0;
        for(PiwigoImageData *image in self.images)
        {
            if(image.imageId == params.imageId) {
                // Update image data
                image.imageTitle = params.imageTitle;
                image.author = params.author;
                image.privacyLevel = params.privacyLevel;
                if (params.comment)
                    image.comment = [NSString stringWithString:params.comment];
                else
                    image.comment = @"";
                image.tags = [params.tags copy];
                
                // Update list and currently viewed image
                [self.images replaceObjectAtIndex:index withObject:image];
                self.imageData = image;
                break;
            }
            index++;
        }
        
        // Update current view
        [self setTitleViewFromImageData];
    }

    // Enable buttons after action
    [self setEnableStateOfButtons:YES];

    // Reload tab bar
    [self updateNavBar];
}


#pragma mark - SetAlbumImageDelegate Methods

-(void)didSetImageAsAlbumThumbnail
{
    [self setEnableStateOfButtons:YES];
}


#pragma mark - MoveImageDelegate Methods

-(void)cancelMoveImage
{
    // Re-enable buttons
    [self setEnableStateOfButtons:YES];
}

-(void)didCopyImageInOneOfCategoryIds:(NSMutableArray *)categoryIds
{
    // Update image data
    self.imageData.categoryIds = [categoryIds mutableCopy];
}

-(void)didRemoveImage:(PiwigoImageData *)image atIndex:(NSInteger)index
{
    // Update album data
    if([self.imgDetailDelegate respondsToSelector:@selector(didDeleteImage:atIndex:)])
    {
        [self.imgDetailDelegate didDeleteImage:self.imageData atIndex:index];
    }

    // Return to image collection
    [self.navigationController popViewControllerAnimated:YES];
}


#pragma mark - ShareImageActivityItemProviderDelegate

-(void)imageActivityItemProviderPreprocessingDidBegin:(UIActivityItemProvider *)imageActivityItemProvider withTitle:(NSString *)title
{
    // Show HUD to let the user know the image is being downloaded in the background.
    dispatch_async(dispatch_get_main_queue(),
                   ^(void){
                       [self showHUDwithTitle:title withProgress:YES];
                   });
}

-(void)imageActivityItemProvider:(UIActivityItemProvider *)imageActivityItemProvider preprocessingProgressDidUpdate:(float)progress
{
    // Update HUD
    dispatch_async(dispatch_get_main_queue(),
                   ^(void){
                       [MBProgressHUD HUDForView:self.hudViewController.view].progress = progress;
                   });
}

-(void)imageActivityItemProviderPreprocessingDidEnd:(UIActivityItemProvider *)imageActivityItemProvider withImageId:(NSInteger)imageId
{
    // Close HUD
    dispatch_async(dispatch_get_main_queue(),
                   ^(void){
                       if ([imageActivityItemProvider isCancelled]) {
                           [self hideHUDwithSuccess:NO completion:^{
                               self.hudViewController = nil;
                           }];
                       }
                       else {
                           [self hideHUDwithSuccess:YES completion:^{
                               self.hudViewController = nil;
                           }];
                       }
                   });
}

-(void)showErrorWithTitle:(NSString *)title andMessage:(NSString *)message
{
    // Close HUD if needed
    if (self.hudViewController) {
        [self hideHUDwithSuccess:NO completion:nil];
    }
    
    // Display error alert after trying to share image
    dispatch_async(dispatch_get_main_queue(),
                   ^(void){
        // Determine present view controller
        UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
        }

        // Present alert
        UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:title
            message:message
            preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction* dismissAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
            style:UIAlertActionStyleCancel
            handler:^(UIAlertAction * action) {
                // Closes ActivityView
                [topViewController dismissViewControllerAnimated:YES completion:nil];
        }];

        [alert addAction:dismissAction];
        alert.view.tintColor = UIColor.piwigoColorOrange;
        if (@available(iOS 13.0, *)) {
            alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
        } else {
            // Fallback on earlier versions
        }
        [topViewController presentViewController:alert animated:YES completion:^{
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange;
        }];
                    });
}

@end
