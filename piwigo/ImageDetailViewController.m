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

@interface ImageDetailViewController ()

@property (nonatomic, strong) PiwigoImageData *imageData;
@property (nonatomic, strong) UIImageView *image;
@property (nonatomic, strong) UIProgressView *progressBar;

@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, assign) NSInteger currentImageIndex;

@property (nonatomic, strong) ImageDownloadView *downloadView;

@end

@implementation ImageDetailViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId andImageIndex:(NSInteger)imageIndex
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor blackColor];
		self.currentImageIndex = imageIndex;
		self.categoryId = categoryId;
		
		self.image = [UIImageView new];
		self.image.translatesAutoresizingMaskIntoConstraints = NO;
		self.image.contentMode = UIViewContentModeScaleAspectFit;
		[self.view addSubview:self.image];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.image]];
		
		self.progressBar = [UIProgressView new];
		self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
		self.progressBar.hidden = YES;
		self.progressBar.tintColor = [UIColor piwigoOrange];
		[self.view addSubview:self.progressBar];
		[self.view addConstraints:[NSLayoutConstraint constraintFillWidth:self.progressBar]];
		[self.progressBar addConstraint:[NSLayoutConstraint constrainViewToHeight:self.progressBar height:10]];
		[self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.progressBar
															  attribute:NSLayoutAttributeTop
															  relatedBy:NSLayoutRelationEqual
																 toItem:self.topLayoutGuide
															  attribute:NSLayoutAttributeBottom
															 multiplier:1.0
															   constant:0]];
		
		UISwipeGestureRecognizer *rightSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRight)];
		rightSwipe.direction = UISwipeGestureRecognizerDirectionLeft;
		[self.view addGestureRecognizer:rightSwipe];
		
		UISwipeGestureRecognizer *leftSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeft)];
		leftSwipe.direction = UISwipeGestureRecognizerDirectionRight;
		[self.view addGestureRecognizer:leftSwipe];
		
		[self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapView)]];
	}
	return self;
}

-(void)setupWithImageData:(PiwigoImageData*)imageData andPlaceHolderImage:(UIImage*)placeHolder
{
	self.imageData = imageData;
	self.title = self.imageData.name;
	
	__weak typeof(self) weakSelf = self;
	self.progressBar.hidden = NO;
	[self.image setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.imageData.mediumPath]]
					  placeholderImage:placeHolder
							   success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
								   weakSelf.image.image = image;
								   weakSelf.downloadView.downloadImage = image;
								   weakSelf.downloadView.hidden = YES;
								   weakSelf.progressBar.hidden = YES;
							   } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
								   
							   }];
	
	[self.image setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
		CGFloat percent = (CGFloat)totalBytesRead / totalBytesExpectedToRead;
		if(percent == 1) {
			weakSelf.progressBar.hidden = YES;
		} else {
			[weakSelf.progressBar setProgress:percent animated:YES];
		}
	}];
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	UIBarButtonItem *imageOptionsButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(imageOptions)];
	self.navigationItem.rightBarButtonItem = imageOptionsButton;
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
											   if([self.delegate respondsToSelector:@selector(didDeleteImage)])
											   {
												   [self.delegate didDeleteImage];
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
	}];
	
	CGRect frame = self.tabBarController.tabBar.frame;
	CGFloat height = frame.size.height;
	CGFloat offsetY = (frame.origin.y >= self.view.frame.size.height) ? -height : height;
	
	[UIView animateWithDuration:0.3
					 animations:^{
						 self.tabBarController.tabBar.frame = CGRectOffset(frame, 0, offsetY);
					 }];
}

-(void)swipeRight
{
	self.currentImageIndex++;
	if(self.currentImageIndex < [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count) {
		[self updateCurrentImage];
	} else {
		self.currentImageIndex--;
	}
}

-(void)swipeLeft
{
	self.currentImageIndex--;
	if(self.currentImageIndex >= 0) {
		[self updateCurrentImage];
	} else {
		self.currentImageIndex++;
	}
}

-(void)updateCurrentImage
{
	PiwigoImageData *imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andIndex:self.currentImageIndex];
	self.title = imageData.name;
	[self.image setImageWithURL:[NSURL URLWithString:imageData.mediumPath]
			   placeholderImage:[UIImage imageNamed:@"placeholder"]];
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

@end
