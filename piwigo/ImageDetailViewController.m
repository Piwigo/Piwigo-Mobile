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

@interface ImageDetailViewController ()

@property (nonatomic, strong) PiwigoImageData *imageData;
@property (nonatomic, strong) UIImageView *image;
@property (nonatomic, strong) UIProgressView *progressBar;

@property (nonatomic, strong) NSString *categoryId;
@property (nonatomic, assign) NSInteger currentImageIndex;

@end

@implementation ImageDetailViewController

-(instancetype)initWithCategoryId:(NSString*)categoryId andImageIndex:(NSInteger)imageIndex
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
							   withTitle:@"Image Options"
					   cancelButtonTitle:@"Cancel"
				  destructiveButtonTitle:@"Delete"
					   otherButtonTitles:@[@"Download", @"Rename"]
								tapBlock:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
									switch(buttonIndex)
									{
										case 0: // Delete
											[self deleteImage];
											break;
										case 1: // Download
											break;
										case 2: // Rename
											break;
									}
								}];
}

-(void)deleteImage
{
	[UIAlertView showWithTitle:@"Are You Sure?"
					   message:@"Are you sure you want to delete this image? This cannot be undone!"
			 cancelButtonTitle:@"Nevermind"
			 otherButtonTitles:@[@"Yes"]
					  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
						  NSLog(@"%@", @(buttonIndex));
						  if(buttonIndex == 1) {
							  [ImageService deleteImageById:[self.imageData.imageId integerValue]
										   ListOnCompletion:^(AFHTTPRequestOperation *operation) {
											   // remove this image from our cache
											   [[CategoriesData sharedInstance] removeImage:self.imageData forCategoryId:self.categoryId];
											   NSLog(@"deleted!");
										   } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
											   // oh noes!
											   NSLog(@"fail to delete");
										   }];
						  }
					  }];
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
	if(self.currentImageIndex < [[[CategoriesData sharedInstance].categories objectForKey:self.categoryId] imageList].count) {
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

@end
