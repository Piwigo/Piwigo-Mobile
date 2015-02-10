//
//  ImageUploadViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/5/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageUploadViewController.h"
#import "ImageUploadTableViewCell.h"
#import "ImageUpload.h"
#import "EditImageDetailsViewController.h"
#import "ImageUploadManager.h"
#import "ImageUploadProgressView.h"
#import "Model.h"

@interface ImageUploadViewController () <UITableViewDelegate, UITableViewDataSource, ImageUploadProgressDelegate, EditImageDetailsDelegate>

@property (nonatomic, strong) UITableView *uploadImagesTableView;
@property (nonatomic, strong) NSMutableArray *imagesToUpload;

@end

@implementation ImageUploadViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoWhiteCream];
		self.imagesToUpload = [NSMutableArray new];
		
		self.title = @"Images";
		
		self.uploadImagesTableView = [UITableView new];
		self.uploadImagesTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.uploadImagesTableView.delegate = self;
		self.uploadImagesTableView.dataSource = self;
		[self.uploadImagesTableView registerNib:[UINib nibWithNibName:@"ImageUploadCell" bundle:nil] forCellReuseIdentifier:@"cell"];
		[self.view addSubview:self.uploadImagesTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.uploadImagesTableView]];
		
		[ImageUploadProgressView sharedInstance].delegate = self;
		
		if([ImageUploadManager sharedInstance].imageUploadQueue.count > 0)
		{
			[[ImageUploadProgressView sharedInstance] addViewToView:self.view forBottomLayout:self.bottomLayoutGuide];
		}
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
	self.navigationItem.leftBarButtonItem = back;
	
	UIBarButtonItem *upload = [[UIBarButtonItem alloc] initWithTitle:@"Upload"
															   style:UIBarButtonItemStylePlain
															  target:self
															  action:@selector(startUpload)];
	self.navigationItem.rightBarButtonItem = upload;
	
	if([ImageUploadManager sharedInstance].imageUploadQueue.count > 0)
	{
		[[ImageUploadProgressView sharedInstance] addViewToView:self.view forBottomLayout:self.bottomLayoutGuide];
	}
}

-(void)cancel
{
	[self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

-(void)startUpload
{
	// @TODO: Ask user if they really want to add these images to the upload queue
	[[ImageUploadManager sharedInstance] addImages:self.imagesToUpload];
	[[ImageUploadProgressView sharedInstance] addViewToView:self.view forBottomLayout:self.bottomLayoutGuide];
}

-(void)setImagesSelected:(NSArray *)imagesSelected
{
	_imagesSelected = imagesSelected;
	[self setUpImageInfo];
}

-(void)setUpImageInfo
{
	for(NSString *imageName in self.imagesSelected)
	{
		// @TODO: Get a default privacy and default author
		ImageUpload *image = [[ImageUpload alloc] initWithImageName:imageName forCategory:self.selectedCategory forPrivacyLevel:[Model sharedInstance].defaultPrivacyLevel author:[Model sharedInstance].defaultAuthor description:@"" andTags:@""];
		[self.imagesToUpload addObject:image];
	}
}

-(void)removeImageFromTableView:(ImageUpload*)imageToRemove
{
	for(NSInteger i = 0; i < self.imagesToUpload.count; i++)
	{
		if([((ImageUpload*)[self.imagesToUpload objectAtIndex:i]).image isEqualToString:imageToRemove.image])
		{
			[self.imagesToUpload removeObjectAtIndex:i];
			[self.uploadImagesTableView reloadData];
			break;
		}
	}
}

#pragma mark UITableView Methods

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 150;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.imagesToUpload.count;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	ImageUploadTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	
	ImageUpload *image = [self.imagesToUpload objectAtIndex:indexPath.row];
	
	[cell setupWithImageInfo:image];
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageDetails" bundle:nil];
	EditImageDetailsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageDetails"];
	editImageVC.imageDetails = [self.imagesToUpload objectAtIndex:indexPath.row];
	editImageVC.delegate = self;
	[self.navigationController pushViewController:editImageVC animated:YES];
}

#pragma mark ImageUploadProgressDelegate Methods

-(void)imageProgress:(ImageUpload *)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks
{
	
}

-(void)imageUploaded:(ImageUpload *)image placeInQueue:(NSInteger)rank outOf:(NSInteger)totalInQueue withResponse:(NSDictionary *)response
{
	[self removeImageFromTableView:image];
}

#pragma mark EditImageDetailsDelegate Methods

-(void)didFinishEditingDetails:(ImageUpload *)details
{
	NSInteger index = 0;
	for(ImageUpload *image in self.imagesToUpload)
	{
		if([image.image isEqualToString:details.image]) break;
		index++;
	}
	
	[self.imagesToUpload replaceObjectAtIndex:index withObject:details];
	[self.uploadImagesTableView reloadData];
}

@end
