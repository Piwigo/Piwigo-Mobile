//
//  ImageDetailViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>
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
		[startingImage setImageWithImageData:self.imageData];
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
		[self.progressBar addConstraint:[NSLayoutConstraint constraintView:self.progressBar toHeight:5]];
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
	
	UIBarButtonItem *imageOptionsButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(imageOptions)];
	self.navigationItem.rightBarButtonItem = imageOptionsButton;
	
	if([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)])
	{
		self.automaticallyAdjustsScrollViewInsets = false;
		self.edgesForExtendedLayout = UIRectEdgeNone;
	}
}

-(void)imageOptions
{
	NSMutableArray *otherButtons = [NSMutableArray new];
	[otherButtons addObject:NSLocalizedString(@"imageOptions_download", @"Download")];
    
    // Add actions capabilities if user has admin rights
    if([Model sharedInstance].hasAdminRights)
	{
		[otherButtons addObject:NSLocalizedString(@"imageOptions_edit",  @"Edit")];
		[otherButtons addObject:NSLocalizedString(@"imageOptions_setAlbumImage", @"Set as Album Image")];
	}
	
	[UIActionSheet showFromBarButtonItem:self.navigationItem.rightBarButtonItem
								animated:YES
							   withTitle:NSLocalizedString(@"imageOptions_title", @"Image Options")
					   cancelButtonTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
				  destructiveButtonTitle:[Model sharedInstance].hasAdminRights ? NSLocalizedString(@"deleteImage_delete", @"Delete") : nil
					   otherButtonTitles:otherButtons
								tapBlock:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
									buttonIndex += [Model sharedInstance].hasAdminRights ? 0 : 1;
									switch(buttonIndex)
									{
										case 0: // Delete
											[self deleteImage];
											break;
										case 1: // Download
											[self downloadImage];
											break;
										case 2: // Edit
										{
											if(![Model sharedInstance].hasAdminRights) break;
											
											UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageDetails" bundle:nil];
											EditImageDetailsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageDetails"];
											editImageVC.imageDetails = [[ImageUpload alloc] initWithImageData:self.imageData];
											editImageVC.isEdit = YES;
											UINavigationController *presentNav = [[UINavigationController alloc] initWithRootViewController:editImageVC];
                                            // Added dispatch_async() to prevent view not showing up on iPad
											dispatch_async(dispatch_get_main_queue(), ^ {
                                                [self.navigationController presentViewController:presentNav animated:YES completion:nil];
                                            });
											break;
										}
										case 3:	// set as album image
										{
											if(![Model sharedInstance].hasAdminRights) break;
											
											AllCategoriesViewController *allCategoriesPickVC = [[AllCategoriesViewController alloc] initForImageId:[self.imageData.imageId integerValue] andCategoryId:[[self.imageData.categoryIds firstObject] integerValue]];
											[self.navigationController pushViewController:allCategoriesPickVC animated:YES];
											
											break;
										}
									}
								}];
}

-(void)deleteImage
{
	[UIAlertView showWithTitle:NSLocalizedString(@"deleteSingleImage_title", @"Delete Image")
					   message:NSLocalizedString(@"deleteSingleImage_message", @"Are you sure you want to delete this image? This cannot be undone!")
			 cancelButtonTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
			 otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
					  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
						  if(buttonIndex == 1) {
							  [ImageService deleteImage:self.imageData
										   ListOnCompletion:^(NSURLSessionTask *task) {
											   if([self.imgDetailDelegate respondsToSelector:@selector(didDeleteImage:)])
											   {
												   [self.imgDetailDelegate didDeleteImage:self.imageData];
											   }
											   [self.navigationController popViewControllerAnimated:YES];
										   } onFailure:^(NSURLSessionTask *task, NSError *error) {
											   [UIAlertView showWithTitle:@"Delete Fail"
																  message:@"Failed to delete image\nRetry?"
														cancelButtonTitle:NSLocalizedString(@"alertNoButton", @"No")
														otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
																 tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
																	 if(buttonIndex == 1)
																	 {
																		 [self deleteImage];
																	 }
																 }];
#if defined(DEBUG)
											   NSLog(@"fail to delete!");
#endif
                                           }];
						  }
					  }];
}

-(void)downloadImage
{
	// Check that user provided access to Photos.app
    if ([ALAssetsLibrary authorizationStatus] != ALAuthorizationStatusAuthorized) {
        [UIAlertView showWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
                           message:NSLocalizedString(@"localAlbums_photosNotAuthorized_msg", @"tell user to change settings, how")
                 cancelButtonTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                 otherButtonTitles:nil
                          tapBlock:nil
         ];
        return;
    }
    
    // Display the download view
    self.downloadView.hidden = NO;
	
	UIImageView *dummyView = [UIImageView new];
	__weak typeof(self) weakSelf = self;
    NSString *URLRequest = [NetworkHandler getURLWithPath:[self.imageData.ThumbPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] asPiwigoRequest:NO withURLParams:nil];
    [dummyView setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:URLRequest]]
					 placeholderImage:nil
							  success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
								  weakSelf.downloadView.downloadImage = image;
							  } failure:nil];
	if(!self.imageData.isVideo)
	{
		[ImageService downloadImage:self.imageData
						 onProgress:^(NSProgress *progress) {
                             dispatch_async(dispatch_get_main_queue(),
                                            ^(void){self.downloadView.percentDownloaded = progress.fractionCompleted;});
						 } ListOnCompletion:^(NSURLSessionTask *task, UIImage *image) {
							 [self saveImageToCameraRoll:image];
						 } onFailure:^(NSURLSessionTask *task, NSError *error) {
							 self.downloadView.hidden = YES;
							 [UIAlertView showWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
												message:[NSString stringWithFormat:NSLocalizedString(@"downloadImageFail_message", @"Failed to download image!\n%@"), [error localizedDescription]]
									  cancelButtonTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
									  otherButtonTitles:@[NSLocalizedString(@"alertTryAgainButton", @"Try Again")]
											   tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
												   if(buttonIndex == 1) {
													   [self downloadImage];
												   }
											   }];
						 }];
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
                         self.downloadView.hidden = YES;
                         [UIAlertView showWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
                                            message:[NSString stringWithFormat:NSLocalizedString(@"downloadVideoFail_message", @"Failed to download video!\n%@"), [error localizedDescription]]
                                  cancelButtonTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                  otherButtonTitles:@[NSLocalizedString(@"alertTryAgainButton", @"Try Again")]
                                           tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                               if(buttonIndex == 1) {
                                                   [self downloadImage];
                                               }
                                           }];
                      } else {
                          // Try to move video in Photos.app
#if defined(DEBUG)
                          NSLog(@"path= %@", filePath.path);
#endif
                          if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(filePath.path)) {
                              UISaveVideoAtPathToSavedPhotosAlbum(filePath.path, self, @selector(movie:didFinishSavingWithError:contextInfo:), nil);
                          } else {
                              [UIAlertView showWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
                                                 message:[NSString stringWithFormat:NSLocalizedString(@"downloadVideoFail_message", @"Failed to download video!\n%@"), NSLocalizedString(@"downloadVideoFail_Photos", @"Video format not accepted by Photos!")]
                                       cancelButtonTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                       otherButtonTitles:nil
                                                tapBlock:nil
                               ];
                          }
                          self.downloadView.hidden = YES;
                      }
                  }
         ];
	}
}
-(void)saveImageToCameraRoll:(UIImage*)imageToSave
{
	UIImageWriteToSavedPhotosAlbum(imageToSave, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

// called when the image is done saving to disk
-(void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
	if(error)
	{
		[UIAlertView showWithTitle:NSLocalizedString(@"imageSaveError_title", @"Fail Saving Image")
						   message:[NSString stringWithFormat:NSLocalizedString(@"imageSaveError_message", @"Failed to save image. Error: %@"), [error localizedDescription]]
				 cancelButtonTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
				 otherButtonTitles:nil
						  tapBlock:nil];
	}
	self.downloadView.hidden = YES;
}
-(void)movie:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
	if(error)
	{
		[UIAlertView showWithTitle:NSLocalizedString(@"videoSaveError_title", @"Fail Saving Video")
						   message:[NSString stringWithFormat:NSLocalizedString(@"videoSaveError_message", @"Failed to save video. Error: %@"), [error localizedDescription]]
				 cancelButtonTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
				 otherButtonTitles:nil
						  tapBlock:nil];
	}
	self.downloadView.hidden = YES;
}

-(void)didTapView
{
	[self.navigationController setNavigationBarHidden:!self.navigationController.navigationBarHidden animated:YES];

	if(self.navigationController.navigationBarHidden)
	{
		[self hideTabBar:self.tabBarController];
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
	[nextImage setImageWithImageData:imageData];
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
	[prevImage setImageWithImageData:imageData];
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

    self.imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andIndex:[[[pageViewController viewControllers] firstObject] imageIndex]];

	if(self.imageData.isVideo)
	{
		self.progressBar.hidden = YES;
	}

	self.imageData = [self.images objectAtIndex:[[[pageViewController viewControllers] firstObject] imageIndex]];
	
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
