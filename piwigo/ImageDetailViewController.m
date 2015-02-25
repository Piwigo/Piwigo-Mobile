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

@interface ImageDetailViewController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, ImagePreviewDelegate>

@property (nonatomic, strong) PiwigoImageData *imageData;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) NSLayoutConstraint *topProgressBarConstraint;

@property (nonatomic, assign) NSInteger categoryId;

@property (nonatomic, strong) ImageDownloadView *downloadView;

@end

@implementation ImageDetailViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId andImageIndex:(NSInteger)imageIndex
{
	self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
	if(self)
	{
		self.view.backgroundColor = [UIColor blackColor];
		self.categoryId = categoryId;
		
		self.dataSource = self;
		self.delegate = self;
		
		PiwigoImageData *imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andIndex:imageIndex];
		self.imageData = imageData;
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
											// @TODO: Show edit image view
											break;
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
											   // @TODO: display error to delete image
											   NSLog(@"fail to delete");
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
	
	if(currentIndex >= [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count - 1)
	{
		return nil;
	}
	PiwigoImageData *imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andIndex:currentIndex + 1];
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
	ImagePreviewViewController *prevImage = [ImagePreviewViewController new];
	[prevImage setImageWithImageData:imageData];
	prevImage.imageIndex = currentIndex - 1;
	return prevImage;
}

-(void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed
{
	ImagePreviewViewController *view = [pageViewController.viewControllers firstObject];
	view.imagePreviewDelegate = self;
	self.progressBar.hidden = view.imageLoaded;
	[self.progressBar setProgress:0];
	self.imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andIndex:[[[pageViewController viewControllers] firstObject] imageIndex]];
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
