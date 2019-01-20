//
//  ImageDetailViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "AllCategoriesViewController.h"
#import "AsyncImageActivityItemProvider.h"
#import "AsyncVideoActivityItemProvider.h"
#import "AppDelegate.h"
#import "CategoriesData.h"
#import "EditImageDetailsViewController.h"
#import "ImageDetailViewController.h"
#import "ImagePreviewViewController.h"
#import "ImageService.h"
#import "ImageScrollView.h"
#import "ImageUpload.h"
#import "ImagesCollection.h"
#import "Model.h"
#import "MoveImageViewController.h"
#import "MBProgressHUD.h"
#import "PhotosFetch.h"
#import "SAMKeychain.h"

NSString * const kPiwigoNotificationPinchedImage = @"kPiwigoNotificationPinchedImage";

@interface ImageDetailViewController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, ImagePreviewDelegate, EditImageDetailsDelegate, MoveImageDelegate, AsyncImageActivityItemProviderDelegate, UIToolbarDelegate>

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
@property (nonatomic, strong) UIBarButtonItem *spaceBetweenButtons;
@property (nonatomic, assign) BOOL isToolbarRequired;

@end

//#ifndef DEBUG_SHARE
//#define DEBUG_SHARE
//#endif

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
        [self setTitleViewFromImageData];

		ImagePreviewViewController *startingImage = [ImagePreviewViewController new];
        startingImage.imagePreviewDelegate = self;
		[startingImage setImageScrollViewWithImageData:self.imageData];
        if (self.imageData.fileSize == NSNotFound) {
            [self retrieveCompleteImageDataOfImageId:[self.imageData.imageId integerValue]];
        }
		startingImage.imageIndex = imageIndex;
		
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
        self.editBarButton.enabled = NO;
        self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteImage)];
        self.deleteBarButton.tintColor = [UIColor redColor];
        self.deleteBarButton.enabled = NO;
        self.shareBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareImage)];
        self.shareBarButton.tintColor = [UIColor piwigoOrange];
        self.setThumbnailBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"paperclip"] landscapeImagePhone:[UIImage imageNamed:@"paperclipCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(setAsAlbumImage)];
        self.setThumbnailBarButton.tintColor = [UIColor piwigoOrange];
        self.setThumbnailBarButton.enabled = NO;
        self.moveBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemReply target:self action:@selector(addImageToCategory)];
        self.moveBarButton.tintColor = [UIColor piwigoOrange];
        self.moveBarButton.enabled = NO;
        [self.moveBarButton setAccessibilityIdentifier:@"Move"];
        self.spaceBetweenButtons = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
        self.navigationController.toolbar.barStyle = UIBarStyleDefault;

        // For managing taps
		[self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapView)]];

        // Register image pinches
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didPinchView) name:kPiwigoNotificationPinchedImage object:nil];

        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(paletteChanged) name:kPiwigoNotificationPaletteChanged object:nil];
	}
	return self;
}


#pragma mark - View Lifecycle

-(void)paletteChanged
{
    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    [self setTitleViewFromImageData];
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

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Scroll previewed image to visible area
    if([self.imgDetailDelegate respondsToSelector:@selector(didFinishPreviewOfImageWithId:)])
    {
        [self.imgDetailDelegate didFinishPreviewOfImageWithId:[self.imageData.imageId integerValue]];
    }
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self updateNavBar];
        [self setTitleViewFromImageData];
    } completion:nil];
}

-(void)updateNavBar
{
    // Interface depends on device
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            
        // iPhone
        if ([Model sharedInstance].hasAdminRights)
        {
            // User with admin rights can move, edit, delete images and set as album image
            [self.navigationItem setRightBarButtonItems:@[self.editBarButton]];
            self.toolbarItems = @[self.shareBarButton, self.spaceBetweenButtons, self.moveBarButton, self.spaceBetweenButtons, self.setThumbnailBarButton, self.spaceBetweenButtons, self.deleteBarButton];

            // Present toolbar if needed
            self.isToolbarRequired = YES;
            BOOL isNavigationBarHidden = self.navigationController.isNavigationBarHidden;
            [self.navigationController setToolbarHidden:isNavigationBarHidden animated:YES];
        }
        else if ([[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights])
        {
            // User with upload access to the current category can edit images
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
    else    // iPad
    {
        // Hide toolbar
        self.isToolbarRequired = NO;
        [self.navigationController setToolbarHidden:YES animated:YES];

        if ([Model sharedInstance].hasAdminRights)
        {
            // User with admin rights can edit, delete images and set as album image
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


#pragma mark - Retrieve Image Data

-(void)retrieveCompleteImageDataOfImageId:(NSInteger)imageId
{
    // Image data are not complete when retrieved using pwg.categories.getImages
    self.shareBarButton.enabled = NO;
    self.editBarButton.enabled = NO;
    self.deleteBarButton.enabled = NO;
    self.moveBarButton.enabled = NO;
    self.setThumbnailBarButton.enabled = NO;

    // Required by Copy, Delete, Move actions (may also be used to show albums image belongs to)
    [ImageService getImageInfoById:imageId
          ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageDataComplete) {
              if (imageDataComplete != nil) {

                  // Update list of images
                  self.imageData = imageDataComplete;
                  NSInteger index = 0;
                  for(PiwigoImageData *image in self.images)
                  {
                      if([image.imageId integerValue] == [imageDataComplete.imageId integerValue]) {
                          break;
                      }
                      index++;
                  }
                  [self.images replaceObjectAtIndex:index withObject:imageDataComplete];

                  // Enable actions
                  self.shareBarButton.enabled = YES;
                  self.editBarButton.enabled = YES;
                  self.deleteBarButton.enabled = YES;
                  self.moveBarButton.enabled = YES;
                  self.setThumbnailBarButton.enabled = YES;
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
          [self retrieveCompleteImageDataOfImageId:[self.imageData.imageId integerValue]];
        }];
    
    [alert addAction:dismissAction];
    [alert addAction:retryAction];
    [self presentViewController:alert animated:YES completion:nil];
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
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:self.view andNberOfImagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
    if ((currentIndex > fmaxf(roundf(2 * imagesPerPage / 3.0), self.images.count - roundf(imagesPerPage / 3.0))) &&
        (self.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages]))
    {
        if([self.imgDetailDelegate respondsToSelector:@selector(needToLoadMoreImages)])
        {
            [self.imgDetailDelegate needToLoadMoreImages];
        }
    }

    // Does the needed image preview controller already exist?
    for (UIViewController *viewController in [pageViewController viewControllers]) {
        // Only consider view controllers of the right class!
        if ([viewController isKindOfClass:[ImagePreviewViewController class]]) {
            ImagePreviewViewController *imageViewCtrl = (ImagePreviewViewController *)viewController;
            // Return if exists
            if (imageViewCtrl.imageIndex == currentIndex + 1) {
                NSLog(@"=> Preview view controller for next image already exists");
                return nil;
            }
        }
    }
    
    // Retrieve (incomplete) image data and create view controller
    PiwigoImageData *imageData = [self.images objectAtIndex:currentIndex + 1];
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
    if (currentIndex <= 0)
    {
        // Crash reported by AppStore here on May 25th, 2017!
        // Should return nil when the user reaches the first image of the album
        return nil;
    }
    
    // Does the needed image preview controller already exist?
    for (UIViewController *viewController in [pageViewController viewControllers]) {
        // Only consider view controllers of the right class!
        if ([viewController isKindOfClass:[ImagePreviewViewController class]]) {
            ImagePreviewViewController *imageViewCtrl = (ImagePreviewViewController *)viewController;
            // Return if exists
            if (imageViewCtrl.imageIndex == currentIndex - 1) {
                NSLog(@"=> Preview view controller for previous image already exists");
                return nil;
            }
        }
    }

    // Retrieve (incomplete) image data
    PiwigoImageData *imageData = [self.images objectAtIndex:currentIndex - 1];
    
    // Retrieve (incomplete) image data and create view controller
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
    // Stop loading image if needed
    ImagePreviewViewController *removedVC = [pageViewController.viewControllers firstObject];
    if (removedVC.downloadTask.state == 0) {                        // Task active?
        [removedVC.scrollView.imageView cancelImageDownloadTask];   // Cancel thumbnail download
        [removedVC.downloadTask cancel];                            // Cancel image file download
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
    PiwigoImageData *imageData = [self.images objectAtIndex:currentIndex];
    if (self.imageData.fileSize == NSNotFound) {
        [self retrieveCompleteImageDataOfImageId:[imageData.imageId integerValue]];
    }

    self.imageData = [self.images objectAtIndex:currentIndex];
    [self setTitleViewFromImageData];
    if(self.imageData.isVideo)
    {
        self.progressBar.hidden = YES;
    }
}


#pragma mark - Edit Image

-(void)editImage
{
    // Present EditImageDetails view
    UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageDetails" bundle:nil];
    EditImageDetailsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageDetails"];
    editImageVC.imageDetails = [[ImageUpload alloc] initWithImageData:self.imageData];
    editImageVC.delegate = self;
    editImageVC.isEdit = YES;       // Edition mode
    [self pushView:editImageVC];
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
    if ([self.imageData.categoryIds count] > 1) {
        // This image is used in another album!
        [alert addAction:removeAction];
    }

    // Present list of actions
    alert.popoverPresentationController.barButtonItem = self.deleteBarButton;
    [self presentViewController:alert animated:YES completion:nil];
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
                   
                   // Remove image from current category
                   [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] removeImages:@[self.imageData]];
                   [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] deincrementImageSizeByOne];

                   // Hide HUD
                   [self hideHUDwithSuccess:YES completion:^{
                       self.hudViewController = nil;
                   }];

                   // Return to album view
                   [self didRemoveImage:self.imageData];
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
                 [self didRemoveImage:self.imageData];
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
            handler:^(UIAlertAction * action) {}];
    
    [alert addAction:dismissAction];
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - Share Image

-(void)shareImage
{
    // Check autorisation to access Photo Library (camera roll)
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

-(void)presentShareImageViewControllerWithCameraRollAccess:(BOOL)hasCameraRollAccess
{
    // Create new activity provider item to pass to the activity view controller
    NSMutableArray *itemsToShare = [NSMutableArray new];
    if (self.imageData.isVideo) {
        // Case of a video
        AsyncVideoActivityItemProvider *videoItemProvider = [[AsyncVideoActivityItemProvider alloc]  initWithPlaceholderImage:self.imageData];

        // Use delegation to monitor the progress of the item method
        videoItemProvider.delegate = self;
        
        // Add to list of items to share
        [itemsToShare addObject:videoItemProvider];
    }
    else {
        // Case of an image
        AsyncImageActivityItemProvider *imageItemProvider = [[AsyncImageActivityItemProvider alloc]  initWithPlaceholderImage:self.imageData];

        // Use delegation to monitor the progress of the item method
        imageItemProvider.delegate = self;

        // Add to list of items to share
        [itemsToShare addObject:imageItemProvider];
    }
    
    // Create an activity view controller with the activity provider item.
    // AsyncImageActivityItemProvider's superclass conforms to the UIActivityItemSource protocol
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];

    // Set HUD view controller for displaying progress
    self.hudViewController = activityViewController;
    
    // Exclude camera roll activity if needed
    if (!hasCameraRollAccess) {
        activityViewController.excludedActivityTypes = @[UIActivityTypeSaveToCameraRoll];
    }
    
    // Delete image/video file and remove observers after dismissing activity view controller
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError){
        NSLog(@"Activity Type selected: %@", activityType);
        if (completed) {
            NSLog(@"Selected activity was performed and returned error:%ld", (long)activityError.code);
            if (self.imageData.isVideo) {
                // Delete shared video file & remove observers
                [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareVideo object:nil];
            }
            else {
                // Delete shared image file & remove observers
                [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareImage object:nil];
            }
        } else {
            if (activityType == NULL) {
                NSLog(@"User dismissed the view controller without making a selection.");
            } else {
                NSLog(@"Activity was not performed.");
                if (self.imageData.isVideo)
                {
                    // Cancel task
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelShareVideo object:nil];
                    
                    // Delete shared video file & remove observers
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareVideo object:nil];
                }
                else {
                    // Cancel task
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelShareImage object:nil];
                    
                    // Delete shared image file & remove observers
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareImage object:nil];
                }
            }
        }
    }];
    
    // Present share image activity view controller
    activityViewController.popoverPresentationController.barButtonItem = self.shareBarButton;
    [self presentViewController:activityViewController animated:YES completion:nil];
}


#pragma mark - Set as Album Image

-(void)setAsAlbumImage
{
    // Present AllCategories view
    AllCategoriesViewController *allCategoriesPickVC = [[AllCategoriesViewController alloc] initForImage:self.imageData andCategoryId:[[self.imageData.categoryIds firstObject] integerValue]];
    [self pushView:allCategoriesPickVC];
}


#pragma mark - Move/Copy image to Category

-(void)addImageToCategory
{
    UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:nil message:nil
            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
            style:UIAlertActionStyleCancel
            handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* copyAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"copyImage_title", @"Copy to Album")
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction * action) {
                MoveImageViewController *moveImageVC = [[MoveImageViewController alloc] initWithSelectedImageIds:nil orSingleImageData:self.imageData inCategoryId:self.categoryId andCopyOption:YES];
                moveImageVC.moveImageDelegate = self;
                [self pushView:moveImageVC];
            }];

    UIAlertAction* moveAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"moveImage_title", @"Move to Album")
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction * action) {
                MoveImageViewController *moveImageVC = [[MoveImageViewController alloc] initWithSelectedImageIds:nil orSingleImageData:self.imageData inCategoryId:self.categoryId andCopyOption:NO];
                moveImageVC.moveImageDelegate = self;
                [self pushView:moveImageVC];
            }];

    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:copyAction];
    [alert addAction:moveAction];

    // Present list of actions
    alert.popoverPresentationController.barButtonItem = self.moveBarButton;
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - push view
-(void)pushView:(UIViewController *)viewController
{
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    navController.modalPresentationStyle = UIModalPresentationFullScreen;

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        navController.modalPresentationStyle = UIModalPresentationPopover;
        navController.popoverPresentationController.sourceView = self.view;
        [navController.popoverPresentationController setPermittedArrowDirections:0];
        [navController.popoverPresentationController setSourceRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0)];
    } else {
        navController.modalPresentationStyle = UIModalPresentationFullScreen;
    }

    [self presentViewController:navController animated:YES completion:nil];
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
                [hud hideAnimated:YES afterDelay:2.f];
            } else {
                UIImage *image = [[UIImage imageNamed:@"warning"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                hud.customView = imageView;
                hud.mode = MBProgressHUDModeCustomView;
                hud.label.text = NSLocalizedString(@"errorHUD_label", @"Error");
                [hud hideAnimated:YES afterDelay:0.5f];
            }
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
    titleLabel.textColor = [UIColor piwigoWhiteCream];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 1;
    titleLabel.font = [UIFont piwigoFontSmallSemiBold];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.adjustsFontSizeToFitWidth = NO;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    if (@available(iOS 9, *)) {
        titleLabel.allowsDefaultTighteningForTruncation = YES;
    }
    titleLabel.text = self.imageData.name;
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
        [oneLineTitleView addConstraints:[NSLayoutConstraint constraintCenterView:titleLabel]];
    }
    else
    {
        UILabel *subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, titleLabel.frame.size.height, 0, 0)];
        subTitleLabel.backgroundColor = [UIColor clearColor];
        subTitleLabel.textColor = [UIColor piwigoWhiteCream];
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
//    NSLog(@"==> setProgress:%.2f", progress);
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
            image.imageDescription = [NSString stringWithString:details.imageDescription];
            image.tags = [details.tags copy];
            [self.images replaceObjectAtIndex:index withObject:image];
            break;
        }
        index++;
    }

    // Update previewed image
    self.imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:[NSString stringWithFormat:@"%ld", (long)details.imageId]];
    
    // Update current view
    [self setTitleViewFromImageData];
}


#pragma mark - MoveImageDelegate Methods

-(void)didCopyImageInOneOfCategoryIds:(NSMutableArray *)categoryIds
{
    // Update image data
    self.imageData.categoryIds = [categoryIds mutableCopy];
}

-(void)didRemoveImage:(PiwigoImageData *)image
{
    // Update album data
    if([self.imgDetailDelegate respondsToSelector:@selector(didDeleteImage:)])
    {
        [self.imgDetailDelegate didDeleteImage:self.imageData];
    }

    // Return to image collection
    [self.navigationController popViewControllerAnimated:YES];
}


#pragma mark - AsyncImageActivityItemProviderDelegate

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

-(void)imageActivityItemProviderPreprocessingDidEnd:(UIActivityItemProvider *)imageActivityItemProvider
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
                            handler:^(UIAlertAction * action) { }];
                       
                       [alert addAction:dismissAction];
                       [topViewController presentViewController:alert animated:YES completion:nil];
                    });
}

@end
