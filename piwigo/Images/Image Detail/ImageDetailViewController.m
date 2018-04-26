//
//  ImageDetailViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "ImageDetailViewController.h"
#import "CategoriesData.h"
#import "ImageService.h"
#import "ImageDownloadView.h"
#import "Model.h"
#import "ImagePreviewViewController.h"
#import "EditImageDetailsViewController.h"
#import "ImageUpload.h"
#import "ImageScrollView.h"
#import "AllCategoriesViewController.h"
#import "SAMKeychain.h"

@interface ImageDetailViewController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, ImagePreviewDelegate>

@property (nonatomic, strong) PiwigoImageData *imageData;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) NSLayoutConstraint *topProgressBarConstraint;

@property (nonatomic, assign) NSInteger categoryId;

@property (nonatomic, strong) ImageDownloadView *downloadView;

@end

@implementation ImageDetailViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId atImageIndex:(NSInteger)imageIndex withArray:(NSArray*)array
{
	self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
	if(self)
	{
		self.view.backgroundColor = [UIColor blackColor];
		self.categoryId = categoryId;
		self.images = array;
		
		self.dataSource = self;
		self.delegate = self;
		
		self.imageData = [self.images objectAtIndex:imageIndex];
		self.title = self.imageData.name;
		ImagePreviewViewController *startingImage = [ImagePreviewViewController new];
		[startingImage setImageScrollViewWithImageData:self.imageData];
		startingImage.imageIndex = imageIndex;
		
		[self setViewControllers:@[startingImage]
					   direction:UIPageViewControllerNavigationDirectionForward
						animated:NO
					  completion:nil];
		
		self.progressBar = [UIProgressView new];
		self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
		self.progressBar.hidden = YES;
		self.progressBar.tintColor = [UIColor piwigoOrange];
		[self.view addSubview:self.progressBar];
		[self.view addConstraints:[NSLayoutConstraint constraintFillWidth:self.progressBar]];
		[self.progressBar addConstraint:[NSLayoutConstraint constraintView:self.progressBar toHeight:3]];
		self.topProgressBarConstraint = [NSLayoutConstraint constraintWithItem:self.progressBar
															  attribute:NSLayoutAttributeTop
															  relatedBy:NSLayoutRelationEqual
																 toItem:self.view
															  attribute:NSLayoutAttributeTop
															 multiplier:1.0
															   constant:0];
		[self.view addConstraint:self.topProgressBarConstraint];
		
		[self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapView)]];
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
    // Image options button
	UIBarButtonItem *imageOptionsButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(imageOptions)];
	self.navigationItem.rightBarButtonItem = imageOptionsButton;
	
    // Never present video poster in full screen
    if (self.imageData.isVideo) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    }
    
    // Scrolling
	if([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)])
	{
		self.automaticallyAdjustsScrollViewInsets = false;
		self.edgesForExtendedLayout = UIRectEdgeNone;
	}

    // Hide tab bar
    self.tabBarController.tabBar.hidden = YES;
}

-(void)imageOptions
{
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:NSLocalizedString(@"imageOptions_title", @"Image Options")
                                message:nil
                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* deleteAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"deleteImage_delete", @"Delete")
                                   style:UIAlertActionStyleDestructive
                                   handler:^(UIAlertAction * action) {
                                       [self deleteImage];
                                   }];
    
    UIAlertAction* downloadAction = [UIAlertAction
                                     actionWithTitle:NSLocalizedString(@"imageOptions_download", @"Download")
                                     style:UIAlertActionStyleDefault
                                     handler:^(UIAlertAction * action) {
                                         [self downloadImage];
                                     }];

    UIAlertAction* editAction = [UIAlertAction
                                 actionWithTitle:NSLocalizedString(@"imageOptions_edit",  @"Edit")
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action) {
                                     // Present EditImageDetails view
                                     UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageDetails" bundle:nil];
                                     EditImageDetailsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageDetails"];
                                     editImageVC.imageDetails = [[ImageUpload alloc] initWithImageData:self.imageData];
                                     editImageVC.isEdit = YES;
                                     UINavigationController *presentNav = [[UINavigationController alloc] initWithRootViewController:editImageVC];
                                     [self.navigationController presentViewController:presentNav animated:YES completion:nil];
                                 }];

    UIAlertAction* setAsAlbumImageAction = [UIAlertAction
                                            actionWithTitle:NSLocalizedString(@"imageOptions_setAlbumImage", @"Set as Album Image")
                                            style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * action) {
                                                // Present CategoriesSelector view
                                                AllCategoriesViewController *allCategoriesPickVC = [[AllCategoriesViewController alloc] initForImageId:[self.imageData.imageId integerValue] andCategoryId:[[self.imageData.categoryIds firstObject] integerValue]];
                                                [self.navigationController pushViewController:allCategoriesPickVC animated:YES];
                                            }];

    // Admins users can delete images/videos
    if([Model sharedInstance].hasAdminRights) {
        [alert addAction:deleteAction];
    }
    
    // Admins and Community users having upload rights can edit images/videos in selected albums
    if([Model sharedInstance].hasAdminRights || [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights]) {
        [alert addAction:editAction];
    }
    
    // Admin users can "Set As Album Image"
    if ([Model sharedInstance].hasAdminRights) {
        [alert addAction:setAsAlbumImageAction];
    }
    
    // Add default actions
    [alert addAction:downloadAction];
    [alert addAction:cancelAction];
    
    // Present list of actions
    alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark -- Delete image

-(void)deleteImage
{
    UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"deleteSingleImage_title", @"Delete Image")
            message:NSLocalizedString(@"deleteSingleImage_message", @"Are you sure you want to delete this image? This cannot be undone!")
            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
           actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
           style:UIAlertActionStyleCancel
           handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* deleteAction = [UIAlertAction
           actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
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
                                actionWithTitle:NSLocalizedString(@"alertTryAgainButton", @"Try Again")
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
    alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark -- Download image

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
    
    // Display the download view
    self.downloadView.hidden = NO;

    // Dummy image for progress view
	UIImageView *dummyView = [UIImageView new];
	__weak typeof(self) weakSelf = self;
    NSURL *URL = [NSURL URLWithString:self.imageData.ThumbPath];
    [dummyView setImageWithURLRequest:[NSURLRequest requestWithURL:URL]
					 placeholderImage:[UIImage imageNamed:@"placeholderImage"]
							  success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
								  weakSelf.downloadView.downloadImage = image;
							  } failure:nil];

    // Launch the download
    if(!self.imageData.isVideo)
	{
		[ImageService downloadImage:self.imageData
                         onProgress:^(NSProgress *progress) {
                             dispatch_async(dispatch_get_main_queue(),
                                            ^(void){self.downloadView.percentDownloaded = progress.fractionCompleted;});

                         }
                  completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
                      // Any error ?
                      if (error.code) {
                          // Failed — Inform user
                          self.downloadView.hidden = YES;
                          UIAlertController* alert = [UIAlertController
                                                      alertControllerWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
                                                      message:[NSString stringWithFormat:NSLocalizedString(@"downloadImageFail_message", @"Failed to download image!\n%@"), [error localizedDescription]]
                                                      preferredStyle:UIAlertControllerStyleAlert];

                          UIAlertAction* defaultAction = [UIAlertAction
                                                          actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                                          style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * action) {}];

                          UIAlertAction* retryAction = [UIAlertAction
                                                        actionWithTitle:NSLocalizedString(@"alertTryAgainButton", @"Try Again")
                                                        style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * action) {
                                                            [self downloadImage];
                                                        }];

                          [alert addAction:defaultAction];
                          [alert addAction:retryAction];
                          [self presentViewController:alert animated:YES completion:nil];

                      } else {
                          // Try to move photo in Photos.app
                          [self saveImageToCameraRoll:filePath];
                      }
                  }
         ];
	}
	else
	{
        [ImageService downloadVideo:self.imageData
                         onProgress:^(NSProgress *progress) {
                             dispatch_async(dispatch_get_main_queue(),
                                            ^(void){self.downloadView.percentDownloaded = progress.fractionCompleted;}
                                            );
                         }
                  completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {                      
                      // Any error ?
                      if (error.code) {
                          // Failed — Inform user
                          self.downloadView.hidden = YES;
                          UIAlertController* alert = [UIAlertController
                                                      alertControllerWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
                                                      message:[NSString stringWithFormat:NSLocalizedString(@"downloadVideoFail_message", @"Failed to download video!\n%@"), [error localizedDescription]]
                                                      preferredStyle:UIAlertControllerStyleAlert];
                          
                          UIAlertAction* defaultAction = [UIAlertAction
                                                          actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                                          style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * action) {}];
                          
                          UIAlertAction* retryAction = [UIAlertAction
                                                        actionWithTitle:NSLocalizedString(@"alertTryAgainButton", @"Try Again")
                                                        style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * action) {
                                                            [self downloadImage];
                                                        }];
                          
                          [alert addAction:defaultAction];
                          [alert addAction:retryAction];
                          [self presentViewController:alert animated:YES completion:nil];
                          
                      } else {
                          // Try to move video in Photos.app
#if defined(DEBUG)
                          NSLog(@"path= %@", filePath.path);
#endif
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
                          self.downloadView.hidden = YES;
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
    
    // Hide progress view
    self.downloadView.hidden = YES;
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
	self.downloadView.hidden = YES;
}

-(void)didTapView
{
	[self.navigationController setNavigationBarHidden:!self.navigationController.navigationBarHidden animated:YES];

	if(self.navigationController.navigationBarHidden)
	{
        if (self.imageData.isVideo) {
            // User wants to play/replay the video
            ImagePreviewViewController *playVideo = [ImagePreviewViewController new];
            [playVideo startVideoPlayerViewWithImageData:self.imageData];
        } else {
            // User wants to display the image in full screen
            [self hideTabBar:self.tabBarController];
        }
	}
	else
	{
		[self showTabBar:self.tabBarController];
	}
}

-(void)hideTabBar:(UITabBarController*)tabbarcontroller
{
	return;
	
//	CGRect screenRect = [[UIScreen mainScreen] bounds];
//	
//	[UIView beginAnimations:nil context:NULL];
//	[UIView setAnimationDuration:0.3];
//	float fHeight = screenRect.size.height;
//	
//	for(UIView *view in tabbarcontroller.view.subviews)
//	{
//		if([view isKindOfClass:[UITabBar class]])
//		{
//			[view setFrame:CGRectMake(view.frame.origin.x, fHeight, view.frame.size.width, view.frame.size.height)];
//		}
//		else
//		{
//			[view setFrame:CGRectMake(view.frame.origin.x, view.frame.origin.y, view.frame.size.width, fHeight)];
//			view.backgroundColor = [UIColor blackColor];
//		}
//	}
//	[UIView commitAnimations];
}

-(void)showTabBar:(UITabBarController*)tabbarcontroller
{
	return;
//	CGRect screenRect = [[UIScreen mainScreen] bounds];
//	float fHeight = screenRect.size.height - tabbarcontroller.tabBar.frame.size.height;
//	
//	[UIView beginAnimations:nil context:NULL];
//	[UIView setAnimationDuration:0.3];
//	for(UIView *view in tabbarcontroller.view.subviews)
//	{
//		if([view isKindOfClass:[UITabBar class]])
//		{
//			[view setFrame:CGRectMake(view.frame.origin.x, fHeight, view.frame.size.width, view.frame.size.height)];
//		}
//		else
//		{
//			[view setFrame:CGRectMake(view.frame.origin.x, view.frame.origin.y, view.frame.size.width, fHeight)];
//		}
//	}
//	[UIView commitAnimations];
}

-(ImageDownloadView*)downloadView
{
	if(_downloadView) return _downloadView;
	
	_downloadView = [ImageDownloadView new];
	_downloadView.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:_downloadView];
	[self.view addConstraints:[NSLayoutConstraint constraintFillSize:_downloadView]];
	return _downloadView;
}

#pragma mark -- UIPageViewControllerDataSource

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
//    [removedVC.scrollView.imageView cancelImageRequestOperation];
	
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

#pragma mark ImagePreviewDelegate Methods

-(void)downloadProgress:(CGFloat)progress
{
	[self.progressBar setProgress:progress animated:YES];
	if(progress == 1)
	{
		self.progressBar.hidden = YES;
	}
}

@end
