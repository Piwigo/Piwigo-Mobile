//
//  ImageDetailViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageDetailViewController.h"
#import "CategoriesData.h"
#import "ImageService.h"
#import "ImageDownloadView.h"
#import "Model.h"
#import "ImagePreviewViewController.h"
#import "EditImageDetailsViewController.h"
#import "ImageUpload.h"
#import "ImageScrollView.h"

@interface ImageDetailViewController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, ImagePreviewDelegate>

@property (nonatomic, strong) PiwigoImageData *imageData;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) NSLayoutConstraint *topProgressBarConstraint;

@property (nonatomic, assign) NSInteger categoryId;

@property (nonatomic, strong) ImageDownloadView *downloadView;

@property (nonatomic, assign) BOOL isSorted;
@property (nonatomic, strong) NSArray *sortedImages;

@end

@implementation ImageDetailViewController

// @TODO: BUG:: don't use imageIndex based on the cached data -- you want to pull from the sorted list that's sorted in the ViewController-- abstract it out and have both views pull from the same source.
-(instancetype)initWithCategoryId:(NSInteger)categoryId atImageIndex:(NSInteger)imageIndex isSorted:(BOOL)isSorted withArray:(NSArray*)array
{
	self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
	if(self)
	{
		self.view.backgroundColor = [UIColor blackColor];
		self.categoryId = categoryId;
		self.isSorted = isSorted;
		if(self.isSorted)
		{
			self.sortedImages = array;
		}
		
		self.dataSource = self;
		self.delegate = self;
		
		PiwigoImageData *imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andIndex:imageIndex];
		if(self.isSorted)
		{
			imageData = [self.sortedImages objectAtIndex:imageIndex];
		}
		self.imageData = imageData;
		self.title = self.imageData.name;
		ImagePreviewViewController *startingImage = [ImagePreviewViewController new];
		[startingImage setImageWithImageData:imageData];
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
		[self.progressBar addConstraint:[NSLayoutConstraint constrainViewToHeight:self.progressBar height:10]];
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
	
	self.topProgressBarConstraint.constant = self.navigationController.navigationBar.frame.size.height + [UIApplication sharedApplication].statusBarFrame.size.height;
	
	if([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)])
	{
		self.automaticallyAdjustsScrollViewInsets = false;
	}
}

-(void)imageOptions
{
	[UIActionSheet showFromBarButtonItem:self.navigationItem.rightBarButtonItem
								animated:YES
							   withTitle:NSLocalizedString(@"imageOptions_title", @"Image Options")
					   cancelButtonTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
				  destructiveButtonTitle:[Model sharedInstance].hasAdminRights ? NSLocalizedString(@"deleteImage_delete", @"Delete") : nil
					   otherButtonTitles:@[NSLocalizedString(@"iamgeOptions_download", @"Download"), NSLocalizedString(@"iamgeOptions_edit",  @"Edit")]
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
											UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageDetails" bundle:nil];
											EditImageDetailsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageDetails"];
											editImageVC.imageDetails = [[ImageUpload alloc] initWithImageData:self.imageData];
											editImageVC.isEdit = YES;
											UINavigationController *presentNav = [[UINavigationController alloc] initWithRootViewController:editImageVC];
											[self.navigationController presentViewController:presentNav animated:YES completion:nil];
											break;
										}
									}
								}];
}

-(void)deleteImage
{
	[UIAlertView showWithTitle:NSLocalizedString(@"deleteSingleImage_title", @"Delete Image")
					   message:NSLocalizedString(@"deleteSingleImage_message", @"Are you sure you want to delete this image? This cannot be undone!")
			 cancelButtonTitle:NSLocalizedString(@"deleteImage_cancelButton", @"Nevermind")
			 otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
					  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
						  if(buttonIndex == 1) {
							  [ImageService deleteImage:self.imageData
										   ListOnCompletion:^(AFHTTPRequestOperation *operation) {
											   if([self.imgDetailDelegate respondsToSelector:@selector(didDeleteImage)])
											   {
												   [self.imgDetailDelegate didDeleteImage];
											   }
											   [self.navigationController popViewControllerAnimated:YES];
										   } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
											   [UIAlertView showWithTitle:@"Delete Fail"
																  message:@"Failed to delete image\nRetry?"
														cancelButtonTitle:@"No"
														otherButtonTitles:@[@"Yes"]
																 tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
																	 if(buttonIndex == 1)
																	 {
																		 [self deleteImage];
																	 }
																 }];
											   NSLog(@"fail to delete!");
										   }];
						  }
					  }];
}

-(void)downloadImage
{
	self.downloadView.hidden = NO;
	
	UIImageView *dummyView = [UIImageView new];
	__weak typeof(self) weakSelf = self;
	[dummyView setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.imageData.thumbPath]]
					 placeholderImage:nil
							  success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
								  weakSelf.downloadView.downloadImage = image;
							  } failure:nil];
	if(!self.imageData.isVideo)
	{
		[ImageService downloadImage:self.imageData
						 onProgress:^(NSInteger current, NSInteger total) {
							 CGFloat progress = (CGFloat)current / total;
							 self.downloadView.percentDownloaded = progress;
						 } ListOnCompletion:^(AFHTTPRequestOperation *operation, UIImage *image) {
							 [self saveImageToCameraRoll:image];
						 } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
							 self.downloadView.hidden = YES;
							 [UIAlertView showWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
												message:[NSString stringWithFormat:NSLocalizedString(@"downloadImageFail_message", @"Failed to download image!\n%@"), [error localizedDescription]]
									  cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
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
						 onProgress:^(NSInteger current, NSInteger total) {
							 CGFloat progress = (CGFloat)current / total;
							 self.downloadView.percentDownloaded = progress;
						 } ListOnCompletion:^(AFHTTPRequestOperation *operation, id response) {
							 NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
							 NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:self.imageData.fileName];
							 UISaveVideoAtPathToSavedPhotosAlbum(path, self, @selector(movie:didFinishSavingWithError:contextInfo:), nil);
						 } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
							 self.downloadView.hidden = YES;
							 [UIAlertView showWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
												message:[NSString stringWithFormat:@"Failed to download video!\n%@", [error localizedDescription]] // @TODO: Localize this
									  cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
									  otherButtonTitles:@[NSLocalizedString(@"alertTryAgainButton", @"Try Again")]
											   tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
												   if(buttonIndex == 1) {
													   [self downloadImage];
												   }
											   }];
						 }];
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
				 cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
				 otherButtonTitles:nil
						  tapBlock:nil];
	}
	self.downloadView.hidden = YES;
}
-(void)movie:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
	if(error)
	{
		[UIAlertView showWithTitle:@"Fail Saving Video"// @TODO: Localize these!
						   message:[NSString stringWithFormat:@"Failed to save video. Error: %@", [error localizedDescription]]
				 cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
				 otherButtonTitles:nil
						  tapBlock:nil];
	}
	self.downloadView.hidden = YES;
}

-(void)didTapView
{
	[self.navigationController setNavigationBarHidden:!self.navigationController.navigationBarHidden animated:YES];

	[UIView animateWithDuration:0.5 animations:^{
		self.tabBarController.tabBar.hidden = !self.tabBarController.tabBar.hidden;
		self.topProgressBarConstraint.constant = !self.tabBarController.tabBar.hidden ? self.navigationController.navigationBar.frame.size.height + [UIApplication sharedApplication].statusBarFrame.size.height : [UIApplication sharedApplication].statusBarFrame.size.height;
		
	}];
	
	CGRect frame = self.tabBarController.tabBar.frame;
	CGFloat height = frame.size.height;
	CGFloat offsetY = (frame.origin.y >= self.view.frame.size.height) ? -height : height;
	
	[UIView animateWithDuration:0.3
					 animations:^{
						 self.tabBarController.tabBar.frame = CGRectOffset(frame, 0, offsetY);
					 }];
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
	
	// check to see if they've scroll beyond a certain threshold, then load more image data
	if(currentIndex >= [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count - 21 && [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages])
	{
		if([self.imgDetailDelegate respondsToSelector:@selector(needToLoadMoreImages)])
		{
			[self.imgDetailDelegate needToLoadMoreImages];
		}
	}
	
	if(currentIndex >= [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count - 1)
	{
		return nil;
	}
	PiwigoImageData *imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andIndex:currentIndex + 1];
	if(self.isSorted)
	{
		imageData = [self.sortedImages objectAtIndex:currentIndex + 1];
	}
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
		return nil;
	}
	
	PiwigoImageData *imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andIndex:currentIndex - 1];
	if(self.isSorted)
	{
		imageData = [self.sortedImages objectAtIndex:currentIndex - 1];
	}
	ImagePreviewViewController *prevImage = [ImagePreviewViewController new];
	[prevImage setImageWithImageData:imageData];
	prevImage.imageIndex = currentIndex - 1;
	return prevImage;
}

-(void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed
{
	ImagePreviewViewController *removedVC = [previousViewControllers firstObject];
	[removedVC.scrollView.imageView cancelImageRequestOperation];
	
	ImagePreviewViewController *view = [pageViewController.viewControllers firstObject];
	view.imagePreviewDelegate = self;
	self.progressBar.hidden = view.imageLoaded;
	[self.progressBar setProgress:0];
	self.imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andIndex:[[[pageViewController viewControllers] firstObject] imageIndex]];
	if(self.isSorted)
	{
		self.imageData = [self.sortedImages objectAtIndex:[[[pageViewController viewControllers] firstObject] imageIndex]];
	}
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
