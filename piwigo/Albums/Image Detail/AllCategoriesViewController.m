//
//  AllCategoriesViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AllCategoriesViewController.h"
#import "CategoriesData.h"
#import "AlbumService.h"
#import "CategoryTableViewCell.h"

@interface AllCategoriesViewController ()

@property (nonatomic, assign) NSInteger imageId;
@property (nonatomic, assign) NSInteger categoryId;

@end

@implementation AllCategoriesViewController

-(instancetype)initForImageId:(NSInteger)imageId andCategoryId:(NSInteger)categoryId
{
	self = [super init];
	if(self)
	{
		self.title = NSLocalizedString(@"categorySelection", @"Select Album");
		self.imageId = imageId;
		self.categoryId = categoryId;
	}
	return self;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(section == 0)
	{
		return 1;
	}
	return super.categories.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if(section == 1)
	{
		return 0;
	}
	return 50.0;
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	if(section == 0)
	{
		UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 50)];
		
		UILabel *headerLabel = [UILabel new];
		headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
		headerLabel.font = [UIFont piwigoFontNormal];
		headerLabel.textColor = [UIColor piwigoGray];
		headerLabel.text = NSLocalizedString(@"categorySelection_forImage", @"Select an album for this image");
		headerLabel.adjustsFontSizeToFitWidth = YES;
		headerLabel.minimumScaleFactor = 0.5;
		[header addSubview:headerLabel];
		[header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:10]];
		[header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
																	   options:kNilOptions
																	   metrics:nil
																		 views:@{@"header" : headerLabel}]];
		
		return header;
	}
	return nil;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	CategoryTableViewCell *cell = (CategoryTableViewCell*)[super tableView:tableView cellForRowAtIndexPath:indexPath];
	
	PiwigoAlbumData *albumData = nil;
	
	if(indexPath.section == 0)
	{
		albumData = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
	}
	else
	{
		albumData = [super.categories objectAtIndex:indexPath.row];
	}
	
	[cell setupWithCategoryData:albumData];
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	PiwigoAlbumData *albumData;
	
	if(indexPath.section == 1)
	{
		albumData = [[CategoriesData sharedInstance].allCategories objectAtIndex:indexPath.row];
	}
	else
	{
		albumData = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
	}
	
	[UIAlertView showWithTitle:NSLocalizedString(@"categoryImageSet_title", @"Set Image Represenative")
					   message:[NSString stringWithFormat:NSLocalizedString(@"categoryImageSet_message", @"Are you sure you want to set this image for the album \"%@\"?"), albumData.name]
			 cancelButtonTitle:NSLocalizedString(@"alertNoButton", @"No")
			 otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
					  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
						  if(buttonIndex == 1)
						  {
							  [self setRepresentativeForCategoryId:albumData.albumId];
						  }
					  }];
}

-(void)setRepresentativeForCategoryId:(NSInteger)categoryId
{
	[AlbumService setCategoryRepresentativeForCategory:categoryId
											forImageId:self.imageId
										  OnCompletion:^(NSURLSessionTask *task, BOOL setSuccessfully) {
											  if(setSuccessfully)
											  {
												  // Update image Id of album
                                                  PiwigoAlbumData *category = [[CategoriesData sharedInstance] getCategoryById:categoryId];
												  category.albumThumbnailId = self.imageId;
												  
                                                  // Update image URL of album
                                                  PiwigoImageData *imgData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:[NSString stringWithFormat:@"%@", @(self.imageId)]];
												  category.albumThumbnailUrl = imgData.ThumbPath;

                                                  // Image will be downloaded when displaying list of albums
                                                  category.categoryImage = nil;
												  
												  [UIAlertView showWithTitle:NSLocalizedString(@"categoryImageSetSuccess_title", @"Image Set Successful")
																	 message:NSLocalizedString(@"categoryImageSetSuccess_message", @"The image was set successfully for the album image")
														   cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
														   otherButtonTitles:nil
																	tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
																		[self.navigationController popViewControllerAnimated:YES];
																	}];
											  }
											  else
											  {
												  [self showSetRepresenativeError:nil];
											  }
										  } onFailure:^(NSURLSessionTask *task, NSError *error) {
											  [self showSetRepresenativeError:[error localizedDescription]];
										  }];
}
-(void)showSetRepresenativeError:(NSString*)message
{
	NSString *bodyMessage = NSLocalizedString(@"categoryImageSetError_message", @"Failed to set the album image");
	if(message)
	{
		bodyMessage = [NSString stringWithFormat:@"%@\n%@", bodyMessage, message];
	}
	[UIAlertView showWithTitle:NSLocalizedString(@"categoryImageSetError_title", @"Image Set Error")
					   message:bodyMessage
			 cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
			 otherButtonTitles:nil
					  tapBlock:nil];
}

@end
