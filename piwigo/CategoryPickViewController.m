//
//  CategoryPickViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoryPickViewController.h"
#import "CategoriesData.h"
#import "LocalAlbumsViewController.h"
#import "Model.h"
#import "AlbumService.h"
#import "PhotosFetch.h"

@interface CategoryPickViewController () <CategoryListDelegate>

@end

@implementation CategoryPickViewController

-(instancetype)init
{
	if([Model sharedInstance].hasAdminRights)
	{
		self = [super init];
		self.categoryListDelegate = self;
		
		[[PhotosFetch sharedInstance] getLocalGroupsOnCompletion:nil];
	}
	else
	{
		self = (CategoryPickViewController*)[[UIViewController alloc] init];
		
		UILabel *adminLabel = [UILabel new];
		adminLabel.translatesAutoresizingMaskIntoConstraints = NO;
		adminLabel.font = [UIFont piwigoFontNormal];
		adminLabel.font = [adminLabel.font fontWithSize:20];
		adminLabel.textColor = [UIColor piwigoOrange];
		adminLabel.text = NSLocalizedString(@"adminRights_title", @"Admin Rights Needed");
		adminLabel.minimumScaleFactor = 0.5;
		adminLabel.adjustsFontSizeToFitWidth = YES;
		adminLabel.textAlignment = NSTextAlignmentCenter;
		[self.view addSubview:adminLabel];
		[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:adminLabel]];
		[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[admin]-10-|"
																		  options:kNilOptions
																		  metrics:nil
																			views:@{@"admin" : adminLabel}]];
		
		UILabel *description = [UILabel new];
		description.translatesAutoresizingMaskIntoConstraints = NO;
		description.font = [UIFont piwigoFontNormal];
		description.textColor = [UIColor piwigoGray];
		description.numberOfLines = 4;
		description.textAlignment = NSTextAlignmentCenter;
		description.text = NSLocalizedString(@"adminRights_message", @"You're not an admin.\nYou have to be an admin to be able to upload images.");
		description.adjustsFontSizeToFitWidth = YES;
		description.minimumScaleFactor = 0.5;
		[self.view addSubview:description];
		[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:description]];
		[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[description]-|"
																		  options:kNilOptions
																		  metrics:nil
																			views:@{@"description" : description}]];
		
		[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-80-[admin]-[description]"
																		  options:kNilOptions
																		  metrics:nil
																			views:@{@"admin" : adminLabel,
																					@"description" : description}]];
		
	}
	
	self.view.backgroundColor = [UIColor piwigoWhiteCream];
	
	return self;
}

-(void)selectedCategory:(PiwigoAlbumData *)category
{
	if(category)
	{
		LocalAlbumsViewController *localAlbums = [[LocalAlbumsViewController alloc] initWithCategoryId:category.albumId];
		[self.navigationController pushViewController:localAlbums animated:YES];
	}
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	return 50.0;
}
-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 50)];
	
	UILabel *headerLabel = [UILabel new];
	headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
	headerLabel.font = [UIFont piwigoFontNormal];
	headerLabel.textColor = [UIColor piwigoGray];
	headerLabel.text = NSLocalizedString(@"categoryUpload_chooseAlbum", @"Select an album to upload images to");
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

@end
