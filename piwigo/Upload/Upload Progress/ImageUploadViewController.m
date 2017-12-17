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
#import "MGSwipeTableCell.h"

@interface ImageUploadViewController () <UITableViewDelegate, UITableViewDataSource, MGSwipeTableCellDelegate, ImageUploadProgressDelegate, EditImageDetailsDelegate>

@property (nonatomic, strong) UITableView *uploadImagesTableView;
@property (nonatomic, strong) NSMutableArray *imagesToEdit;

@end

@implementation ImageUploadViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		self.imagesToEdit = [NSMutableArray new];
		
		self.title = NSLocalizedString(@"imageUploadDetailsView_title", @"Images");
		
		self.uploadImagesTableView = [UITableView new];
		self.uploadImagesTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.uploadImagesTableView.delegate = self;
		self.uploadImagesTableView.dataSource = self;
        self.uploadImagesTableView.backgroundColor = [UIColor piwigoGray];
		UINib *cellNib = [UINib nibWithNibName:@"ImageUploadCell" bundle:nil];
		[self.uploadImagesTableView registerNib:cellNib forCellReuseIdentifier:@"Cell"];
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
	
	UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(cancel)];
	self.navigationItem.leftBarButtonItem = back;
	
	UIBarButtonItem *upload = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"imageUploadDetailsButton_title", @"Upload")
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
	[[ImageUploadManager sharedInstance] addImages:self.imagesToEdit];
	[[ImageUploadProgressView sharedInstance] addViewToView:self.view forBottomLayout:self.bottomLayoutGuide];
	self.imagesToEdit = [NSMutableArray new];
	[self.uploadImagesTableView reloadData];
}

-(void)setImagesSelected:(NSArray *)imagesSelected
{
	_imagesSelected = imagesSelected;
	[self setUpImageInfo];
}

-(void)setUpImageInfo
{
	for(PHAsset *imageAsset in self.imagesSelected)
	{
		ImageUpload *image = [[ImageUpload alloc] initWithImageAsset:imageAsset
                                                         forCategory:self.selectedCategory
                                                     forPrivacyLevel:[Model sharedInstance].defaultPrivacyLevel
                                                              author:[Model sharedInstance].defaultAuthor
                                                         description:@"" andTags:nil];
		[self.imagesToEdit addObject:image];
	}
}

-(void)removeImageFromTableView:(ImageUpload*)imageToRemove
{
	for(NSInteger i = 0; i < self.imagesToEdit.count; i++)
	{
		if([((ImageUpload*)[self.imagesToEdit objectAtIndex:i]).image isEqualToString:imageToRemove.image])
		{
			[self.imagesToEdit removeObjectAtIndex:i];
			[self.uploadImagesTableView reloadData];
			break;
		}
	}
}

-(void)updateImage:(ImageUpload*)image withProgress:(CGFloat)progress
{
	// the image being uploaded is always the first object in the array
	ImageUploadTableViewCell *cell = (ImageUploadTableViewCell*)[self.uploadImagesTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
	cell.imageProgress = progress;
}

#pragma mark — UITableView Methods

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	return 44.0;
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 30.0)];
	header.backgroundColor = [UIColor piwigoGray];
	
	UILabel *headerLabel = [UILabel new];
	headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontNormal];
	headerLabel.textColor = [UIColor piwigoOrange];
	[header addSubview:headerLabel];
	[header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:5]];
	[header addConstraint:[NSLayoutConstraint constraintViewFromLeft:headerLabel amount:15]];
	
	switch(section)
	{
		case 0:
			headerLabel.text = NSLocalizedString(@"imageUploadDetailsEdit_title", @"Edit Images to Upload");
			break;
		case 1:
			headerLabel.text = NSLocalizedString(@"imageUploadDetailsUploading_title", @"Images that are Being Uploaded");
			break;
	}
	
	return header;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 180;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(self.imagesToEdit.count == 0 && [ImageUploadManager sharedInstance].imageUploadQueue.count == 0)
	{
		[self cancel];
	}
	if(section == 0)
	{
		return self.imagesToEdit.count;
	}
	else
	{
		return [ImageUploadManager sharedInstance].imageUploadQueue.count;
	}
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	ImageUploadTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
	
	if(indexPath.section == 0)
	{
        ImageUpload *image = [self.imagesToEdit objectAtIndex:indexPath.row];
		[cell setupWithImageInfo:image];
	}
	else
	{
		ImageUpload *image = [[ImageUploadManager sharedInstance].imageUploadQueue objectAtIndex:indexPath.row];
		[cell setupWithImageInfo:image];
		cell.isInQueueForUpload = YES;
	}
    
    cell.delegate = self;
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	if(indexPath.section == 0)
	{
		UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageDetails" bundle:nil];
		EditImageDetailsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageDetails"];
		editImageVC.imageDetails = [self.imagesToEdit objectAtIndex:indexPath.row];
		editImageVC.delegate = self;
		[self.navigationController pushViewController:editImageVC animated:YES];
	}
}

-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 1 && indexPath.row == 0)
	{
		return NO;
	}
	return YES;
}

#pragma mark — MGSwipeTableCellDelegate Methods

-(BOOL)swipeTableCell:(MGSwipeTableCell *)cell tappedButtonAtIndex:(NSInteger)index
             direction:(MGSwipeDirection)direction fromExpansion:(BOOL) fromExpansion
{
//    NSLog(@"Delegate: button tapped, %@ position, index %d, from Expansion: %@",
//          direction == MGSwipeDirectionLeftToRight ? @"left" : @"right", (int)index, fromExpansion ? @"YES" : @"NO");
    
    if (direction == MGSwipeDirectionRightToLeft && index == 0) {
        // Delete button
        NSIndexPath *indexPath = [self.uploadImagesTableView indexPathForCell:cell];
        NSLog(@"Delete button pressed at indexPath: %@",indexPath);
        if(indexPath.section == 0)      // Image selected for upload
        {
            // Remove image not in upload queue
            [self.imagesToEdit removeObjectAtIndex:indexPath.row];
        }
        else if(indexPath.row == 0)     // Image being uploaded
        {
            // Stop current iCloud download or Piwigo upload
            ImageUpload *image = [[ImageUploadManager sharedInstance].imageUploadQueue objectAtIndex:indexPath.row];
            image.stopUpload = YES;
            [[ImageUploadManager sharedInstance].imageUploadQueue replaceObjectsAtIndexes:[NSIndexSet indexSetWithIndex:indexPath.row] withObjects:[NSArray arrayWithObject:image]];
        }
        else if (indexPath.row < [ImageUploadManager sharedInstance].imageUploadQueue.count)    // Image to be uploaded
        {
            // Remove image from upload queue (both in table and collection view) or stop iCloud download or Piwigo upload
            ImageUpload *image = [[ImageUploadManager sharedInstance].imageUploadQueue objectAtIndex:indexPath.row];
            [[ImageUploadManager sharedInstance].imageUploadQueue removeObjectAtIndex:indexPath.row];
            [[ImageUploadManager sharedInstance].imageNamesUploadQueue removeObjectForKey:[image.image stringByDeletingPathExtension]];
            [ImageUploadManager sharedInstance].maximumImagesForBatch--;
        }

        // Update tables
        [self.uploadImagesTableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
    return YES;
}


#pragma mark — ImageUploadProgressDelegate Methods

-(void)imageProgress:(ImageUpload *)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks iCloudProgress:(CGFloat)iCloudProgress
{
    CGFloat chunkPercent = 100.0 / totalChunks / 100.0;
    CGFloat onChunkPercent = chunkPercent * (currentChunk - 1);
    CGFloat peiceProgress = (CGFloat)current / total;
    CGFloat uploadProgress = onChunkPercent + (chunkPercent * peiceProgress);
    
    if (iCloudProgress < 0) {
        [self updateImage:image withProgress:uploadProgress];
        NSLog(@"ImageUploadViewController[imageProgress]: %.2f", uploadProgress);
    } else {
        [self updateImage:image withProgress:((iCloudProgress + uploadProgress) / 2.0)];
        NSLog(@"ImageUploadViewController[imageProgress]: %.2f", ((iCloudProgress + uploadProgress) / 2.0));
    }
}

-(void)imageUploaded:(ImageUpload *)image placeInQueue:(NSInteger)rank outOf:(NSInteger)totalInQueue withResponse:(NSDictionary *)response
{
	[self.uploadImagesTableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
}


#pragma mark — EditImageDetailsDelegate Methods

-(void)didFinishEditingDetails:(ImageUpload *)details
{
	NSInteger index = 0;
	for(ImageUpload *image in self.imagesToEdit)
	{
		if([image.image isEqualToString:details.image]) break;
		index++;
	}
	
	[self.imagesToEdit replaceObjectAtIndex:index withObject:details];
	[self.uploadImagesTableView reloadData];
}

@end
